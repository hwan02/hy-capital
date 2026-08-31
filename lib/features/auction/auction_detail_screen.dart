import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_field.dart';
import '../../models/models.dart';
import 'progress.dart' show kStatusOptions;
import 'auction_checklist.dart';
import '../property/inherit.dart';

const _teal = Color(0xFF14B8A6);

Color _verdictColor(String v) => switch (v) {
      'GO' => AppColors.primary,
      'PASS' => AppColors.rose,
      _ => AppColors.gold,
    };

class AuctionDetailScreen extends ConsumerWidget {
  final String id;
  const AuctionDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auctionProvider);
    return async.when(
      loading: () => const Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: Text('오류: $e'))),
      data: (items) {
        final p = items.where((e) => e.id == id).firstOrNull;
        if (p == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(backgroundColor: AppColors.bg),
            body: const Center(child: Text('물건을 찾을 수 없어요')),
          );
        }
        return _DetailBody(p: p);
      },
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final AuctionProperty p;
  const _DetailBody({required this.p});

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _checklistKey = GlobalKey<AuctionChecklistFormState>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _update(Map<String, dynamic> data) async {
    await ref
        .read(supabaseProvider)
        .from('auction_properties')
        .update(data)
        .eq('id', widget.p.id);
    invalidateAll(ref);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final vColor = _verdictColor(p.verdict);
    final zones = ref.watch(zonesProvider).asData?.value ?? const <Zone>[];
    final zone = matchZoneForAddress(p.address, zones);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/auction'),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Pill(p.verdict, color: vColor),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: _teal,
          labelColor: _teal,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.search_rounded, size: 19), text: '조사표'),
            Tab(icon: Icon(Icons.photo_library_rounded, size: 19), text: '사진'),
            Tab(icon: Icon(Icons.calculate_rounded, size: 19), text: '계산기'),
            Tab(icon: Icon(Icons.rule_rounded, size: 19), text: '모아판정'),
            Tab(icon: Icon(Icons.checklist_rounded, size: 19), text: '손품·발품'),
            Tab(icon: Icon(Icons.edit_note_rounded, size: 19), text: '메모'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SurveyTab(p: p, formKey: _checklistKey, onSave: _update),
          _PhotosTab(p: p, onSave: _update),
          _CalcTab(
              p: p,
              zone: zone,
              price: effectivePrice(
                  p,
                  ref.watch(latestSurveysProvider).asData?.value ??
                      const <String, PriceSurvey>{}),
              onSave: _update),
          _MoaTab(p: p, price: effectivePrice(
                  p,
                  ref.watch(latestSurveysProvider).asData?.value ??
                      const <String, PriceSurvey>{}),
              onSave: _update),
          _ChecksTab(p: p, onSave: _update),
          _MemoTab(p: p, onSave: _update),
        ],
      ),
    );
  }
}

// ── 조사표 탭 ───────────────────────────────────────────────
class _SurveyTab extends StatelessWidget {
  final AuctionProperty p;
  final GlobalKey<AuctionChecklistFormState> formKey;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _SurveyTab(
      {required this.p, required this.formKey, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: _teal, size: 20),
                const Gap(10),
                Expanded(
                  child: Text(
                      p.currentPrice > 0
                          ? '현재시세 (자동) ${Won.compact(p.currentPrice)}원'
                          : '시세 평균가를 채우면 현재시세가 자동 계산돼요',
                      style: const TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Gap(18),
          AuctionChecklistForm(
              key: formKey, initial: p.checklist, strategy: p.strategy),
          const Gap(18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              onPressed: () async {
                final st = formKey.currentState;
                if (st == null) return;
                final (data, price) = st.collect();
                await onSave({'checklist': data, 'current_price': price});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(price > 0
                        ? '저장됨 · 현재시세 ${Won.compact(price)}원'
                        : '저장됨'),
                    backgroundColor: _teal,
                  ));
                }
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('조사표 저장 · 현재시세 계산'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 사진 탭 ───────────────────────────────────────────────
class _PhotosTab extends StatefulWidget {
  final AuctionProperty p;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _PhotosTab({required this.p, required this.onSave});

  @override
  State<_PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<_PhotosTab> {
  bool _busy = false;

  Future<void> _pick() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    setState(() => _busy = true);
    final urls = <String>[...widget.p.images];
    for (final f in files) {
      final reader = html.FileReader();
      reader.readAsDataUrl(f);
      await reader.onLoad.first;
      urls.add(reader.result as String);
    }
    await widget.onSave({'images': urls});
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(int i) async {
    final urls = <String>[...widget.p.images]..removeAt(i);
    await widget.onSave({'images': urls});
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.p.images;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 19),
            label: Text(_busy ? '올리는 중…' : '경매 스크린샷 올리기'),
          ),
          const Gap(8),
          const Text('물건상세·감정평가·현황조사서·임차인 현황 등 캡처를 여러 장 올리세요.',
              style: TextStyle(color: AppColors.textFaint, fontSize: AppFont.label)),
          const Gap(18),
          if (imgs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                  icon: Icons.image_rounded, message: '아직 올린 사진이 없어요'),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: imgs.length,
              itemBuilder: (_, i) => _PhotoTile(
                url: imgs[i],
                onRemove: () => _remove(i),
                onView: () => _viewer(context, imgs, i),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  final VoidCallback onView;
  const _PhotoTile(
      {required this.url, required this.onRemove, required this.onView});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onView,
            child: Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.broken_image_rounded,
                        color: AppColors.textFaint))),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _viewer(BuildContext context, List<String> imgs, int start) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: PageView.builder(
        controller: PageController(initialPage: start),
        itemCount: imgs.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Image.network(imgs[i], fit: BoxFit.contain),
        ),
      ),
    ),
  );
}

