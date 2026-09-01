import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'auction_screen.dart' show quickAddAuction;
import 'auction_detail_screen.dart' show matchZoneForAddress;

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
  int _stageF = -1; // 단계 필터: -1 전체 / 1 진입 적기 / 2 관리계획 / 3 조합설립↑

  bool _stageMatch(Zone z) => _stageF < 0
      ? true
      : (_stageF == 3 ? z.stage >= 3 : z.stage == _stageF);

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
      chip(1, '① 진입 적기(수립중)', AppColors.primary),
      chip(2, '② 관리계획 고시', AppColors.gold),
      chip(3, '③ 조합설립↑', AppColors.rose),
    ]);
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
        if (_stageF == 1) ...[
          const Gap(8),
          const Text('★ 진입 적기 = 대상지 선정~관리계획 수립 중(고시 전) = 저점. 은천처럼 여기서 매수.',
              style: TextStyle(
                  fontSize: AppFont.caption,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
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
        const Gap(2),
        const Text('구역을 누르면 경매물건이 펼쳐집니다. ＋로 물건 추가, 물건을 누르면 상세(임장 입력)로.',
            style:
                TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(10),
        _stageChips(),
        const Gap(14),
        for (final z in zs) ...[
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
