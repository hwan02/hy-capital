import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/widgets/money_field.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'package:go_router/go_router.dart';
import '../knowledge/knowledge_screen.dart';
import '../questions/lecture_questions_screen.dart';
import 'auction_paste.dart';
import 'buy_band.dart';
import 'auction_calculator.dart';
import 'tax_timeline.dart';
import 'redevelopment_flow.dart';
import 'moa_town_screen.dart';
import 'auction_detail_screen.dart' show matchZoneForAddress;
import 'progress.dart'
    show kProgressAccent, kStatusLabel, kStatusColor, kStatusOptions;
import 'progress_screen.dart';
import '../property/criteria_screen.dart';
import '../property/inherit.dart';
import '../property/survey_screen.dart';

const _teal = Color(0xFF14B8A6);

/// 붙여넣기 한 판으로 물건을 등록한다. 사용자가 받는 카톡/사이트 텍스트에
/// 필요한 숫자가 다 들어있으므로 손입력을 최소화한다.
/// 경매물건 빠른 추가. [prefillAddress] 주면 파싱된 주소가 없을 때 그 값으로 채운다
/// (모아타운 구역에서 추가 시 구역 주소를 넣어 구역 매칭이 되게).
Future<void> quickAddAuction(BuildContext context, WidgetRef ref,
    {String? prefillAddress}) async {
  final c = TextEditingController();
  final res = await showDialog<(ParsedAuction, String)>(
    context: context,
    builder: (_) => _PasteDialog(controller: c),
  );
  if (res == null) return;
  final saved = res.$1;
  final acq = res.$2;
  final addr = saved.address ?? prefillAddress;
  try {
    final sb = ref.read(supabaseProvider);
    final row = await sb
        .from('auction_properties')
        .insert({
          'user_id': sb.auth.currentUser!.id,
          'title': saved.title ?? '이름 없는 물건',
          'status': 'interest',
          'verdict': 'HOLD',
          'acquisition': acq,
          if (saved.caseNo != null) 'case_no': saved.caseNo,
          if (addr != null) 'address': addr,
          if (saved.court != null) 'court': saved.court,
          if (saved.propertyKind != null) 'property_kind': saved.propertyKind,
          if (saved.appraisalPrice > 0) 'appraisal_price': saved.appraisalPrice,
          if (saved.minPrice > 0) 'min_price': saved.minPrice,
          if (saved.depositOrTenth > 0) 'deposit': saved.depositOrTenth,
          if (saved.bidDate != null)
            'bid_date': saved.bidDate!.toUtc().toIso8601String(),
        })
        .select()
        .single();
    invalidateAll(ref);
    if (context.mounted) context.go('/auction/${row['id']}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가 실패: $e'), backgroundColor: AppColors.rose),
      );
    }
  }
}

/// 텍스트를 붙여넣으면 아래에 파싱 결과를 즉시 미리보기로 보여준다.
class _PasteDialog extends StatefulWidget {
  final TextEditingController controller;
  const _PasteDialog({required this.controller});

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  ParsedAuction _p = const ParsedAuction();
  String _acq = 'auction'; // auction=경매 · quick_sale=급매

