import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'auction_screen.dart' show quickAddAuction;
import 'auction_detail_screen.dart' show matchZoneForAddress;
import 'buy_band.dart';

/// 모아타운/신통기획 신청지 — 서울 자치구 개요 → 자치구별 구역 리스트 →
/// 구역 안에서 경매물건 추가·상세(임장)·네이버 지도.
const _teal = Color(0xFF14B8A6);

Color _kindColor(String k) => k == '신통기획' ? AppColors.violet : _teal;

/// 다음 가격 상승 이벤트 — 이 «직전»이 매도 라인.
String? _nextJump(Zone z) {
  final moa = z.kind != '신통기획';
  if (z.stage <= 1) return moa ? '통합심의(관리계획 고시)' : '정비구역 지정고시';
  if (z.stage == 2) return '조합설립인가';
  return null; // 3단계↑ 이미 상승 반영
}

Future<void> _openNaver(String query) async {
  final uri = Uri.parse(
      'https://map.naver.com/p/search/${Uri.encodeComponent(query)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class MoaTownView extends ConsumerStatefulWidget {
  const MoaTownView({super.key});

  @override
  ConsumerState<MoaTownView> createState() => _MoaTownViewState();
}

class _MoaTownViewState extends ConsumerState<MoaTownView> {
  String? _district; // null = 서울 개요
  String? _openZoneId; // 펼친 구역
  /// 자치구 안에서 보는 사업 종류. 모아와 신통은 «절차가 달라»
  /// 사다리를 같이 그릴 수 없다 — 골라서 본다.
  String _kind = '모아타운';
  // 단계 필터: -1 전체 / 0 살 수 있는 것(A+B) / 1 매수A / 2 매수B / 3 진입불가
  int _stageF = -1;

  bool _stageMatch(Zone z) => switch (_stageF) {
        < 0 => true,
        0 => bandOfZone(z).canBuy, // 매수 A + B
        3 => z.stage >= 3,
        final v => z.stage == v,
      };

  Widget _stageChips() {
    Widget chip(int v, String label, Color c) {
      final on = _stageF == v;
      return InkWell(
        onTap: () => setState(() => _stageF = v),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
                color: on ? c : AppColors.border, width: on ? 1.4 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? c : AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: [
      chip(-1, '전체', _teal),
      chip(0, '🟢 살 수 있는 것', AppColors.primary),
      chip(1, '매수 A · 수립 중(저점)', AppColors.primary),
      chip(2, '매수 B · 동의서 징구', AppColors.gold),
      chip(3, '🚫 진입 불가(조합설립↑)', AppColors.rose),
    ]);
  }

  /// 동의율을 구역 카드에서 바로 입력한다.
  /// 편집 다이얼로그 깊숙이 있어서 119곳 중 «0곳»이 채워져 있었다.
  /// 매수 B 에서 「인가 임박」을 가리는 유일한 값이다.
  Future<void> _editConsent(Zone z) async {
    final c = TextEditingController(
        text: z.consentRate > 0 ? z.consentRate.toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('조합설립 동의율',
            style: TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                '«70% 이상»이면 조합설립인가가 임박했다는 뜻이다. 그때부터는 '
                '탈출 창이 좁아진다 — 인가가 나면 양도가 막힌다.\n'
                '추진위·구청·현장 부동산에서 듣는 값이다.',
                style: TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.textSecondary,
                    height: 1.55)),
            const Gap(14),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '동의율 (%)', hintText: '예: 75'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: const Color(0xFF04211D)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(c.text.trim()) ?? 0;
    await ref
        .read(supabaseProvider)
        .from('zones')
        .update({'consent_rate': v}).eq('id', z.id);
    ref.invalidate(zonesProvider);
  }

  /// 구역의 네이버 검색어 / 물건 추가 시 주소 seed (동+번지 포함).
  String _zoneSeed(Zone z) {
    var n = z.name
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll('일대', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final d = z.district ?? '';
    if (n.contains('확인 전') || n.isEmpty) return '서울 $d 모아타운';
    final base = (d.isNotEmpty && n.contains(d)) ? n : '$d $n';
    return '서울 $base'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(zonesProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (zones) {
        if (zones.isEmpty) {
          return const EmptyState(
              icon: Icons.map_rounded,
              message: '등록된 구역이 없어요.\n＋구역 으로 모아타운·신통 신청지를 추가하세요.');
        }
        final props =
            ref.watch(auctionProvider).asData?.value ?? const <AuctionProperty>[];
        final shown = zones.where(_stageMatch).toList();
        return _district == null
            ? _overview(shown)
            : _districtList(shown, props, _district!);
      },
    );
  }

  // ── 서울 자치구 개요 ────────────────────────────────────────
  Widget _overview(List<Zone> zones) {
    final byDist = <String, List<Zone>>{};
    for (final z in zones) {
      final d = (z.district == null || z.district!.isEmpty) ? '기타' : z.district!;
      byDist.putIfAbsent(d, () => []).add(z);
    }
    final dists = byDist.keys.toList()
      ..sort((a, b) => byDist[b]!.length.compareTo(byDist[a]!.length));
    final moaTotal = zones.where((z) => z.kind == '모아타운').length;
    final sinTotal = zones.where((z) => z.kind == '신통기획').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('모아타운 · 신통기획 신청지',
            style:
                TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        Text('모아 $moaTotal · 신통 $sinTotal · 자치구를 눌러 구역 리스트로.',
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(10),
        _stageChips(),
        // 왜 이 구간인지 — 「가격이 뛰는 구간」(자료실 2026-08-31) 기준.
        if (_stageF >= 0) ...[
          const Gap(8),
          Builder(builder: (_) {
            final b = switch (_stageF) {
              0 => null,
              1 => BuyBand.early,
              2 => BuyBand.late_,
              _ => BuyBand.blocked,
            };
            final txt = b == null
                ? '★ 조합설립인가 «전»만 산다. 인가가 나면 조합원 지위 양도가 막혀 낙찰받아도 승계가 안 된다.'
                : '★ ${b.why}\n   매도 라인 — ${sellLineOf(b)}';
            final c = b?.color ?? AppColors.primary;
            return Text(txt,
                style: TextStyle(
                    fontSize: AppFont.caption,
                    color: c,
                    height: 1.55,
                    fontWeight: FontWeight.w600));
          }),
        ],
        const Gap(16),
        if (dists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('이 단계에 해당하는 구역이 없어요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint)),
          )
        else
          ResponsiveGrid(
            minTileWidth: 150,
            ratio: 1.35,
            children: [for (final d in dists) _distTile(d, byDist[d]!)],
          ),
        const Gap(14),
        const Text('※ 등록된 신청지입니다. 새 지정은 «세제→정비» 타임라인·슬랙으로 매일 갱신돼요.',
            style: TextStyle(
                fontSize: AppFont.caption,
                color: AppColors.textFaint,
                height: 1.5)),
      ],
    );
  }

  Widget _distTile(String d, List<Zone> zs) {
    final moa = zs.where((z) => z.kind == '모아타운').length;
    final sin = zs.where((z) => z.kind == '신통기획').length;
    return GlassCard(
      accent: _teal,
      onTap: () => setState(() {
        _district = d;
        _openZoneId = null;
        // 그 구에 더 많은 쪽을 기본으로 열어준다
        _kind = sin > moa ? '신통기획' : '모아타운';
      }),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 18, color: _teal),
            const Gap(4),
            Flexible(
              child: Text(d,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            ),
          ]),
          const Gap(8),
          Text('${zs.length}곳',
              style: const TextStyle(
                  fontSize: AppFont.hero,
                  fontWeight: FontWeight.w800,
                  color: _teal)),
          const Gap(6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            if (moa > 0) Pill('모아 $moa', color: _teal),
            if (sin > 0) Pill('신통 $sin', color: AppColors.violet),
          ]),
        ],
      ),
    );
  }

  // ── 자치구 → 구역 리스트 ───────────────────────────────────
  Widget _districtList(List<Zone> zones, List<AuctionProperty> props, String d) {
    final zs = [
      for (final z in zones)
        if ((z.district ?? '기타') == d || (z.district == null && d == '기타')) z
    ]..sort((a, b) => b.stage.compareTo(a.stage));
    // 섞여 있으면 고른 종류만 — 절차가 달라 같이 보면 헷갈린다.
    final mixed = zs.any((z) => z.isSin) && zs.any((z) => !z.isSin);
    final list = mixed ? zs.where((z) => z.kind == _kind).toList() : zs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _district = null),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 18, color: _teal),
              Gap(4),
              Text('서울 전체',
                  style: TextStyle(
                      color: _teal,
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const Gap(8),
        Text(d,
            style: const TextStyle(
                fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(12),
        // 사업 종류 — 절차가 다르므로 섞어 보지 않는다.
        Builder(builder: (context) {
          final moaN = zs.where((z) => !z.isSin).length;
          final sinN = zs.where((z) => z.isSin).length;
          if (moaN == 0 || sinN == 0) return const SizedBox.shrink();
          Widget chip(String k, int n, Color c) {
            final on = _kind == k;
            return InkWell(
              onTap: () => setState(() {
                _kind = k;
                _openZoneId = null;
              }),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: on ? c.withValues(alpha: 0.18) : AppColors.surfaceAlt,
                  border: Border.all(
                      color: on ? c : AppColors.border, width: on ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$k $n곳',
                    style: TextStyle(
                        color: on ? c : AppColors.textSecondary,
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800)),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              chip('모아타운', moaN, _teal),
              const Gap(8),
              chip('신통기획', sinN, AppColors.violet),
            ]),
          );
        }),
        // 단계 사다리 — 고른 종류의 절차만 그린다.
        _StageLadder(zones: zs.where((z) => z.kind == _kind).toList(),
            sin: _kind == '신통기획'),
        const Gap(14),
        _stageChips(),
        const Gap(14),
        for (final z in list) ...[
          _zoneCard(z, props, zones),
          const Gap(10),
        ],
      ],
    );
  }

  Widget _zoneCard(Zone z, List<AuctionProperty> props, List<Zone> zones) {
    final c = _kindColor(z.kind);
    final unknown = z.name.contains('확인 전') || z.name.isEmpty;
    final open = _openZoneId == z.id;
    // 이 구역에 매칭되는 물건(주소 기반).
    final mine = [
      for (final p in props)
        if (matchZoneForAddress(p.address, zones)?.id == z.id) p
    ];
    return GlassCard(
      accent: c,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _openZoneId = open ? null : z.id),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Pill(z.kind, color: c),
                        const Gap(6),
                        Pill('단계 ${z.stage} · ${z.stageLabel}',
                            color: z.stage >= 3
                                ? AppColors.gold
                                : AppColors.sky),
                        if (mine.isNotEmpty) ...[
                          const Gap(6),
                          Pill('물건 ${mine.length}', color: AppColors.primary),
                        ],
                      ]),
                      const Gap(8),
                      Text(unknown ? '동·번지 확인 전' : z.name,
                          style: const TextStyle(
                              fontSize: AppFont.section,
                              fontWeight: FontWeight.w800)),
                      if (_nextJump(z) != null) ...[
                        const Gap(4),
                        Row(children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 14, color: AppColors.rose),
                          const Gap(4),
                          Flexible(
                            child: Text('다음 상승: ${_nextJump(z)} 직전 매도',
                                style: const TextStyle(
                                    fontSize: AppFont.caption,
                                    color: AppColors.rose,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ],
                      // 권리산정기준일 — 이 날 다음날부터 분할·신축은 현금청산.
                      if (z.rightsDate != null) ...[
                        const Gap(7),
                        Row(children: [
                          const Icon(Icons.event_available_rounded,
                              size: 13, color: AppColors.textFaint),
                          const Gap(6),
                          Text('권리산정기준일 ${Dates.ymd(z.rightsDate!)}',
                              style: const TextStyle(
                                  fontSize: AppFont.caption,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                          const Gap(8),
                          const Expanded(
                            child: Text('이 날 다음날부터 분할·신축 → 현금청산',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppFont.caption,
                                    color: AppColors.textFaint)),
                          ),
                        ]),
                      ],
                      // 동의율 — 매수 B 에서 「인가 임박」을 가리는 값.
                      const Gap(7),
                      InkWell(
                        onTap: () => _editConsent(z),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Icon(Icons.how_to_vote_rounded,
                                size: 13,
                                color: z.imminent
                                    ? AppColors.rose
                                    : AppColors.textFaint),
                            const Gap(6),
                            Text(
                                z.consentRate > 0
                                    ? '동의율 ${z.consentRate.toStringAsFixed(0)}%'
                                    : '동의율 입력',
                                style: TextStyle(
                                    fontSize: AppFont.caption,
                                    fontWeight: FontWeight.w700,
                                    color: z.consentRate > 0
                                        ? (z.imminent
                                            ? AppColors.rose
                                            : AppColors.textSecondary)
                                        : _teal)),
                            const Gap(8),
                            if (z.imminent && z.stage == 2)
                              const Expanded(
                                child: Text('⚠️ 인가 임박 — 탈출 창이 좁다',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppFont.caption,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.rose)),
                              )
                            else
                              const Expanded(
                                child: Text('70%↑ 면 조합설립 임박',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppFont.caption,
                                        color: AppColors.textFaint)),
                              ),
                          ]),
                        ),
                      ),
                      // 초기 단계 해제 위험 — 자양2동 681은 4개월 만에 빠졌다.
                      if (hasDropRisk(z)) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.gold),
                                const Gap(8),
                                const Expanded(
                                  child: Text(kDropRiskNote,
                                      style: TextStyle(
                                          fontSize: AppFont.caption,
                                          color: AppColors.gold,
                                          height: 1.6)),
                                ),
                              ]),
                        ),
                      ],
                      if (z.aliases.isNotEmpty) ...[
                        const Gap(4),
                        Text('포함 번지: ${z.aliases.join(', ')}',
                            style: const TextStyle(
                                fontSize: AppFont.body,
                                color: AppColors.textSecondary)),
                      ],
                      if ((z.memo ?? '').isNotEmpty) ...[
                        const Gap(4),
                        Text(z.memo!,
                            style: const TextStyle(
                                fontSize: AppFont.caption,
                                color: AppColors.textFaint,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
                const Gap(8),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textFaint),
              ],
            ),
          ),
          if (open) ...[
            const Gap(12),
            const Divider(height: 1, color: AppColors.border),
            const Gap(12),
            // 구역 지도
            _actionRow(Icons.map_rounded, '구역 지도 (네이버)',
                () => _openNaver(_zoneSeed(z)), _teal),
            const Gap(10),
            // 물건 리스트
            if (mine.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('아직 등록된 경매물건이 없어요. 아래 ＋로 추가하세요.',
                    style: TextStyle(
                        fontSize: AppFont.body, color: AppColors.textFaint)),
              )
            else
              for (final p in mine) ...[
                _propRow(p),
                const Gap(8),
              ],
            const Gap(4),
            // 물건 추가
            InkWell(
              onTap: () =>
                  quickAddAuction(context, ref, prefillAddress: _zoneSeed(z)),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: c, width: 1.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('＋ 이 구역에 경매물건 추가',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: c,
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionRow(IconData icon, String label, VoidCallback onTap, Color c) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: c),
            const Gap(6),
            Text(label,
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _propRow(AuctionProperty p) {
    return InkWell(
      onTap: () => context.go('/auction/${p.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Pill(p.isSim ? '모의' : '실제',
                        color: p.isSim ? AppColors.violet : AppColors.primary),
                    if (p.corpStatus == 'ok') ...[
                      const Gap(5),
                      const Pill('법인 가능', color: AppColors.primary),
                    ],
                    const Gap(6),
                    Flexible(
                      child: Text(p.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  if ((p.address ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(p.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textFaint)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '네이버 지도',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.map_rounded, size: 20, color: _teal),
              onPressed: () => _openNaver(
                  (p.address == null || p.address!.isEmpty) ? p.title : p.address!),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 단계 사다리 — 순서와 «내 자리»를 같이 본다
// ══════════════════════════════════════════════════════════

/// 모아타운 7단계를 순서대로 늘어놓고, 이 자치구 구역이 몇 곳씩
/// 어느 칸에 있는지 표시한다. 매수 A/B/금지 구간도 색으로 가른다.
class _StageLadder extends StatelessWidget {
  final List<Zone> zones;
  /// 어느 절차로 그릴지. 추측하지 않는다 — 위에서 골라 내려준다.
  final bool sin;
  const _StageLadder({required this.zones, required this.sin});

  bool get _sin => sin;

  @override
  Widget build(BuildContext context) {
    final count = <int, int>{};
    for (final z in zones) {
      count[z.stage] = (count[z.stage] ?? 0) + 1;
    }
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.stairs_rounded,
                size: 15, color: AppColors.textSecondary),
            const Gap(8),
            Text(_sin ? '사업 진행 순서 (신통)' : '사업 진행 순서 (모아)',
                style: const TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
            const Spacer(),
            const Text('숫자 = 구역 수',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
          ]),
          const Gap(12),
          // 축이 모아 12칸 · 신통 11칸이라 한 줄에 안 들어간다.
          // 가로 스크롤은 브라우저 뒤로가기와 충돌하므로 «줄바꿈»으로 간다.
          LayoutBuilder(builder: (context, c) {
            final last = sin ? 11 : 12;
            const gap = 6.0;
            // 한 줄에 6칸씩 — 라벨이 두 줄까지 들어가는 너비.
            final per = c.maxWidth < 520 ? 3 : (c.maxWidth < 760 ? 4 : 6);
            final w = (c.maxWidth - gap * (per - 1)) / per;
            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (var i = 1; i <= last; i++)
                  SizedBox(width: w, child: _rung(i, count[i] ?? 0, i == last)),
              ],
            );
          }),
          const Gap(12),
          // 구간 뜻
          Wrap(spacing: 12, runSpacing: 6, children: [
            for (final b in [BuyBand.early, BuyBand.late_, BuyBand.blocked])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: b.color, borderRadius: BorderRadius.circular(2)),
                ),
                const Gap(6),
                Text('${b.label} · ${b.short}',
                    style: TextStyle(
                        fontSize: AppFont.caption,
                        color: b.color,
                        fontWeight: FontWeight.w700)),
              ]),
          ]),
          const Gap(8),
          Text(
              _sin
                  ? '가격은 «선정 → 토허가», «지정고시», «조합설립» 에서 뛴다. '
                      '골짜기는 «기획 완료»와 «동의서 징구» — 그 칸에서 산다.'
                  : '가격은 «수립 → 고시», «징구 → 인가» 두 번 뛴다. 그 직전 칸에서 산다.',
              style: const TextStyle(
                  fontSize: AppFont.caption,
                  color: AppColors.textSecondary,
                  height: 1.55)),
          const Gap(4),
          const Text(
              '조합설립인가부터는 조합원 지위 양도가 막힌다 — 낙찰받아도 승계가 안 된다.',
              style: TextStyle(
                  fontSize: AppFont.caption,
                  color: AppColors.rose,
                  height: 1.55)),
        ],
      ),
    );
  }

  Widget _rung(int stage, int n, bool isLast) {
    final band = _sin ? bandOfSinStage(stage) : bandOfStage(stage);
    final has = n > 0;
    final c = band.color;
    // 조합설립인가로 넘어가는 칸에서 «문이 닫힌다» — 그 경계를 붉게 표시.
    final gate = band == BuyBand.blocked &&
        (_sin ? bandOfSinStage(stage - 1) : bandOfStage(stage - 1)) !=
            BuyBand.blocked;
    return Column(children: [
      if (gate)
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Text('↓ 여기서 닫힌다',
              style: TextStyle(
                  fontSize: AppFont.micro,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rose)),
        ),
      Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.withValues(alpha: has ? 0.22 : 0.07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: has ? c : c.withValues(alpha: 0.25),
              width: has ? 1.3 : 1),
        ),
        child: Text(has ? '$stage · $n' : '$stage',
            style: TextStyle(
                fontSize: AppFont.label,
                fontWeight: FontWeight.w900,
                color: has ? c : c.withValues(alpha: 0.45))),
      ),
      const Gap(5),
      SizedBox(
        height: 32,
        child: Text(
          (_sin ? Zone.sinStageLabels[stage] : Zone.stageLabels[stage]) ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppFont.caption,
              height: 1.3,
              fontWeight: has ? FontWeight.w700 : FontWeight.w500,
              color: has ? AppColors.textSecondary : AppColors.textFaint),
        ),
      ),
      // 단계 이름은 «끝난 일»이다. 지금 뭐가 돌아가는지를 한 줄 더 준다 —
      // 매수 자리가 여기서 갈린다.
      const Gap(3),
      SizedBox(
        height: 32,
        child: Text(
          '↳ ${(_sin ? kSinStageDoing[stage] : kStageDoing[stage]) ?? ''}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppFont.micro,
              height: 1.3,
              fontWeight: band.canBuy ? FontWeight.w800 : FontWeight.w500,
              color: band.canBuy
                  ? c
                  : AppColors.textFaint.withValues(alpha: 0.7)),
        ),
      ),
    ]);
  }
}