// ── 계산기 탭 ───────────────────────────────────────────────
/// 입찰가 산정 시 고려사항 도움말 (ⓘ 로 펼침).
class _BidTips extends StatefulWidget {
  const _BidTips();
  @override
  State<_BidTips> createState() => _BidTipsState();
}

class _BidTipsState extends State<_BidTips> {
  bool _ex = false; // 예시 펼치기

  static const _items = <(String, String)>[
    ('매매 실거래가', '인근 같은 평형의 최근 실제 거래가 — 가치 판단의 기준'),
    ('급매가격', '지금 시장에 나온 급매 호가 — 낙찰가가 이보다 낮아야 의미'),
    ('취득세', '낙찰가 기준 · 다주택/중과 여부 확인'),
    ('각종 비용', '명도비 · (미납)관리비 · 수리비 · 중개수수료 등'),
  ];

  // 예시 — 2024타경535019
  static const _ex1 = <(String, String, bool)>[
    ('감정가', '3억 8,900만', false),
    ('취등록·법무비', '600만', false),
    ('인테리어', '1,500만', false),
    ('입주청소', '50만', false),
    ('명도비', '200만', false),
    ('총 비용', '2,350만', false),
    ('입찰가', '2억 7,230만', true),
    ('입찰가 + 총비용', '2억 9,580만', false),
    ('매도 예상가', '3억 3,000만', false),
    ('예상 수익', '3,420만', true),
  ];