  @override
  Widget build(BuildContext context) {
    final t = widget.controller.text.trim();
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('경매 물건 추가',
          style: TextStyle(fontSize: AppFont.section)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 경매 / 급매 — 셈은 같고 이름만 다르다
              Row(children: [
                for (final a in const [
                  ('auction', '경매', Icons.gavel_rounded),
                  ('quick_sale', '급매', Icons.bolt_rounded),
                ]) ...[
                  InkWell(
                    onTap: () => setState(() => _acq = a.$1),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: _acq == a.$1
                            ? (a.$1 == 'auction' ? _teal : AppColors.gold)
                                .withValues(alpha: 0.18)
                            : Colors.transparent,
                        border: Border.all(
                            color: _acq == a.$1
                                ? (a.$1 == 'auction' ? _teal : AppColors.gold)
                                : AppColors.border,
                            width: _acq == a.$1 ? 1.4 : 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(a.$3,
                            size: 14,
                            color: _acq == a.$1
                                ? (a.$1 == 'auction' ? _teal : AppColors.gold)
                                : AppColors.textFaint),
                        const Gap(6),
                        Text(a.$2,
                            style: TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w800,
                                color: _acq == a.$1
                                    ? (a.$1 == 'auction'
                                        ? _teal
                                        : AppColors.gold)
                                    : AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                  const Gap(6),
                ],
              ]),
              const Gap(10),
              Text(
                  _acq == 'auction'
                      ? '카톡으로 받은 글이나 경매사이트 화면을 그대로 붙여넣으세요.\n'
                          '사건번호·최저가·보증금·입찰일·법원을 자동으로 뽑습니다.'
                      : '임장에서 들은 급매를 넣으세요. 단지명과 «부르는 값»만 있으면 됩니다.\n'
                          '계약금은 호가의 10%로 잡고, 시세는 단지 시세조사에서 가져옵니다.',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFont.label,
                      height: 1.5)),
              const Gap(12),
              TextField(
                controller: widget.controller,
                autofocus: true,
                maxLines: 7,
                minLines: 4,
                style: const TextStyle(fontSize: AppFont.label, height: 1.45),
                onChanged: (v) =>
                    setState(() => _p = parseAuctionText(v)),
                decoration: InputDecoration(
                    hintText: _acq == 'auction'
                        ? '여기에 붙여넣기 (물건명만 적어도 됩니다)'
                        : '예: 남성아트빌 401호 1억 2,800만'),
              ),
              if (t.isNotEmpty) ...[
                const Gap(14),
                Row(children: [
                  Text('읽어낸 값 ${_p.filledCount}/8',
                      style: const TextStyle(
                          color: _teal,
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w800)),
                  const Gap(8),
                  const Expanded(
                    child: Text('빈 칸은 등록 후 상세에서 채우면 됩니다',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                  ),
                ]),
                const Gap(8),
                _row('물건명', _p.title),
                _row('사건번호', _p.caseNo),
                _row('주소', _p.address),
                _row('종류', _p.propertyKind),
                _row('감정가',
                    _p.appraisalPrice > 0 ? '${Won.compact(_p.appraisalPrice)}원' : null),
                _row(_acq == 'auction' ? '최저가' : '부르는 값',
                    _p.minPrice > 0 ? '${Won.compact(_p.minPrice)}원' : null),
                _row(
                    _acq == 'auction' ? '입찰보증금' : '계약금(10%)',
                    _p.depositOrTenth > 0
                        ? '${Won.compact(_p.depositOrTenth)}원'
                            '${_p.deposit > 0 ? "" : " (최저가 10% 추정)"}'
                        : null),
                _row('입찰일', _p.bidDate == null
                    ? null
                    : '${_p.bidDate!.year}.${_p.bidDate!.month}.${_p.bidDate!.day}'
                        ' ${_p.bidDate!.hour}시'),
                _row('법원', _p.court),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: t.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  // 파싱이 물건명을 못 잡았으면 입력한 텍스트 첫 줄을 쓴다.
                  (_p.title != null
                      ? _p
                      : ParsedAuction(
                          title: t.split('\n').first.trim(),
                          caseNo: _p.caseNo,
                          address: _p.address,
                          court: _p.court,
                          propertyKind: _p.propertyKind,
                          appraisalPrice: _p.appraisalPrice,
                          minPrice: _p.minPrice,
                          deposit: _p.deposit,
                          bidDate: _p.bidDate,
                          areaSqm: _p.areaSqm,
                        ), _acq)),
          child: const Text('추가'),
        ),
      ],
    );
  }

  Widget _row(String label, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.caption)),
            ),
            Expanded(
              child: Text(value ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      fontWeight:
                          value == null ? FontWeight.w400 : FontWeight.w700,
                      color: value == null
                          ? AppColors.textFaint
                          : AppColors.textPrimary)),
            ),
          ],
        ),
      );
}

// 상태 이름·색은 «progress.dart 가 유일한 출처»다.
// 단계를 늘렸는데 여기 안 고쳐서 어긋나는 일을 막는다.
final _statusLabel = kStatusLabel;
final _statusColor = kStatusColor;

Color _verdictColor(String v) => switch (v) {
      'GO' => AppColors.primary,
      'PASS' => AppColors.rose,
      _ => AppColors.gold,
    };

String _corpLabel(String s) => switch (s) {
      'ok' => '법인 가능',
      'heavy' => '법인 중과',
      'check' => '법인 확인',
      _ => '법인?',
    };
Color _corpColor(String s) => switch (s) {
      'ok' => AppColors.primary,
      'heavy' => AppColors.rose,
      'check' => AppColors.gold,
      _ => AppColors.textFaint,
    };

class AuctionScreen extends ConsumerStatefulWidget {
  const AuctionScreen({super.key});

