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
import '../../models/models.dart';
import 'auction_checklist.dart';

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
    _tab = TabController(length: 4, vsync: this);
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
            Tab(icon: Icon(Icons.edit_note_rounded, size: 19), text: '메모'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SurveyTab(p: p, formKey: _checklistKey, onSave: _update),
          _PhotosTab(p: p, onSave: _update),
          _CalcTab(p: p, onSave: _update),
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
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Gap(18),
          AuctionChecklistForm(key: formKey, initial: p.checklist),
          const Gap(20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
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
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
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
class _CalcTab extends StatefulWidget {
  final AuctionProperty p;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _CalcTab({required this.p, required this.onSave});

  @override
  State<_CalcTab> createState() => _CalcTabState();
}

class _CalcTabState extends State<_CalcTab> {
  late double bid, sale, loan, acq, repair, evict, other, saleCost, finance, target, score;
  late String verdict;

  @override
  void initState() {
    super.initState();
    final p = widget.p;
    sale = p.expectedSalePrice > 0 ? p.expectedSalePrice : p.currentPrice;
    bid = p.bidPrice > 0 ? p.bidPrice : (p.currentPrice * 0.85);
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
  }

  double get _costs => acq + repair + evict + other + saleCost + finance;
  double get cashNeeded => bid - loan + acq + repair + evict + other;
  double get netProfit => sale - bid - _costs;
  double get roi => cashNeeded <= 0 ? 0 : netProfit / cashNeeded * 100;
  double get maxBid => sale - _costs - target;
  bool get overMax => maxBid > 0 && bid > maxBid;

  @override
  Widget build(BuildContext context) {
    final cp = widget.p.currentPrice;
    final maxRange = ((cp > 0 ? cp : (sale > 0 ? sale : 500000000)) * 1.2)
        .clamp(100000000, double.infinity)
        .toDouble();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    const Text('예상 입찰가',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    Text('${Won.compact(bid)}원',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _teal)),
                  ],
                ),
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
                          color: AppColors.textFaint, fontSize: 12)),
              ],
            ),
          ),
          const Gap(16),
          // 실시간 결과
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _metric('필요현금', '${Won.compact(cashNeeded)}원', AppColors.gold),
              _metric('예상순수익', '${Won.compact(netProfit)}원',
                  netProfit >= 0 ? AppColors.primary : AppColors.rose),
              _metric('ROI', '${roi.toStringAsFixed(0)}%',
                  roi >= 0 ? AppColors.primary : AppColors.rose),
              _metric('최대입찰가', '${Won.compact(maxBid)}원', AppColors.sky),
            ],
          ),
          if (overMax) ...[
            const Gap(12),
            _warn('입찰가가 최대입찰가(${Won.compact(maxBid)}원)를 초과 · 입찰 비추천'),
          ],
          const Gap(20),
          const Text('금액 입력',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const Gap(10),
          _money('예상 매도가', sale, (v) => setState(() => sale = v)),
          _money('경락잔금대출', loan, (v) => setState(() => loan = v)),
          _money('취득·등기비', acq, (v) => setState(() => acq = v)),
          _money('수리/인테리어', repair, (v) => setState(() => repair = v)),
          _money('명도비', evict, (v) => setState(() => evict = v)),
          _money('기타/예비비', other, (v) => setState(() => other = v)),
          _money('매도비용(중개 등)', saleCost, (v) => setState(() => saleCost = v)),
          _money('대출이자/금융비용', finance, (v) => setState(() => finance = v)),
          _money('목표수익', target, (v) => setState(() => target = v)),
          const Gap(16),
          Row(
            children: [
              const Text('판단',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () async {
                await widget.onSave({
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
                  'score': score,
                  'verdict': verdict,
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
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11.5)),
            const Gap(3),
            Text(value,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );

  Widget _money(String label, double value, ValueChanged<double> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _MoneyField(label: label, initial: value, onChanged: onChanged),
      );

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
                fontSize: 12.5,
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

// ── 메모 탭 ───────────────────────────────────────────────
class _MemoTab extends StatefulWidget {
  final AuctionProperty p;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _MemoTab({required this.p, required this.onSave});

  @override
  State<_MemoTab> createState() => _MemoTabState();
}

class _MemoTabState extends State<_MemoTab> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.p.memo ?? '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('#시세 #부동산전화 #대출 #권리 #임차인 #명도 #현장 #수리 #입찰',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
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
          const Gap(16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding: const EdgeInsets.symmetric(vertical: 14)),
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
        ],
      ),
    );
  }
}

// ── 콤마 금액 입력 ──────────────────────────────────────────
class _MoneyField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;
  const _MoneyField(
      {required this.label, required this.initial, required this.onChanged});

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.initial > 0 ? _comma(widget.initial) : '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String _comma(double v) {
    final s = v.round().toString();
    return s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final n = double.tryParse(_c.text.replaceAll(',', '')) ?? 0;
    return TextField(
      controller: _c,
      keyboardType: TextInputType.number,
      inputFormatters: [_ThousandsFormatter()],
      onChanged: (v) {
        widget.onChanged(double.tryParse(v.replaceAll(',', '')) ?? 0);
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        suffixText: n > 0 ? Won.compact(n) : null,
        suffixStyle: const TextStyle(
            color: _teal, fontWeight: FontWeight.w800, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = digits.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