  Widget _exRow(String k, String v, bool hi) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: hi ? FontWeight.w800 : FontWeight.w500,
                    color: hi ? _teal : AppColors.textSecondary)),
            Text(v,
                style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: hi ? FontWeight.w800 : FontWeight.w600,
                    color: hi ? _teal : AppColors.textPrimary)),
          ],
        ),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 5, color: _teal),
            ),
            const Gap(9),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: AppFont.label,
                      color: AppColors.textSecondary,
                      height: 1.45),
                  children: [
                    TextSpan(
                        text: '$k  ',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800)),
                    TextSpan(text: v),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('입찰가 산정 시 고려사항',
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: _teal)),
          const Gap(10),
          for (final (k, v) in _items) _row(k, v),
          const Gap(4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              '예상 수익 = 예상 매도가 − (입찰가 + 비용) − 세금\n= 실제 수익',
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.6),
            ),
          ),
          const Gap(8),
          InkWell(
            onTap: () => setState(() => _ex = !_ex),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    _ex
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _teal),
                const Gap(3),
                Text(_ex ? '예시 접기' : '실제 예시 보기 (2024타경535019)',
                    style: const TextStyle(
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700,
                        color: _teal)),
              ]),
            ),
          ),
          if (_ex) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                children: [
                  for (final (k, v, hi) in _ex1) _exRow(k, v, hi),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 물건 주소를 구역명(동+번지)과 매칭해 해당 모아타운 구역을 찾는다.
/// 근사 매칭 — 동 이름과 번지 숫자가 주소에 모두 들어가면 그 구역으로 본다.
Zone? matchZoneForAddress(String? address, List<Zone> zones) {
  if (address == null || address.isEmpty) return null;
  final a = address.replaceAll(' ', '');
  for (final z in zones) {
    // 동이 다르면 건너뛴다(다른 동의 같은 번지 오매칭 방지).
    final dong = RegExp(r'([가-힣]+?)[0-9]*동').firstMatch(z.name)?.group(1);
    if (dong != null && dong.isNotEmpty && !a.contains(dong)) continue;
    // 1) 구역명 대표 번지
    final beonji = RegExp(r'동\s*([0-9]+)').firstMatch(z.name)?.group(1);
    if (beonji != null && a.contains(beonji)) return z;
    // 2) 포함 번지 목록(aliases)
    for (final al in z.aliases) {
      if (al.isNotEmpty && a.contains(al)) return z;
    }
  }
  return null;
}

class _CalcTab extends StatefulWidget {
  final AuctionProperty p;
  final EffectivePrice price; // 단지에서 상속받은 시세
  final Zone? zone; // 주소로 매칭된 모아타운 구역(단계 표시용)
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _CalcTab(
      {required this.p,
      required this.price,
      required this.onSave,
      this.zone});

  @override
  State<_CalcTab> createState() => _CalcTabState();
}

class _CalcTabState extends State<_CalcTab> {
  late double bid, sale, loan, acq, repair, evict, other, saleCost, finance, target, score;
  late String verdict;
  late String status;   // interest→…→won(낙찰)→sold(매각완료)
  late String strategy; // flip=아파트 차익 · plus=모아·신속 빌라 플피
  late double jeonse;   // 전세 시세 — 플피 계산의 핵심
  bool _tips = false;   // 입찰가 산정 고려사항 펼치기
  late String mode;     // sim=모의 · real=실제
  late double actual;   // 실제 낙찰가
  final _reasonC = TextEditingController(); // 판단 근거
  final _reviewC = TextEditingController();  // 원인분석(회고)

  // 진행 상태 옵션 — progress.dart 의 9단계 + 종료 상태.
  static final _statuses = kStatusOptions;

  @override
  void initState() {
    super.initState();
    final p = widget.p;
    // 시세는 단지 조사값을 우선 쓴다 — 매물마다 다시 입력하지 않는다.
    final cp = widget.price.sale > 0 ? widget.price.sale : p.currentPrice;
    sale = p.expectedSalePrice > 0 ? p.expectedSalePrice : cp;
    bid = p.bidPrice > 0 ? p.bidPrice : (cp * 0.85);
    loan = p.loanAmount;
    acq = p.acquisitionCost;
    repair = p.repairCost;
    evict = p.evictionCost;
    other = p.otherCost;
    saleCost = p.saleCost;
    finance = p.financeCost;
    target = p.targetProfit;
    score = p.score;
    verdict = p.verdict;
    status = p.status;
    strategy = p.strategy;
    jeonse = p.jeonsePrice > 0 ? p.jeonsePrice : widget.price.jeonse;
    mode = p.mode;
    actual = p.actualPrice;
    _reasonC.text = p.reason ?? '';
    _reviewC.text = p.review ?? '';
  }

  @override
  void dispose() {
    _reasonC.dispose();
    _reviewC.dispose();
    super.dispose();
  }

  bool get isPlus => strategy == 'plus';

  /// 실투자금(플피형) = 낙찰가 + 선투입비용 − 전세보증금.
  /// 전세를 놓으면 경락잔금대출은 통상 못 쓰므로 대출을 빼지 않는다.
  double get ownCash => bid + acq + repair + evict + other - jeonse;
  double get plusPi => ownCash < 0 ? -ownCash : 0;
  bool get jeonseCoversBid => jeonse > 0 && jeonse >= bid;

  double get _costs => acq + repair + evict + other + saleCost + finance;
  double get cashNeeded => bid - loan + acq + repair + evict + other;
  double get netProfit => sale - bid - _costs;
  double get roi => cashNeeded <= 0 ? 0 : netProfit / cashNeeded * 100;
  double get maxBid => sale - _costs - target;
  bool get overMax => maxBid > 0 && bid > maxBid;

  @override
  Widget build(BuildContext context) {
    final cp = widget.price.sale > 0 ? widget.price.sale : widget.p.currentPrice;
    final maxRange = ((cp > 0 ? cp : (sale > 0 ? sale : 500000000)) * 1.2)
        .clamp(100000000, double.infinity)
        .toDouble();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.zone != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.10),
                border: Border.all(color: _teal.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.route_rounded, size: 16, color: _teal),
                const Gap(9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                              '${widget.zone!.name} · ${widget.zone!.stage}단계 ${widget.zone!.stageLabel}',
                              style: const TextStyle(
                                  fontSize: AppFont.label,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (widget.zone!.consentRate > 0)
                          Pill(
                              '동의율 ${widget.zone!.consentRate.toStringAsFixed(0)}%',
                              color: widget.zone!.imminent
                                  ? AppColors.primary
                                  : AppColors.gold),
                      ]),
                      if ((widget.zone!.stageSource ?? '').isNotEmpty) ...[
                        const Gap(2),
                        Text(widget.zone!.stageSource!,
                            style: const TextStyle(
                                fontSize: AppFont.caption,
                                color: AppColors.textFaint)),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            const Gap(14),
          ],
          if (widget.price.fromComplex) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.10),
                border:
                    Border.all(color: AppColors.sky.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.domain_rounded,
                    size: 15, color: AppColors.sky),
                const Gap(9),
                Expanded(
                  child: Text(
                      '시세는 «단지 시세조사»에서 가져왔다 — '
                      '${widget.price.ageDays}일 전 기록'
                      '${widget.price.stale ? " · 갱신 권장" : ""}',
                      style: TextStyle(
                          color: widget.price.stale
                              ? AppColors.gold
                              : AppColors.textSecondary,
                          fontSize: AppFont.label)),
                ),
              ]),
            ),
            const Gap(14),
          ],
          // 전략 유형 — 셈이 완전히 다르므로 여기서 먼저 고른다.
          Row(children: [
            const Text('전략',
                style: TextStyle(
                    fontSize: AppFont.label, color: AppColors.textSecondary)),
            const Gap(12),
            _stratChip('flip', '아파트 차익', Icons.trending_up_rounded),
            const Gap(6),
            _stratChip('plus', '빌라 플피', Icons.savings_rounded),
          ]),
          const Gap(6),
          Text(
              isPlus
                  ? '낙찰 → 전세로 회수(플피) → 조합설립 프리미엄 → 매매. 핵심은 «실투자금».'
                  : '낙찰 → 수리 → 매도 차익. 핵심은 ROI.',
              style: const TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint)),
          const Gap(14),
          // 예상입찰가 슬라이더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Text('예상 입찰가',
                          style: TextStyle(
                              fontSize: AppFont.label,
                              color: AppColors.textSecondary)),
                      const Gap(6),
                      Tooltip(
                        message: '입찰가 산정 시 고려사항 보기',
                        child: InkWell(
                          onTap: () => setState(() => _tips = !_tips),
                          borderRadius: BorderRadius.circular(20),
                          child: Icon(
                              _tips
                                  ? Icons.help_rounded
                                  : Icons.help_outline_rounded,
                              size: 17,
                              color: _tips ? _teal : AppColors.textFaint),
                        ),
                      ),
                    ]),
                    Text('${Won.compact(bid)}원',
                        style: const TextStyle(
                            fontSize: AppFont.display,
                            fontWeight: FontWeight.w900,
                            color: _teal)),
                  ],
                ),
                if (_tips) ...[
                  const Gap(12),
                  const _BidTips(),
                ],
                Slider(
                  value: bid.clamp(0, maxRange),
                  min: 0,
                  max: maxRange,
                  divisions: 120,
                  activeColor: _teal,
                  onChanged: (v) => setState(() => bid = v),
                ),
                if (cp > 0)
                  Text(
                      '현재시세 ${Won.compact(cp)}원 대비 ${((cp - bid) / cp * 100).toStringAsFixed(0)}% 할인',
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: AppFont.label)),
              ],
            ),
          ),
          const Gap(16),
          // 실시간 결과
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              if (isPlus) ...[
                // 실투자금이 음수면 돈이 남는다(플피).
                _metric(
                    ownCash <= 0 ? '플피 (남는 돈)' : '실투자금',
                    '${Won.compact(ownCash <= 0 ? plusPi : ownCash)}원',
                    ownCash <= 0 ? AppColors.primary : AppColors.gold),
                _metric('전세 − 낙찰가', '${Won.compact(jeonse - bid)}원',
                    jeonseCoversBid ? AppColors.primary : AppColors.rose),
                _metric('예상순수익', '${Won.compact(netProfit)}원',
                    netProfit >= 0 ? AppColors.primary : AppColors.rose),
                _metric('최대입찰가', '${Won.compact(maxBid)}원', AppColors.sky),
              ] else ...[
                _metric('필요현금', '${Won.compact(cashNeeded)}원', AppColors.gold),
                _metric('예상순수익', '${Won.compact(netProfit)}원',
                    netProfit >= 0 ? AppColors.primary : AppColors.rose),
                _metric('ROI', '${roi.toStringAsFixed(0)}%',
                    roi >= 0 ? AppColors.primary : AppColors.rose),
                _metric('최대입찰가', '${Won.compact(maxBid)}원', AppColors.sky),
              ],
            ],
          ),
          if (isPlus && jeonse > 0 && !jeonseCoversBid) ...[
            const Gap(12),
            _warn('전세가(${Won.compact(jeonse)}원)가 낙찰가보다 낮음 · '
                '플피 전략의 전제가 무너집니다'),
          ],
          if (isPlus && jeonse <= 0) ...[
            const Gap(12),
            _warn('전세 시세를 넣어야 실투자금이 계산됩니다 · 입찰 전에 반드시 확인'),
          ],
          if (overMax) ...[
            const Gap(12),
            _warn('입찰가가 최대입찰가(${Won.compact(maxBid)}원)를 초과 · 입찰 비추천'),
          ],
          const Gap(20),
          const Text('금액 입력',
              style: TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _money('예상 매도가', sale, (v) => setState(() => sale = v)),
              if (isPlus)
                _money('전세 시세', jeonse, (v) => setState(() => jeonse = v))
              else
                _money('경락잔금대출', loan, (v) => setState(() => loan = v)),
              _money('취득·등기비', acq, (v) => setState(() => acq = v)),
              _money('수리/인테리어', repair, (v) => setState(() => repair = v)),
              _money('명도비', evict, (v) => setState(() => evict = v)),
              _money('기타/예비비', other, (v) => setState(() => other = v)),
              _money('매도비용', saleCost, (v) => setState(() => saleCost = v)),
              _money('대출이자', finance, (v) => setState(() => finance = v)),
              _money('목표수익', target, (v) => setState(() => target = v)),
            ],
          ),
          const Gap(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('상태',
                    style: TextStyle(
                        fontSize: AppFont.label,
                        color: AppColors.textSecondary)),
              ),
              const Gap(12),
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (k, l, c) in _statuses) _statusChip(k, l, c),
                ]),
              ),
            ],
          ),
          const Gap(16),
          Row(
            children: [
              const Text('판단',
                  style: TextStyle(fontSize: AppFont.label, color: AppColors.textSecondary)),
              const Gap(12),
              for (final v in ['GO', 'HOLD', 'PASS']) ...[
                _verdictChip(v),
                const Gap(6),
              ],
              const Spacer(),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: score > 0 ? score.toStringAsFixed(0) : '',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: '점수', isDense: true),
                  onChanged: (v) => score = double.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
          const Gap(20),
          Row(children: [
            const Text('모의투자 로그',
                style: TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            const Gap(8),
            Icon(mode == 'real' ? Icons.verified_rounded : Icons.science_rounded,
                size: 16,
                color: mode == 'real' ? AppColors.primary : AppColors.violet),
          ]),
          const Gap(2),
          const Text('실제로 하기 전에 모의로 부르고, 낙찰가를 적어 회고한다',
              style: TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint)),
          const Gap(10),
          Row(children: [
            _modeChip('sim', '모의', Icons.science_rounded, AppColors.violet),
            const Gap(8),
            _modeChip('real', '실제', Icons.verified_rounded, AppColors.primary),
          ]),
          const Gap(12),
          TextField(
            controller: _reasonC,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(fontSize: AppFont.label, height: 1.45),
            decoration: const InputDecoration(
                labelText: '판단 근거 — 왜 이 물건·이 입찰가?',
                alignLabelWithHint: true),
          ),
          const Gap(12),
          Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _metric('내 입찰가', '${Won.compact(bid)}원', _teal),
            _money('실제 낙찰가', actual, (v) => setState(() => actual = v)),
          ]),
          if (actual > 0) ...[
            const Gap(10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (bid >= actual ? AppColors.primary : AppColors.rose)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                bid >= actual
                    ? '내 입찰가가 낙찰가보다 ${Won.compact(bid - actual)}원 높음 → 낙찰이었을 것 (이겼다)'
                    : '내 입찰가가 낙찰가보다 ${Won.compact(actual - bid)}원 낮음 → 패찰 (더 썼어야)',
                style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700,
                    color: bid >= actual ? AppColors.primary : AppColors.rose),
              ),
            ),
          ],
          const Gap(12),
          TextField(
            controller: _reviewC,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontSize: AppFont.label, height: 1.45),
            decoration: const InputDecoration(
                labelText: '원인분석(회고) — 왜 이 결과였나',
                alignLabelWithHint: true),
          ),
          const Gap(16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              onPressed: () async {
                await widget.onSave({
                  'mode': mode,
                  'actual_price': actual,
                  'reason': _reasonC.text.trim(),
                  'review': _reviewC.text.trim(),
                  'bid_price': bid,
                  'expected_sale_price': sale,
                  'loan_amount': loan,
                  'acquisition_cost': acq,
                  'repair_cost': repair,
                  'eviction_cost': evict,
                  'other_cost': other,
                  'sale_cost': saleCost,
                  'finance_cost': finance,
                  'target_profit': target,
                  'strategy': strategy,
                  'jeonse_price': jeonse,
                  'score': score,
                  'verdict': verdict,
                  'status': status,
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('계산 결과 저장됨'), backgroundColor: _teal));
                }
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.caption)),
            const Gap(3),
            Text(value,
                style: TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );

  Widget _money(String label, double value, ValueChanged<double> onChanged) =>
      SizedBox(
        width: 196,
        child: MoneyField(
            label: label,
            initial: value,
            onChanged: onChanged,
            dense: true,
            accent: _teal),
      );

  Widget _stratChip(String key, String label, IconData icon) {
    final on = strategy == key;
    final c = key == 'plus' ? AppColors.violet : _teal;
    return InkWell(
      onTap: () => setState(() => strategy = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: on ? c : AppColors.border, width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: on ? c : AppColors.textFaint),
          const Gap(6),
          Text(label,
              style: TextStyle(
                  color: on ? c : AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _modeChip(String key, String label, IconData icon, Color c) {
    final on = mode == key;
    return InkWell(
      onTap: () => setState(() => mode = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border:
              Border.all(color: on ? c : AppColors.border, width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: on ? c : AppColors.textFaint),
          const Gap(6),
          Text(label,
              style: TextStyle(
                  color: on ? c : AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _statusChip(String key, String label, Color c) {
    final on = status == key;
    return InkWell(
      onTap: () => setState(() => status = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: on ? c : AppColors.border),
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

  Widget _verdictChip(String v) {
    final on = verdict == v;
    final c = _verdictColor(v);
    return InkWell(
      onTap: () => setState(() => verdict = v),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: on ? c : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(v,
            style: TextStyle(
                color: on ? c : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _warn(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.rose, size: 16),
            const Gap(8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: AppColors.rose,
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

// ── 메모 탭 ───────────────────────────────────────────────
// ── 손품·발품 체크리스트 ──────────────────────────────────
const _sonpum = <(String, String, String)>[
  ('sp_profit', '예상수익 3,000만원↑', '빌라는 최소 3천만↑ 나는 것만. 안 되면 패스'),
  ('sp_bldg', '건축물대장 확인(현황=실제)', '대장과 실제 다른지(위반·용도·면적)'),
  ('sp_illegal', '위반건축물이면 패스', '대장에 위반 표기 시 거른다'),
  ('sp_geun', '근린생활시설이면 패스', '근생빌라(주택 아님) 제외'),
  ('sp_newsale', '신축분양빌라 패스', '분양 프리미엄 얹힌 건 단타 부적합'),
  ('sp_regi', '등기부 소유권보존·근저당', '최선순위 근저당/압류 = 말소기준'),
  ('sp_withdraw', '취하 가능성(채무 vs 낙찰가)', '등기부 채무액과 낙찰가 비교 — 취하 위험 늘 파악'),
  ('sp_year', '연식 확인', '신축/구옥 시세 크게 갈림'),
  ('sp_aptprice', '주변 아파트 시세', '빌라 가치 상한 가늠'),
  ('sp_deal', '최근 거래시점(매매/월세)', '언제 거래됐는지'),
  ('sp_loc', '역세권·초품아/중품빌', '학교·역 인접 여부'),
  ('sp_stage', '재개발/재건축 단계·인프라', '모아타운 등 진행 단계'),
  ('sp_royal', '로얄층(엘베無 2~3층/有 5~6층)', '1층·탑층 비선호'),
  ('sp_fund', '투자금·이자·월세 커버 계산', '이자 내고 남는지, 시드 8천 안'),
];
const _balpum = <(String, String, String)>[
  ('bp_lease', '임차권등기명령·공실 여부', '전세사기 물건·현재 공실 확인'),
  ('bp_illegal', '위반건축물 등재 확인', '건축물대장 위반 표기'),
  ('bp_ext', '제시외 물건 확인', '등기 외 부속·증축'),
  ('bp_safety', '안전점검표·방수·우수관', '관리 상태 신호'),
  ('bp_leak', '옥상 누수(탑층만)', '물 고인 흔적 = 누수 위험'),
  ('bp_epoxy', '옥상 에폭시·방수(5~6층 매수 시)', '코팅 없으면 누수 위험·옆길 시멘트 확인'),
  ('bp_semi', '반지하 습기(비추)', '계단 3개 OK·8개 매우 습함·언덕/옆길 확인'),
  ('bp_park', '주차 세대당 1대', ''),
  ('bp_inter', '인테리어비 산정(입찰 전)', '리모델링 후 받을 값과 비교'),
  ('bp_price', '실매매가·급매가 확인', '호가 말고 성사가'),
  ('bp_rent', '월세 시세(연식·층·엘베별)', '3000/70, 5000/80 식으로'),
  ('bp_multi', '부동산 3곳↑ 교차', '물건과 사랑에 빠지지 말 것'),
];

class _ChecksTab extends StatefulWidget {
  final AuctionProperty p;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _ChecksTab({required this.p, required this.onSave});

  @override
  State<_ChecksTab> createState() => _ChecksTabState();
}

class _ChecksTabState extends State<_ChecksTab> {
  late Map<String, dynamic> _v;
  final Map<String, TextEditingController> _notes = {};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _v = Map<String, dynamic>.from(widget.p.checks);
    for (final it in [..._sonpum, ..._balpum]) {
      _notes[it.$1] =
          TextEditingController(text: (_v['${it.$1}__note'] ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _done(List<(String, String, String)> items) =>
      items.where((e) => _v[e.$1] == true).length;

  @override
  Widget build(BuildContext context) {
    final spDone = _done(_sonpum), bpDone = _done(_balpum);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('손품 (책상)', spDone, _sonpum.length, AppColors.sky),
          const Gap(6),
          for (final it in _sonpum) _tile(it, AppColors.sky),
          const Gap(18),
          _section('발품 (현장)', bpDone, _balpum.length, _teal),
          const Gap(6),
          for (final it in _balpum) _tile(it, _teal),
          const Gap(10),
          const Text('※ 질문 스크립트·상세는 자료실 «부동산 질문 스크립트/손품·발품 실전»에서.',
              style: TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint)),
          const Gap(16),
          if (_dirty)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
                onPressed: () async {
                  await widget.onSave({'checks': _v});
                  setState(() => _dirty = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('체크 저장됨'), backgroundColor: _teal));
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('저장'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, int done, int total, Color c) => Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          const Gap(8),
          Pill('$done/$total', color: done == total ? AppColors.primary : c),
        ],
      );

  Widget _tile((String, String, String) it, Color c) {
    final on = _v[it.$1] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() {
              _v[it.$1] = !on;
              _dirty = true;
            }),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                    on
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: on ? c : AppColors.textFaint,
                    size: 22),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.$2,
                          style: TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w700,
                              color: on ? AppColors.textFaint : null,
                              decoration:
                                  on ? TextDecoration.lineThrough : null)),
                      if (it.$3.isNotEmpty) ...[
                        const Gap(1),
                        Text(it.$3,
                            style: const TextStyle(
                                fontSize: AppFont.caption,
                                color: AppColors.textFaint)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: TextField(
              controller: _notes[it.$1],
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: AppFont.label),
              onChanged: (t) {
                _v['${it.$1}__note'] = t;
                if (!_dirty) setState(() => _dirty = true);
              },
              decoration: InputDecoration(
                hintText: '메모…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoTab extends StatefulWidget {
  final AuctionProperty p;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _MemoTab({required this.p, required this.onSave});

  @override
  State<_MemoTab> createState() => _MemoTabState();
}

class _MemoTabState extends State<_MemoTab> {
  late final TextEditingController _c;
  final _shopC = TextEditingController(); // 부동산명
  final _entryC = TextEditingController(); // 방문 내용

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.p.memo ?? '');
  }

  @override
  void dispose() {
    _c.dispose();
    _shopC.dispose();
    _entryC.dispose();
    super.dispose();
  }

  /// 부동산 방문 메모를 날짜·상호 붙여 맨 위에 누적하고 저장.
  Future<void> _addVisit() async {
    final txt = _entryC.text.trim();
    if (txt.isEmpty) return;
    final now = DateTime.now();
    final d =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final shop = _shopC.text.trim();
    final head = shop.isEmpty ? '[$d #부동산]' : '[$d $shop]';
    final line = '$head $txt';
    _c.text = _c.text.isEmpty ? line : '$line\n${_c.text}';
    await widget.onSave({'memo': _c.text});
    _entryC.clear();
    _shopC.clear();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('부동산 메모 추가됨'), backgroundColor: _teal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 부동산 방문 메모 빠른 추가 ──
          GlassCard(
            accent: _teal,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(children: [
                  Icon(Icons.storefront_rounded, size: 18, color: _teal),
                  Gap(6),
                  Text('부동산 방문 메모',
                      style: TextStyle(
                          fontSize: AppFont.section,
                          fontWeight: FontWeight.w800)),
                ]),
                const Gap(10),
                TextField(
                  controller: _shopC,
                  decoration: InputDecoration(
                    labelText: '부동산 상호 (선택)',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const Gap(8),
                TextField(
                  controller: _entryC,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '전세 2.6억까진 나감 · 매물 적음 · 다용도실 크다고 함',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const Gap(10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                    onPressed: _addVisit,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('메모에 추가'),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          const Text('#시세 #부동산전화 #대출 #권리 #임차인 #명도 #현장 #수리 #입찰',
              style: TextStyle(color: AppColors.textFaint, fontSize: AppFont.label)),
          const Gap(10),
          TextField(
            controller: _c,
            minLines: 8,
            maxLines: 20,
            decoration: InputDecoration(
              hintText:
                  '8/21 #부동산전화 - 동일 타입 12.8억이면 매도 가능성 높다고 함\n8/22 #대출 - A은행 5.5억, 금리 4.3%',
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const Gap(14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            onPressed: () async {
              await widget.onSave({'memo': _c.text});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('메모 저장됨'), backgroundColor: _teal));
              }
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('메모 저장'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 모아타운 단타 판정(6게이트) ──────────────────────────────
class _MoaTab extends StatefulWidget {
  final AuctionProperty p;
  final EffectivePrice price;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _MoaTab({required this.p, required this.price, required this.onSave});

  @override
  State<_MoaTab> createState() => _MoaTabState();
}

class _MoaTabState extends State<_MoaTab> {
  late double _official;
  late double _land;
  late String _pz; // out|in|unknown
  late int _deals;
  late int _listings;
  late final TextEditingController _note;
  late final TextEditingController _landC;
  late final TextEditingController _dealsC;
  late final TextEditingController _listC;

  @override
  void initState() {
    super.initState();
    final p = widget.p;
    _official = p.officialPrice;
    _land = p.landShare;
    _pz = p.projectZone ?? 'unknown';
    _deals = p.recentDeals;
    _listings = p.listingsCount;
    _note = TextEditingController(text: p.moaNote ?? '');
    _landC = TextEditingController(text: _land > 0 ? _trim(_land) : '');
    _dealsC = TextEditingController(text: _deals > 0 ? '$_deals' : '');
    _listC = TextEditingController(text: _listings > 0 ? '$_listings' : '');
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _note.dispose();
    _landC.dispose();
    _dealsC.dispose();
    _listC.dispose();
    super.dispose();
  }

  // 게이트 판정: (라벨, 상태 ok|no|check, 설명)
  List<(String, String, String)> _gates() {
    final sale = widget.price.sale > 0 ? widget.price.sale : widget.p.currentPrice;
    final jeonse =
        widget.price.jeonse > 0 ? widget.price.jeonse : widget.p.jeonsePrice;
    final gap = sale - jeonse;
    final g = <(String, String, String)>[];
    // G1 갭 ≤ 8천
    if (sale <= 0 || jeonse <= 0) {
      g.add(('G1 갭 ≤ 8천 (시드)', 'check', '현재시세·전세 입력 필요'));
    } else if (gap > 0 && gap <= 80000000) {
      g.add(('G1 갭 ≤ 8천 (시드)', 'ok', '갭 ${Won.compact(gap)}원'));
    } else {
      g.add(('G1 갭 ≤ 8천 (시드)', 'no', '갭 ${Won.compact(gap)}원 > 8천'));
    }
    // G2 공시가 ≤ 1억
    if (_official <= 0) {
      g.add(('G2 공시가 ≤ 1억 (법인 기본세율)', 'check', '공시가 입력 필요'));
    } else if (_official <= 100000000) {
      g.add(('G2 공시가 ≤ 1억 (법인 기본세율)', 'ok', '${Won.compact(_official)}원'));
    } else {
      g.add(('G2 공시가 ≤ 1억 (법인 기본세율)', 'no', '${Won.compact(_official)}원 > 1억 → 중과'));
    }
    // G3 사업시행구역 아님
    g.add(switch (_pz) {
      'out' => ('G3 사업시행구역 아님', 'ok', '미해당 → 1억↓ 중과제외 유지'),
      'in' => ('G3 사업시행구역 아님', 'no', '해당 → 법인 12% 중과'),
      _ => ('G3 사업시행구역 아님', 'check', '고시로 확인 필요'),
    });
    // G4 권리산정·입주권 (수동)
    g.add(('G4 권리산정일·입주권 승계', 'check', '메모로 직접 확인'));
    // G5 거래량
    if (_deals <= 0) {
      g.add(('G5 거래량(환금성)', 'check', '최근 실거래 건수 입력'));
    } else if (_deals >= 3) {
      g.add(('G5 거래량(환금성)', 'ok', '최근 $_deals건${_listings > 0 ? ' · 매물 $_listings' : ''}'));
    } else {
      g.add(('G5 거래량(환금성)', 'no', '최근 $_deals건 — 약함'));
    }
    // G6 프리미엄 매도가 (수동)
    g.add(('G6 6~12개월 내 프리미엄 매도가', 'check', '수요·매도가 직접 확인'));
    return g;
  }

  Color _sc(String s) => switch (s) {
        'ok' => AppColors.primary,
        'no' => AppColors.rose,
        _ => AppColors.gold,
      };
  IconData _si(String s) => switch (s) {
        'ok' => Icons.check_circle_rounded,
        'no' => Icons.cancel_rounded,
        _ => Icons.help_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final gates = _gates();
    final okN = gates.where((e) => e.$2 == 'ok').length;
    final noN = gates.where((e) => e.$2 == 'no').length;
    final checkN = gates.where((e) => e.$2 == 'check').length;
    final (verdict, vColor) = noN > 0
        ? ('복제 불가 / 보류 (탈락 $noN)', AppColors.rose)
        : checkN > 0
            ? ('확인 필요 ($checkN건)', AppColors.gold)
            : ('복제 가능', AppColors.primary);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('은천동 단기매도 복제 판정 — 6게이트',
              style: TextStyle(
                  fontSize: AppFont.title, fontWeight: FontWeight.w800)),
          const Gap(2),
          const Text('임장에서 채운 값으로 실시간 판정. 전부 O면 복제 가능.',
              style:
                  TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
          const Gap(16),

          // 판정 요약
          GlassCard(
            accent: vColor,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(_si(noN > 0 ? 'no' : (checkN > 0 ? 'check' : 'ok')),
                  color: vColor, size: 30),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(verdict,
                        style: TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800,
                            color: vColor)),
                    const Gap(2),
                    Text('통과 $okN · 탈락 $noN · 확인 $checkN / 6',
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textFaint)),
                  ],
                ),
              ),
            ]),
          ),
          const Gap(14),

          // 게이트 리스트
          for (final (label, st, detail) in gates) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _sc(st).withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(_si(st), color: _sc(st), size: 20),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w700)),
                      const Gap(1),
                      Text(detail,
                          style: const TextStyle(
                              fontSize: AppFont.caption,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ]),
            ),
          ],
          const Gap(10),

          // ── 입력 필드 ──
          const Text('임장 입력',
              style: TextStyle(
                  fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          const Gap(12),
          MoneyField(
              label: '공시가(시가표준액) 원',
              initial: _official,
              onChanged: (v) => setState(() => _official = v),
              dense: true,
              accent: _teal),
          const Gap(12),
          Row(children: [
            Expanded(child: _numField('대지지분 ㎡', _landC, (v) => _land = v)),
            const Gap(10),
            Expanded(
                child: _numField(
                    '최근 실거래(건)', _dealsC, (v) => _deals = v.toInt())),
            const Gap(10),
            Expanded(
                child: _numField(
                    '현재 매물(개)', _listC, (v) => _listings = v.toInt())),
          ]),
          const Gap(14),
          const Text('사업시행구역 여부 (G3 · 법인 중과 판정)',
              style: TextStyle(
                  fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          const Gap(8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pzChip('out', '미해당(1억↓ 유지)'),
            _pzChip('in', '해당(법인 중과)'),
            _pzChip('unknown', '미확인'),
          ]),
          const Gap(14),
          const Text('권리산정일 · 입주권 승계 · 기타 (G4/G6)',
              style: TextStyle(
                  fontSize: AppFont.label, fontWeight: FontWeight.w700)),
          const Gap(8),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  '권리산정기준일 2022-01-20 이전 취득 → 입주권 O\n조합설립 전 · 매도 6개월 내 2.9억 가능(부동산 확인)',
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const Gap(16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              onPressed: () async {
                await widget.onSave({
                  'official_price': _official,
                  'land_share': _land,
                  'project_zone': _pz,
                  'recent_deals': _deals,
                  'listings_count': _listings,
                  'moa_note': _note.text,
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('모아판정 저장됨'), backgroundColor: _teal));
                }
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(
          String label, TextEditingController c, ValueChanged<double> on) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: (t) => setState(() => on(double.tryParse(t.trim()) ?? 0)),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
      );

  Widget _pzChip(String key, String label) {
    final on = _pz == key;
    final c = key == 'in'
        ? AppColors.rose
        : (key == 'out' ? AppColors.primary : AppColors.gold);
    return InkWell(
      onTap: () => setState(() => _pz = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border:
              Border.all(color: on ? c : AppColors.border, width: on ? 1.4 : 1),
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
}

// ── 콤마 금액 입력 ──────────────────────────────────────────