  @override
  ConsumerState<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends ConsumerState<AuctionScreen> {
  String _filter = 'all'; // all | GO | <status>
  String _zone = 'all'; // all | <zoneId> | __none__ (구역 필터)
  // 0=매물·단지 · 1=진행 · 3=기준 · 4=자료실 · 5=강의 질문 · 6=계산기 · 7=세제
  // · 8=재개발절차 · 9=모아타운
  // «구역부터 고르고» 물건을 본다 — 그래서 모아타운이 기본이다.
  int _tab = 9;

  /// 물건이 속한 구역 — 소속 단지(complex.zoneId) 우선, 없으면 주소로 매칭.
  Zone? _zoneOfProp(
      AuctionProperty p, Map<String, Complex> cById, List<Zone> zones) {
    final c = p.complexId == null ? null : cById[p.complexId];
    if (c?.zoneId != null) {
      for (final z in zones) {
        if (z.id == c!.zoneId) return z;
      }
    }
    return matchZoneForAddress(p.address, zones);
  }

  Widget _zoneChip(String key, String label, int n) {
    final on = _zone == key;
    return InkWell(
      onTap: () => setState(() => _zone = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color:
              on ? AppColors.violet.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: on ? AppColors.violet : AppColors.border,
              width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label $n',
            style: TextStyle(
                color: on ? AppColors.violet : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auctionProvider);
    final surveys = ref.watch(latestSurveysProvider).asData?.value ??
        const <String, PriceSurvey>{};
    final complexesList =
        ref.watch(complexesProvider).asData?.value ?? const <Complex>[];
    final zonesList =
        ref.watch(zonesProvider).asData?.value ?? const <Zone>[];
    // 물건 주소 → 구역 → «매수 구간». 자료실 「가격이 뛰는 구간」 기준.
    Zone? zoneOf(AuctionProperty p) =>
        matchZoneForAddress(p.address, zonesList);
    BuyBand bandOf(AuctionProperty p) => bandOfZone(zoneOf(p));
    final complexById = {for (final c in complexesList) c.id: c};
    const amber = Color(0xFFF59E0B);
    const orange = Color(0xFFF97316); // 강의 질문
    return ModulePage(
      // 이 화면이 제일 빽빽하다 — 사다리 11~12칸에 구역 카드까지 들어간다.
      // 기본 1100 이면 칸이 좁아 글씨를 못 키운다.
      maxWidth: 1500,
      title: '부동산',
      icon: Icons.location_city_rounded,
      color: switch (_tab) {
        0 => _teal,
        1 => kProgressAccent,
        2 => AppColors.sky,
        3 => amber,
        4 => amber,
        5 => orange,
        6 => AppColors.gold,
        9 => AppColors.sky,
        _ => AppColors.violet
      },
      action: switch (_tab) {
        0 => Row(mainAxisSize: MainAxisSize.min, children: [
              AddButton(
                  color: _teal,
                  label: '매물',
                  onTap: () => quickAddAuction(context, ref)),
              const Gap(8),
              AddButton(
                  color: AppColors.sky,
                  label: '단지',
                  onTap: () => editBuiltinRecord(context, ref, complexSpec)),
              const Gap(8),
              AddButton(
                  color: AppColors.violet,
                  label: '구역',
                  onTap: () => editBuiltinRecord(context, ref, zoneSpec)),
            ]),
        4 => const KnowledgeActions(),
        _ => null,
      },
      children: [
        // 물건 / 자료실 / 강의 질문 전환 (좁은 화면에서 줄바꿈)
        // 프로세스 순서: 발굴(모아타운·매물) → 판단(계산기) → 실행(진행) → 참고(세제·절차·기준·자료실·강의)
        Wrap(spacing: 8, runSpacing: 8, children: [
          ModuleTab(
              label: '모아타운',
              icon: Icons.map_rounded,
              color: AppColors.sky,
              selected: _tab == 9,
              onTap: () => setState(() => _tab = 9)),
          ModuleTab(
              label: '매물·단지',
              icon: Icons.gavel_rounded,
              color: _teal,
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          ModuleTab(
              label: '계산기',
              icon: Icons.calculate_rounded,
              color: AppColors.gold,
              selected: _tab == 6,
              onTap: () => setState(() => _tab = 6)),
          ModuleTab(
              label: '진행',
              icon: Icons.timeline_rounded,
              color: kProgressAccent,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
          ModuleTab(
              label: '세제',
              icon: Icons.receipt_long_rounded,
              color: AppColors.violet,
              selected: _tab == 7,
              onTap: () => setState(() => _tab = 7)),
          ModuleTab(
              label: '재개발절차',
              icon: Icons.account_tree_rounded,
              color: AppColors.rose,
              selected: _tab == 8,
              onTap: () => setState(() => _tab = 8)),
          ModuleTab(
              label: '기준',
              icon: Icons.rule_rounded,
              color: amber,
              selected: _tab == 3,
              onTap: () => setState(() => _tab = 3)),
          ModuleTab(
              label: '자료실',
              icon: Icons.menu_book_rounded,
              color: amber,
              selected: _tab == 4,
              onTap: () => setState(() => _tab = 4)),
          ModuleTab(
              label: '강의 질문',
              icon: Icons.live_help_rounded,
              color: orange,
              selected: _tab == 5,
              onTap: () => setState(() => _tab = 5)),
        ]),
        const Gap(18),
        if (_tab == 9) const MoaTownView(),
        if (_tab == 8) const RedevelopmentFlow(),
        if (_tab == 7) const TaxTimeline(),
        if (_tab == 6) const AuctionCalculator(),
        if (_tab == 5) const LectureQuestionsView(),
        if (_tab == 4) const KnowledgeView(excludeTag: '에어비앤비'),
        if (_tab == 3) const CriteriaView(),
        if (_tab == 1) const ProgressView(),
        if (_tab == 0)
          async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.gavel_rounded,
                message: '등록된 경매 물건이 없어요.\n관심 물건을 추가해 투자 판단을 시작하세요.',
              );
            }
            final go = items.where((p) => p.verdict == 'GO').toList();
            final cashSum = go.fold(0.0, (s, p) => s + p.cashNeeded);
            final avgScore = items.isEmpty
                ? 0.0
                : items.fold(0.0, (s, p) => s + p.score) / items.length;

            // 모의 적중률 — 낙찰가가 기록된 모의 물건 중, 내 입찰가 ≥ 낙찰가(이겼을) 비율.
            final simDone =
                items.where((p) => p.isSim && p.actualPrice > 0).toList();
            final simHits = simDone.where((p) => p.wouldWin).length;
            final hitRate =
                simDone.isEmpty ? null : simHits / simDone.length * 100;

            final byFilter = (_filter == 'excluded'
                    ? items.where((p) => p.excluded).toList()
                    : (switch (_filter) {
                        'all' => items,
                        'GO' => items.where((p) => p.verdict == 'GO').toList(),
                        'sim' => items.where((p) => p.isSim).toList(),
                        'real' => items.where((p) => !p.isSim).toList(),
                        'corp' =>
                          items.where((p) => p.corpStatus == 'ok').toList(),
                        // 매수 구간 — 「가격이 뛰는 구간」 기준(자료실 2026-08-31)
                        'buy' => items
                            .where((p) => bandOf(p).canBuy)
                            .toList(),
                        'buyA' => items
                            .where((p) => bandOf(p) == BuyBand.early)
                            .toList(),
                        'blocked' => items
                            .where((p) => bandOf(p) == BuyBand.blocked)
                            .toList(),
                        final s => items.where((p) => p.status == s).toList(),
                      })
                        // 제외한 물건은 기본 목록에서 숨긴다(제외 필터에서만 보임).
                        .where((p) => !p.excluded)
                        .toList())
                .toList()
              // 입찰일 임박순. 날짜 없는 건 뒤로, 지난 건 맨 뒤로.
              ..sort((a, b) {
                final da = a.daysToBid, db = b.daysToBid;
                int rank(int? d) => d == null ? 1 : (d < 0 ? 2 : 0);
                final r = rank(da).compareTo(rank(db));
                if (r != 0) return r;
                if (da == null || db == null) return 0;
                return da.compareTo(db);
              });

            // 구역별 — 물건의 소속 구역(단지 우선, 없으면 주소 매칭)으로 집계·필터.
            final zoneCount = <String, int>{};
            final zoneName = <String, String>{};
            for (final p in items.where((p) => !p.excluded)) {
              final z = _zoneOfProp(p, complexById, zonesList);
              final k = z?.id ?? '__none__';
              zoneCount[k] = (zoneCount[k] ?? 0) + 1;
              zoneName[k] = z?.name ?? '구역 없음';
            }
            String zoneKey(AuctionProperty p) =>
                _zoneOfProp(p, complexById, zonesList)?.id ?? '__none__';

            // 예산으로 걸러내지 않는다 — 살 물건을 찾으면 자금을 맞추는 순서다.
            // 보증금·계약금은 «필요한 돈»으로 카드에 보여주기만 한다.
            final filtered = _zone == 'all'
                ? byFilter
                : byFilter.where((p) => zoneKey(p) == _zone).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 160,
                  ratio: 1.5,
                  children: [
                    StatTile(
                      label: '관심 물건',
                      value: '${items.length}건',
                      icon: Icons.inventory_2_rounded,
                      color: _teal,
                    ),
                    StatTile(
                      label: 'GO 후보',
                      value: '${go.length}건',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary,
                    ),
                    StatTile(
                      label: 'GO 총 필요현금',
                      value: '${Won.compact(cashSum)}원',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.gold,
                    ),
                    StatTile(
                      label: '평균 투자점수',
                      value: avgScore.toStringAsFixed(0),
                      icon: Icons.speed_rounded,
                      color: AppColors.violet,
                    ),
                    StatTile(
                      label: '모의 적중률',
                      value: hitRate == null
                          ? '기록 전'
                          : '${hitRate.toStringAsFixed(0)}% ($simHits/${simDone.length})',
                      icon: Icons.military_tech_rounded,
                      color: AppColors.rose,
                    ),
                  ],
                ),
                const Gap(18),
                if (zoneCount.length > 1) ...[
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _zoneChip('all', '전체 구역',
                        items.where((p) => !p.excluded).length),
                    for (final e in (zoneCount.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value))))
                      _zoneChip(e.key, zoneName[e.key] ?? '구역', e.value),
                  ]),
                  const Gap(12),
                ],
                _FilterChips(
                  current: _filter,
                  onSelect: (f) => setState(() => _filter = f),
                ),
                const Gap(14),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('해당 조건의 물건이 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                for (final p in filtered) ...[
                  _AuctionCard(
                    p: p,
                    band: bandOf(p),
                    rights: rightsCheck(p, zoneOf(p)),
                    zoneRightsDate: zoneOf(p)?.rightsDate,
                    onFill: (col, val) async {
                      await ref
                          .read(supabaseProvider)
                          .from('auction_properties')
                          .update({col: val}).eq('id', p.id);
                      invalidateAll(ref);
                    },
                    price: effectivePrice(p, surveys),
                    onOpen: () => context.go('/auction/${p.id}'),
                    onDelete: () => deleteBuiltinRecord(
                        context, ref, auctionSpec, p.id,
                        name: p.title),
                    onSetVerdict: (v) async {
                      final sb = ref.read(supabaseProvider);
                      await sb
                          .from('auction_properties')
                          .update({'verdict': v}).eq('id', p.id);
                      invalidateAll(ref);
                    },
                    onToggleAlert: (v) async {
                      final sb = ref.read(supabaseProvider);
                      await sb
                          .from('auction_properties')
                          .update({'alert_enabled': v}).eq('id', p.id);
                      invalidateAll(ref);
                    },
                    onToggleExclude: (v) async {
                      final sb = ref.read(supabaseProvider);
                      await sb
                          .from('auction_properties')
                          .update({'excluded': v}).eq('id', p.id);
                      invalidateAll(ref);
                    },
                    onSetCorp: (v) async {
                      final sb = ref.read(supabaseProvider);
                      await sb
                          .from('auction_properties')
                          .update({'corp_status': v}).eq('id', p.id);
                      invalidateAll(ref);
                    },
                  ),
                  const Gap(14),
                ],
                // ── 단지 시세 (합친 뷰) — 선택 구역의 단지만 ──────────
                const Gap(6),
                Row(children: [
                  const Icon(Icons.domain_rounded,
                      size: 18, color: AppColors.sky),
                  const Gap(7),
                  Text(_zone == 'all' ? '단지 시세' : '이 구역 단지 시세',
                      style: const TextStyle(
                          fontSize: AppFont.section,
                          fontWeight: FontWeight.w800)),
                ]),
                const Gap(12),
                SurveyView(
                    embedded: true,
                    onlyZoneId: _zone == 'all' ? null : _zone),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _FilterChips({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final chips = <(String, String)>[
      ('all', '전체'),
      ('sim', '모의'),
      ('real', '실제'),
      ('GO', 'GO만'),
      ('corp', '법인가능'),
      ('buy', '🟢 살 수 있는 것'),
      ('buyA', '🟢 매수 A (저점)'),
      ('blocked', '🚫 진입 불가'),
      for (final (k, label, _) in kStatusOptions) (k, label),
      ('excluded', '제외됨'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (key, label) in chips)
          _Chip(
            label: label,
            selected: current == key,
            onTap: () => onSelect(key),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _teal.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: selected ? _teal : AppColors.border,
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? _teal : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AuctionCard extends StatefulWidget {
  final AuctionProperty p;
  final BuyBand band; // 구역 단계로 판정한 매수 구간
  final RightsCheck rights; // 사용승인일 vs 권리산정기준일
  final DateTime? zoneRightsDate; // 구역의 권리산정기준일
  /// 「다음에 채울 것」을 카드에서 바로 저장한다.
  final Future<void> Function(String col, Object? val) onFill;
  final EffectivePrice price; // 단지에서 상속받은 시세
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<String> onSetVerdict; // 할래(GO)/보류(HOLD)/패스(PASS)
  final ValueChanged<bool> onToggleAlert; // 매각기일 알림 받기
  final ValueChanged<bool> onToggleExclude; // 목록에서 제외/복원
  final ValueChanged<String?> onSetCorp; // 법인 취득세 태그(ok/heavy/check/null)
  const _AuctionCard(
      {required this.p,
      required this.band,
      required this.rights,
      required this.zoneRightsDate,
      required this.onFill,
      required this.price,
      required this.onOpen,
      required this.onDelete,
      required this.onSetVerdict,
      required this.onToggleAlert,
      required this.onToggleExclude,
      required this.onSetCorp});

  @override
  State<_AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<_AuctionCard> {
  /// 「다음에 채울 것」 하나만 묻는 작은 창. 상세로 안 들어가게 한다.
  Future<void> _fill(BuildContext context, MissingField f) async {
    Object? val;
    if (f.kind == FieldKind.date) {
      final now = DateTime.now();
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime(1995),
        firstDate: DateTime(1960),
        lastDate: now,
        helpText: '건축물대장 ${f.label}',
      );
      if (d == null) return;
      val = d.toIso8601String().substring(0, 10);
    } else if (f.kind == FieldKind.zone) {
      val = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('사업시행구역에 해당하나',
              style: TextStyle(fontSize: AppFont.section)),
          content: const Text(
              '이미 사업시행구역에 들어간 물건이면 늦었다. 구역도·고시문에서 확인한다.',
              style: TextStyle(
                  fontSize: AppFont.label, color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'in'),
                style: TextButton.styleFrom(foregroundColor: AppColors.rose),
                child: const Text('해당됨 (늦었다)')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF06210F)),
                onPressed: () => Navigator.pop(context, 'out'),
                child: const Text('미해당 (OK)')),
          ],
        ),
      );
      if (val == null) return;
    } else {
      final c = TextEditingController();
      var money = 0.0; // MoneyField 는 콜백으로 값을 준다
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(f.label, style: const TextStyle(fontSize: AppFont.section)),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(f.why,
                  style: const TextStyle(
                      fontSize: AppFont.caption,
                      color: AppColors.textSecondary,
                      height: 1.5)),
              const Gap(14),
              if (f.kind == FieldKind.money)
                MoneyField(
                    label: f.label,
                    initial: 0,
                    autofocus: true,
                    accent: _teal,
                    onChanged: (v) => money = v)
              else
                TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: f.label),
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
      final n = f.kind == FieldKind.money
          ? money
          : double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;
      if (n <= 0) return;
      val = f.kind == FieldKind.count ? n.toInt() : n;
    }
    await widget.onFill(f.column, val);
  }

  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final onOpen = widget.onOpen;
    final onDelete = widget.onDelete;
    final vColor = _verdictColor(p.verdict);
    final d = p.daysToBid;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
      // 진입 불가 구역이면 카드 테두리부터 빨갛게 — 목록에서 바로 걸러진다.
      accent: (widget.band == BuyBand.blocked || widget.rights.isBlocking)
          ? AppColors.rose
          : vColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 매수 구간 — 조합설립을 넘긴 구역은 낙찰받아도 승계가 안 된다.
          if (widget.band != BuyBand.unknown ||
              widget.rights != RightsCheck.unknown) ...[
            if (widget.band != BuyBand.unknown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: widget.band.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(children: [
                Icon(widget.band.icon, size: 15, color: widget.band.color),
                const Gap(8),
                Text(widget.band.label,
                    style: TextStyle(
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w900,
                        color: widget.band.color)),
                const Gap(8),
                Expanded(
                  child: Text(widget.band.short,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textSecondary)),
                ),
              ]),
            ),
            if (widget.band == BuyBand.blocked) ...[
              const Gap(6),
              Text(widget.band.why,
                  style: const TextStyle(
                      fontSize: AppFont.caption,
                      color: AppColors.rose,
                      height: 1.5)),
            ],
            // 권리산정기준일 — 「사면 안 되는 물건」을 여기서 거른다.
            if (widget.rights != RightsCheck.unknown) ...[
              const Gap(7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.rights.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(children: [
                  Icon(widget.rights.icon,
                      size: 14, color: widget.rights.color),
                  const Gap(8),
                  Text(widget.rights.label,
                      style: TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w900,
                          color: widget.rights.color)),
                  const Gap(8),
                  Expanded(
                    child: Text(
                        widget.zoneRightsDate == null
                            ? ''
                            : '권리산정 ${Dates.ymd(widget.zoneRightsDate!)}'
                                '${widget.p.approvedOn == null ? '' : ' · 사용승인 ${Dates.ymd(widget.p.approvedOn!)}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textSecondary)),
                  ),
                ]),
              ),
              if (widget.rights.isBlocking) ...[
                const Gap(6),
                Text(widget.rights.why,
                    style: const TextStyle(
                        fontSize: AppFont.caption,
                        color: AppColors.rose,
                        height: 1.5)),
              ],
            ],
            // 판정에 «다음에 필요한 값» 하나만. 여러 개 늘어놓으면 안 채운다.
            if (!widget.rights.isBlocking &&
                widget.band != BuyBand.blocked) ...[
              Builder(builder: (context) {
                final need = nextMissing(p);
                final (done, total) = filledCount(p);
                if (need == null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Row(children: [
                      const Icon(Icons.task_alt_rounded,
                          size: 14, color: AppColors.primary),
                      const Gap(8),
                      Text('판정값 $total/$total 다 채웠다',
                          style: const TextStyle(
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ]),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: InkWell(
                    onTap: () => _fill(context, need),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: _teal.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.edit_note_rounded,
                            size: 15, color: _teal),
                        const Gap(8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('다음에 채울 것 — ${need.label}',
                                style: const TextStyle(
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w800,
                                    color: _teal)),
                            const Gap(2),
                            Text(need.why,
                                style: const TextStyle(
                                    fontSize: AppFont.micro,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                        const Spacer(),
                        Text('$done/$total',
                            style: const TextStyle(
                                fontSize: AppFont.caption,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textFaint)),
                      ]),
                    ),
                  ),
                );
              }),
            ],
            const Gap(12),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.section, fontWeight: FontWeight.w700)),
                    if ((p.address ?? '').isNotEmpty || (p.caseNo ?? '').isNotEmpty) ...[
                      const Gap(3),
                      Text(
                          [p.address, p.caseNo]
                              .where((e) => (e ?? '').isNotEmpty)
                              .join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: AppFont.label)),
                    ],
                  ],
                ),
              ),
              const Gap(8),
              Pill(p.isSim ? '모의' : '실제',
                  color: p.isSim ? AppColors.violet : AppColors.primary),
              const Gap(6),
              if (p.isQuickSale) ...[
                const Pill('급매', color: AppColors.gold),
                const Gap(6),
              ],
              if (p.isPlus) ...[
                const Pill('플피', color: AppColors.violet),
                const Gap(6),
              ],
              if (p.corpStatus != null) ...[
                Pill(_corpLabel(p.corpStatus!), color: _corpColor(p.corpStatus!)),
                const Gap(6),
              ],
              if (!p.isQuickSale && d != null) ...[
                Pill(
                    p.bidPassed
                        ? '입찰 종료'
                        : (d == 0 ? '오늘 입찰' : 'D-$d'),
                    color: p.bidPassed
                        ? AppColors.textFaint
                        : (d <= 7 ? AppColors.rose : AppColors.violet)),
                const Gap(6),
              ],
              Pill(_statusLabel[p.status] ?? p.status,
                  color: _statusColor[p.status] ?? AppColors.textFaint),
              const Gap(6),
              _ScorePill(score: p.score, verdict: p.verdict, color: vColor),
              if (!p.isQuickSale)
                GestureDetector(
                  onTap: () => widget.onToggleAlert(!p.alertEnabled),
                  child: Tooltip(
                    message: p.alertEnabled
                        ? '매각기일 알림 켜짐 (D-3·2·1)'
                        : '매각기일 알림 받기',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        p.alertEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: 19,
                        color: p.alertEnabled
                            ? AppColors.gold
                            : AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AppColors.textFaint, size: 20),
                color: AppColors.surfaceAlt,
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'edit') {
                    onOpen();
                  } else if (v == 'exclude') {
                    widget.onToggleExclude(!p.excluded);
                  } else if (v == 'delete') {
                    onDelete();
                  } else if (v == 'corp_ok') {
                    widget.onSetCorp('ok');
                  } else if (v == 'corp_heavy') {
                    widget.onSetCorp('heavy');
                  } else if (v == 'corp_check') {
                    widget.onSetCorp('check');
                  } else if (v == 'corp_clear') {
                    widget.onSetCorp(null);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(
                      value: 'exclude',
                      child: Text(p.excluded ? '목록에 복원' : '목록에서 제외')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'corp_ok', child: Text('법인: 가능 (공시가1억↓)')),
                  const PopupMenuItem(
                      value: 'corp_check', child: Text('법인: 확인필요')),
                  const PopupMenuItem(
                      value: 'corp_heavy', child: Text('법인: 중과(12%)')),
                  if (p.corpStatus != null)
                    const PopupMenuItem(
                        value: 'corp_clear', child: Text('법인: 태그 지우기')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ),
          if (widget.price.stale) ...[
            const Gap(12),
            _Warn(
                text: '단지 시세조사가 ${widget.price.ageDays}일 전 기록 · '
                    '단지·시세 탭에서 갱신하세요',
                color: AppColors.gold),
          ],
          // 경고 배너
          if (p.overMaxBid || p.belowTarget) ...[
            const Gap(12),
            _Warn(
              text: p.overMaxBid
                  ? '입찰가가 최대입찰가(${Won.compact(p.maxBid)}원)를 초과 · 입찰 비추천'
                  : '예상순수익이 목표수익(${Won.compact(p.targetProfit)}원)에 미달',
            ),
          ],
          const Gap(12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _metric(
                  widget.price.fromComplex ? '현재시세 · 단지' : '현재시세',
                  widget.price.sale <= 0
                      ? '—'
                      : '${Won.compact(widget.price.sale)}원',
                  color: widget.price.fromComplex ? AppColors.sky : null),
              _metric('예상매도가', '${Won.compact(p.expectedSalePrice)}원'),
              _metric('예상입찰가', '${Won.compact(p.bidPrice)}원'),
              _metric('할인율', Pct.of(p.discountRate),
                  color: p.discountRate > 0 ? AppColors.primary : null),
              if (p.isPlus) ...[
                // 플피형은 ROI 가 아니라 실투자금을 본다.
                _metric(widget.price.fromComplex ? '전세 · 단지' : '전세',
                    widget.price.jeonse <= 0
                        ? '—'
                        : '${Won.compact(widget.price.jeonse)}원',
                    color: widget.price.jeonse >= p.bidPrice && p.bidPrice > 0
                        ? AppColors.primary
                        : (widget.price.fromComplex ? AppColors.sky : null)),
                _metric(p.ownCash <= 0 ? '플피' : '실투자금',
                    '${Won.compact(p.ownCash <= 0 ? p.plusPi : p.ownCash)}원',
                    color: p.ownCash <= 0 ? AppColors.primary : AppColors.gold),
              ] else
                _metric('필요현금', '${Won.compact(p.cashNeeded)}원',
                    color: AppColors.gold),
              _metric('예상순수익', '${Won.compact(p.netProfit)}원',
                  color: p.netProfit >= 0 ? AppColors.primary : AppColors.rose),
              _metric(p.depositLabel, '${Won.compact(p.depositDue)}원',
                  color: AppColors.gold),
              if (!p.isPlus)
                _metric('ROI', Pct.of(p.roi),
                    color: p.roi >= 0 ? AppColors.primary : AppColors.rose),
              _metric('최대입찰가', '${Won.compact(p.maxBid)}원',
                  color: AppColors.sky),
            ],
          ),
          if (_open && (p.memo ?? '').isNotEmpty) ...[
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(p.memo!,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFont.label,
                      height: 1.55)),
            ),
          ],
          const Gap(12),
          Row(children: [
            const Text('할까?',
                style: TextStyle(
                    fontSize: AppFont.label,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
            const Gap(10),
            _vChip('GO', '할래'),
            const Gap(6),
            _vChip('HOLD', '보류'),
            const Gap(6),
            _vChip('PASS', '패스'),
          ]),
          const Gap(10),
          Row(
            children: [
              if ((p.memo ?? '').isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 3),
                    child: Row(children: [
                      Icon(
                          _open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textSecondary),
                      const Gap(3),
                      Text(_open ? '접기' : '추천포인트·입지·이력',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              const Spacer(),
              if (p.images.isNotEmpty) ...[
                const Icon(Icons.photo_library_rounded,
                    size: 13, color: AppColors.textFaint),
                const Gap(3),
                Text('${p.images.length}',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.caption)),
                const Gap(8),
              ],
              const Text('상세 열기',
                  style: TextStyle(
                      color: _teal, fontSize: AppFont.label, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _teal),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _vChip(String v, String label) {
    final on = widget.p.verdict == v;
    final c = _verdictColor(v);
    return GestureDetector(
      onTap: () => widget.onSetVerdict(v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: on ? c : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? c : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFont.caption)),
          const Gap(3),
          Text(value,
              style: TextStyle(
                  fontSize: AppFont.section,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.textPrimary)),
        ],
      );
}

class _ScorePill extends StatelessWidget {
  final double score;
  final String verdict;
  final Color color;
  const _ScorePill(
      {required this.score, required this.verdict, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(verdict,
              style: TextStyle(
                  color: color, fontSize: AppFont.label, fontWeight: FontWeight.w900)),
          if (score > 0) ...[
            const Gap(6),
            Text('${score.toStringAsFixed(0)}점',
                style: TextStyle(
                    color: color, fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _Warn extends StatelessWidget {
  final String text;
  final Color? color;
  const _Warn({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.rose;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
              color == null
                  ? Icons.warning_amber_rounded
                  : Icons.account_balance_wallet_rounded,
              color: c,
              size: 16),
          const Gap(8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}


/// 경매 화면 상단 전환 탭 (물건 / 자료실).

