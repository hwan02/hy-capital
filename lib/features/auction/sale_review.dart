// 경공매 오답노트 — 달력 물건 하나에 «내 예상 → 실제 결과 → 왜 → 나중에 다시 보기».
//
// ① 매각 전에 «얼마에 낙찰될까»를 적어 둔다(입찰했다면 내 입찰가도).
// ② 매각 뒤 낙찰가·응찰자·2위 가격을 넣으면 낙찰가율·예상 오차가 바로 나온다.
// ③ 왜 그 가격이었나 — 값을 올린 것/누른 것 태그 + 글, 그리고 «다음엔».
// ④ 몇 달 뒤(기본 매각일 +3달) 다시 열어 그 분석이 맞았는지 판정한다.
//
// 저장은 sale_items 한 줄(0069 컬럼). 쓰는 동안 2초마다 이 기기에 임시저장 —
// 메모를 쓰다 날린 적이 있어서, 긴 분석 글도 같은 방식으로 지킨다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/form_draft.dart';
import '../../core/edit/plain_controller.dart';
import '../../core/edit/record_form.dart' show pickDay;
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_field.dart';
import '../../core/widgets/save_key.dart';
import '../../models/models.dart';

const _accent = AppColors.gold;
const _up = AppColors.rose; // 값을 올린 요인
const _down = AppColors.sky; // 값을 누른 요인

const kReviewResults = ['낙찰', '유찰', '변경·취하'];

/// 왜 이 가격? — 낙찰가를 «올린» 것.
const kReasonsUp = ['구역 기대감', '시세보다 쌈', '전세가 높음', '권리 깨끗', '실수요', '경쟁 과열'];

/// 왜 이 가격? — 낙찰가를 «누른» 것.
const kReasonsDown = ['인수 부담', '하자·위치', '유찰 누적', '시장 침체', '대출 규제', '관심 적음'];

const kVerdicts = <String, Color>{
  '맞았다': AppColors.primary,
  '반반': AppColors.gold,
  '틀렸다': AppColors.rose,
};

/// 결과를 넣으면 «다시 볼 날»을 비워 둔 경우 매각일 + 이만큼으로 잡는다.
/// 3달이면 잔금·명도가 끝나고 전세·매물 시세가 보이기 시작한다.
const kReviewAfterDays = 90;

String _pct(double r) => Pct.of(r * 100, digits: r * 100 >= 100 ? 0 : 1);

// ─────────────────────────────── 단계 ───────────────────────────────

/// 오답노트에서 물건이 놓이는 칸 — 위에서부터 «지금 손댈 것» 순.
enum ReviewStage {
  reviewDue('다시 볼 날 됨', '그때 분석이 맞았나 판정하기'),
  awaitingResult('결과 넣기', '매각기일이 지났다 — 낙찰가·응찰자를 넣는다'),
  needsAnalysis('왜 이 가격?', '결과는 넣었다 — 왜 그 가격이었는지 적는다'),
  upcoming('매각 전', '얼마에 낙찰될지 미리 적어 두면 나중에 맞춰 본다'),
  waiting('다시 볼 날 기다림', '분석 끝 — 날이 되면 위로 올라온다'),
  done('끝난 노트', '판정까지 마쳤다');

  const ReviewStage(this.title, this.hint);
  final String title;
  final String hint;

  /// 손댈 게 남은 칸(토글 옆 숫자).
  bool get needsAction =>
      this == reviewDue || this == awaitingResult || this == needsAnalysis;
}

/// 오답노트에 들어오는 물건 — 태그를 달았거나(관심·임장·입찰예정·패스) 뭐라도 적은 것.
/// 162건을 다 띄우면 묻힌다. 패스한 물건도 «얼마에 팔렸나»가 오답노트라 넣는다.
ReviewStage? reviewStageOf(SaleItem it, DateTime today) {
  if (!it.hasNote && it.tag == null) return null;
  final day = DateTime(today.year, today.month, today.day);
  final sale = DateTime(it.saleDate.year, it.saleDate.month, it.saleDate.day);
  if (it.result == null) {
    if (sale.isBefore(day)) return ReviewStage.awaitingResult;
    // 매각 전 «패스»는 맞춰 볼 게 없다 — 예상을 적었을 때만.
    if (it.tag == '패스' && !it.hasNote) return null;
    return ReviewStage.upcoming;
  }
  final analysed = it.reasons.isNotEmpty || (it.why ?? '').trim().isNotEmpty;
  if (!analysed) return ReviewStage.needsAnalysis;
  if (it.verdict != null) return ReviewStage.done;
  final r = it.reviewOn;
  if (r != null && !DateTime(r.year, r.month, r.day).isAfter(day)) {
    return ReviewStage.reviewDue;
  }
  return ReviewStage.waiting;
}

// ─────────────────────────────── 통계 ───────────────────────────────

/// 쌓인 노트에서 배우는 숫자 — 입찰가를 정할 때 «이 구역은 몇 %에 팔리나».
class ReviewStats {
  final int sold; // 낙찰 기록 수
  final double? avgRate; // 평균 낙찰가율
  final double? avgBidders;
  final double? avgAbsError; // 내 예상 평균 오차(절댓값)
  final double? avgError; // 부호 있는 평균 — +면 늘 낮게 본다
  final int errorN;
  final Map<String, int> verdicts;
  final List<({String zone, double rate, int n})> byZone;
  final List<MapEntry<String, int>> topReasons;

  const ReviewStats({
    required this.sold,
    required this.avgRate,
    required this.avgBidders,
    required this.avgAbsError,
    required this.avgError,
    required this.errorN,
    required this.verdicts,
    required this.byZone,
    required this.topReasons,
  });

  factory ReviewStats.of(Iterable<SaleItem> items) {
    final sold = items.where((it) => it.soldRate != null).toList();
    double? avg(Iterable<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    final errs = [for (final it in sold) if (it.guessError != null) it.guessError!];
    final zones = <String, List<double>>{};
    for (final it in sold) {
      zones.putIfAbsent(it.zone, () => []).add(it.soldRate!);
    }
    final reasons = <String, int>{};
    for (final it in items) {
      for (final r in it.reasons) {
        reasons[r] = (reasons[r] ?? 0) + 1;
      }
    }
    final verdicts = <String, int>{};
    for (final it in items) {
      if (it.verdict != null) verdicts[it.verdict!] = (verdicts[it.verdict!] ?? 0) + 1;
    }
    return ReviewStats(
      sold: sold.length,
      avgRate: avg(sold.map((it) => it.soldRate!)),
      avgBidders: avg([
        for (final it in sold)
          if (it.bidders != null) it.bidders!.toDouble(),
      ]),
      avgAbsError: avg(errs.map((e) => e.abs())),
      avgError: avg(errs),
      errorN: errs.length,
      verdicts: verdicts,
      byZone: [
        for (final e in zones.entries)
          (zone: e.key, rate: avg(e.value)!, n: e.value.length),
      ]..sort((a, b) => b.n != a.n ? b.n - a.n : a.zone.compareTo(b.zone)),
      topReasons: reasons.entries.toList()
        ..sort((a, b) => b.value != a.value
            ? b.value - a.value
            : a.key.compareTo(b.key)),
    );
  }

  bool get isEmpty => sold == 0 && verdicts.isEmpty && topReasons.isEmpty;
}

// ─────────────────────────────── 목록 ───────────────────────────────

/// 「오답노트」 — 달력 물건 중 노트에 들어온 것을 단계별로.
class SaleReviewView extends ConsumerWidget {
  final List<SaleItem> items;
  const SaleReviewView({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final groups = <ReviewStage, List<SaleItem>>{};
    for (final it in items) {
      final s = reviewStageOf(it, today);
      if (s != null) groups.putIfAbsent(s, () => []).add(it);
    }
    int byDate(SaleItem a, SaleItem b) => a.saleDate.compareTo(b.saleDate);
    int byReview(SaleItem a, SaleItem b) =>
        (a.reviewOn ?? a.saleDate).compareTo(b.reviewOn ?? b.saleDate);
    for (final e in groups.entries) {
      switch (e.key) {
        case ReviewStage.upcoming:
          e.value.sort(byDate);
        case ReviewStage.reviewDue || ReviewStage.waiting:
          e.value.sort(byReview);
        default:
          e.value.sort((a, b) => byDate(b, a)); // 최근 매각부터
      }
    }
    final noted = [for (final g in groups.values) ...g];
    final stats = ReviewStats.of(noted);

    if (noted.isEmpty) {
      return const EmptyState(
        icon: Icons.edit_note_rounded,
        message: '아직 노트가 없어요 — 달력에서 물건을 눌러 태그를 달거나 「오답노트」를 쓰면 여기 모입니다',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!stats.isEmpty) ...[_StatsCard(stats), const Gap(18)],
        for (final s in ReviewStage.values)
          if ((groups[s] ?? const []).isNotEmpty) ...[
            SectionHeader(
              '${s.title} ${groups[s]!.length}',
              subtitle: s.hint,
            ),
            const Gap(8),
            for (final it in groups[s]!) ...[
              _NoteCard(it, stage: s),
              const Gap(8),
            ],
            const Gap(14),
          ],
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ReviewStats s;
  const _StatsCard(this.s);

  @override
  Widget build(BuildContext context) {
    Widget big(String label, String value, {String? sub, Color? color}) =>
        SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: AppFont.caption, color: AppColors.textSecondary)),
              const Gap(2),
              Text(value,
                  style: TextStyle(
                      fontSize: AppFont.display,
                      fontWeight: FontWeight.w800,
                      color: color ?? AppColors.textPrimary)),
              if (sub != null)
                Text(sub,
                    style: const TextStyle(
                        fontSize: AppFont.caption, color: AppColors.textFaint)),
            ],
          ),
        );
    final err = s.avgError;
    return GlassCard(
      accent: _accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('쌓인 노트에서',
              style: TextStyle(
                  fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          const Gap(12),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              big('평균 낙찰가율', s.avgRate == null ? '—' : _pct(s.avgRate!),
                  sub: '감정가 대비 · 낙찰 ${s.sold}건', color: _accent),
              big('평균 응찰',
                  s.avgBidders == null
                      ? '—'
                      : '${s.avgBidders!.toStringAsFixed(1)}명'),
              big(
                '내 예상 오차',
                s.avgAbsError == null ? '—' : '±${_pct(s.avgAbsError!)}',
                sub: err == null
                    ? '예상을 적고 결과를 넣으면 나온다'
                    : '${s.errorN}건 · ${err >= 0 ? '늘 낮게 봤다' : '늘 높게 봤다'} '
                        '(${Pct.signed(err * 100)})',
              ),
              if (s.verdicts.isNotEmpty)
                big(
                  '다시 보니',
                  '${s.verdicts['맞았다'] ?? 0} / ${s.verdicts['틀렸다'] ?? 0}',
                  sub: '맞았다 / 틀렸다 · 반반 ${s.verdicts['반반'] ?? 0}',
                ),
            ],
          ),
          if (s.byZone.isNotEmpty) ...[
            const Gap(14),
            const Text('구역별 낙찰가율',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textSecondary)),
            const Gap(6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final z in s.byZone)
                Pill('${z.zone} ${_pct(z.rate)} · ${z.n}건', color: _accent),
            ]),
          ],
          if (s.topReasons.isNotEmpty) ...[
            const Gap(12),
            const Text('자주 나온 이유',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textSecondary)),
            const Gap(6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in s.topReasons.take(6))
                Pill('${r.key} ${r.value}',
                    color: kReasonsDown.contains(r.key) ? _down : _up),
            ]),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final SaleItem it;
  final ReviewStage stage;
  const _NoteCard(this.it, {required this.stage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const cap = TextStyle(fontSize: AppFont.caption, color: AppColors.textSecondary);
    final rate = it.soldRate;
    final err = it.guessError;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => openSaleReview(context, ref, it),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: it.caseNo,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(
                    text: '  ${it.source == '공매' ? '공' : '경'}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: it.source == '공매' ? AppColors.violet : AppColors.sky),
                  ),
                  TextSpan(
                      text: '  ${it.zone}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ]),
                style: const TextStyle(fontSize: AppFont.body),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(6),
            if (it.tag != null) ...[Pill(it.tag!, color: AppColors.textSecondary), const Gap(6)],
            Text(
              '${Dates.md(it.saleDate)} ${Dates.dday(it.saleDate)}',
              style: const TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint),
            ),
          ]),
          const Gap(4),
          Text(
            '감정 ${Won.compact(it.appraisal)} · 최저 ${Won.compact(it.minPrice)}'
            '${it.appraisal > 0 ? ' (${_pct(it.ratio)})' : ''}'
            '${it.fails > 0 ? ' · 유찰${it.fails}' : ''}'
            '${(it.guessPrice ?? 0) > 0 ? ' · 내 예상 ${Won.compact(it.guessPrice!)}' : ''}'
            '${(it.myBid ?? 0) > 0 ? ' · 내 입찰 ${Won.compact(it.myBid!)}' : ''}',
            style: cap,
          ),
          if (it.result != null) ...[
            const Gap(6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  it.isSold
                      ? '낙찰 ${Won.compact(it.soldPrice!)}'
                          '${rate != null ? ' · ${_pct(rate)}' : ''}'
                          '${it.bidders != null ? ' · ${it.bidders}명' : ''}'
                          '${(it.secondPrice ?? 0) > 0 ? ' · 2위 ${Won.compact(it.secondPrice!)}' : ''}'
                      : it.result!,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: it.isSold ? _accent : AppColors.textSecondary,
                  ),
                ),
                if (err != null)
                  Pill('예상보다 ${Pct.signed(err * 100)}',
                      color: err.abs() <= 0.03 ? AppColors.primary : AppColors.rose),
                if (it.verdict != null)
                  Pill('다시 보니 ${it.verdict}', color: kVerdicts[it.verdict] ?? _accent),
              ],
            ),
          ],
          if (it.reasons.isNotEmpty) ...[
            const Gap(8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in it.reasons)
                Pill(r, color: kReasonsDown.contains(r) ? _down : _up),
            ]),
          ],
          if ((it.why ?? '').isNotEmpty) ...[
            const Gap(8),
            Text(it.why!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppFont.label)),
          ],
          if (it.reviewOn != null && stage != ReviewStage.done) ...[
            const Gap(6),
            Text(
              '다시 볼 날 ${Dates.ymd(it.reviewOn!)} ${Dates.dday(it.reviewOn!)}',
              style: TextStyle(
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w700,
                color: stage == ReviewStage.reviewDue ? _accent : AppColors.textFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── 편집 ───────────────────────────────

String _draftKey(SaleItem it) => 'sale_review:${it.id}';

/// 오답노트 창만 — 저장을 누르면 sale_items 에 넣을 patch, 닫으면 null.
Future<Map<String, dynamic>?> showSaleReviewSheet(BuildContext context, SaleItem it) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReviewSheet(it),
    );

/// 오답노트 열기 → 저장하면 sale_items 한 줄을 고친다.
Future<void> openSaleReview(BuildContext context, WidgetRef ref, SaleItem it) async {
  final patch = await showSaleReviewSheet(context, it);
  if (patch == null) return;
  try {
    await ref.read(supabaseProvider).from('sale_items').update(patch).eq('id', it.id);
  } catch (e) {
    // 쓴 글은 임시저장에 남아 있다 — 다시 열면 채워진다.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.rose,
        content: Text('저장 실패 — 마이그레이션 0069 를 실행했는지 확인 · 쓴 글은 임시저장됨\n$e'),
      ));
    }
    return;
  }
  await FormDraft.clear(_draftKey(it));
  ref.invalidate(saleItemsProvider);
}

class _ReviewSheet extends StatefulWidget {
  final SaleItem it;
  const _ReviewSheet(this.it);

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  SaleItem get it => widget.it;

  late double _guess = it.guessPrice ?? 0;
  late double _myBid = it.myBid ?? 0;
  late String? _result = it.result;
  late double _sold = it.soldPrice ?? 0;
  late double _second = it.secondPrice ?? 0;
  late final _bidders = PlainController(text: it.bidders?.toString() ?? '');
  late final Set<String> _reasons = {...it.reasons};
  late final _why = PlainController(text: it.why ?? '');
  late final _lesson = PlainController(text: it.lesson ?? '');
  late DateTime? _reviewOn = it.reviewOn;
  late final _reviewNote = PlainController(text: it.reviewNote ?? '');
  late String? _verdict = it.verdict;

  bool _ready = false; // 임시저장을 읽은 뒤에 칸을 그린다(MoneyField 는 처음 값만 받는다)
  DateTime? _restoredAt;
  bool _submitted = false;
  Timer? _timer;
  late final Map<String, String> _initial = _snap();
  String _last = '';

  Map<String, String> _snap() => {
        'guess': _guess.round().toString(),
        'myBid': _myBid.round().toString(),
        'result': _result ?? '',
        'sold': _sold.round().toString(),
        'second': _second.round().toString(),
        'bidders': _bidders.text,
        'reasons': (_reasons.toList()..sort()).join('|'),
        'why': _why.text,
        'lesson': _lesson.text,
        'reviewOn': _reviewOn?.toIso8601String().substring(0, 10) ?? '',
        'reviewNote': _reviewNote.text,
        'verdict': _verdict ?? '',
      };

  void _apply(Map<String, String> m) {
    double n(String? v) => double.tryParse(v ?? '') ?? 0;
    String? s(String? v) => (v ?? '').isEmpty ? null : v;
    _guess = n(m['guess']);
    _myBid = n(m['myBid']);
    _result = s(m['result']);
    _sold = n(m['sold']);
    _second = n(m['second']);
    _bidders.text = m['bidders'] ?? '';
    _reasons
      ..clear()
      ..addAll((m['reasons'] ?? '').split('|').where((e) => e.isNotEmpty));
    _why.text = m['why'] ?? '';
    _lesson.text = m['lesson'] ?? '';
    _reviewOn = s(m['reviewOn']) == null ? null : DateTime.tryParse(m['reviewOn']!);
    _reviewNote.text = m['reviewNote'] ?? '';
    _verdict = s(m['verdict']);
  }

  @override
  void initState() {
    super.initState();
    _initial; // 처음 값을 먼저 찍어 둔다
    _load();
  }

  Future<void> _load() async {
    final d = await FormDraft.load(_draftKey(it));
    if (!mounted) return;
    setState(() {
      if (d != null && !_sameAs(d.fields, _initial)) {
        _apply(d.fields);
        _restoredAt = d.savedAt;
      }
      _last = _snap().toString();
      _ready = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _saveDraft());
  }

  bool _sameAs(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  void _saveDraft() {
    if (_submitted || !_ready) return;
    final now = _snap();
    final key = now.toString();
    if (key == _last) return;
    _last = key;
    if (_sameAs(now, _initial)) {
      FormDraft.clear(_draftKey(it));
    } else {
      FormDraft.save(_draftKey(it), now);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveDraft(); // 창이 그냥 닫혀도(취소·바깥 누름) 쓴 건 남긴다
    for (final c in [_bidders, _why, _lesson, _reviewNote]) {
      c.dispose();
    }
    super.dispose();
  }

  void _discardDraft() {
    FormDraft.clear(_draftKey(it));
    setState(() {
      _apply(_initial);
      _restoredAt = null;
      _ready = false; // MoneyField 를 처음 값으로 다시 그린다
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
    _last = _snap().toString();
  }

  void _submit() {
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final sold = _result == '낙찰';
    // 결과를 넣었는데 «다시 볼 날»이 비었으면 매각일 + 3달.
    final review = _reviewOn ??
        (_result != null
            ? it.saleDate.add(const Duration(days: kReviewAfterDays))
            : null);
    final patch = <String, dynamic>{
      'guess_price': _guess > 0 ? _guess : null,
      'my_bid': _myBid > 0 ? _myBid : null,
      'result': _result,
      'sold_price': sold && _sold > 0 ? _sold : null,
      'bidders': sold ? int.tryParse(_bidders.text.trim()) : null,
      'second_price': sold && _second > 0 ? _second : null,
      'reasons': _reasons.toList(),
      'why': t(_why),
      'lesson': t(_lesson),
      'review_on': review?.toIso8601String().substring(0, 10),
      'review_note': t(_reviewNote),
      'verdict': _verdict,
    };
    _saveDraft(); // 저장이 실패해도 남게 — 성공하면 호출한 쪽이 지운다
    _submitted = true;
    Navigator.pop(context, patch);
  }

  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오답노트 · ${it.zone}',
              style: const TextStyle(fontSize: AppFont.section)),
          const Gap(2),
          Text(
            '${it.caseNo} · ${Dates.ymd(it.saleDate)} ${Dates.dday(it.saleDate)}\n'
            '감정 ${Won.compact(it.appraisal)} · 최저 ${Won.compact(it.minPrice)}'
            '${it.appraisal > 0 ? ' (${_pct(it.ratio)})' : ''}'
            '${it.fails > 0 ? ' · 유찰 ${it.fails}' : ''}',
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textSecondary),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: !_ready
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_restoredAt != null) ...[_draftBanner(), const Gap(12)],
                  _step(1, '매각 전 — 내 예상', '얼마에 낙찰될까? 결과를 보기 전에 적어야 오답노트가 된다'),
                  const Gap(8),
                  MoneyField(
                    label: '내 예상 낙찰가',
                    initial: _guess,
                    accent: _accent,
                    dense: true,
                    onChanged: (v) => setState(() => _guess = v),
                  ),
                  _rateLine(_guess),
                  const Gap(8),
                  MoneyField(
                    label: '내 입찰가 (입찰했으면)',
                    initial: _myBid,
                    accent: _accent,
                    dense: true,
                    onChanged: (v) => setState(() => _myBid = v),
                  ),
                  _rateLine(_myBid),
                  const Gap(18),
                  _step(2, '결과', '행크옥션 «매각 결과»에서 옮긴다'),
                  const Gap(8),
                  _seg(kReviewResults, _result, {for (final r in kReviewResults) r: _accent},
                      (v) => setState(() => _result = _result == v ? null : v)),
                  if (_result == '낙찰') ...[
                    const Gap(10),
                    MoneyField(
                      label: '낙찰가',
                      initial: _sold,
                      accent: _accent,
                      dense: true,
                      onChanged: (v) => setState(() => _sold = v),
                    ),
                    const Gap(8),
                    Row(children: [
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _bidders,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                              labelText: '응찰자', suffixText: '명', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: MoneyField(
                          label: '2위 입찰가',
                          initial: _second,
                          accent: _accent,
                          dense: true,
                          onChanged: (v) => setState(() => _second = v),
                        ),
                      ),
                    ]),
                    const Gap(10),
                    _metrics(),
                  ],
                  const Gap(18),
                  _step(3, '왜 이 가격?', '값을 올린 것·누른 것을 고르고, 내 말로 한 줄'),
                  const Gap(8),
                  _reasonGroup('↑ 값을 올린 것', kReasonsUp, _up),
                  const Gap(8),
                  _reasonGroup('↓ 값을 누른 것', kReasonsDown, _down),
                  const Gap(10),
                  TextField(
                    controller: _why,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '왜 이 가격에 낙찰됐나',
                      hintText: '예) 4차라 최저가가 64%까지 내려와 6명이 몰렸다. 2위와 118만 차이',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const Gap(10),
                  TextField(
                    controller: _lesson,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '다음엔 — 내 입찰가라면',
                      hintText: '예) 이 구역 다세대는 감정가 75~80%를 써야 들어간다',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const Gap(18),
                  _step(4, '나중에 다시 보기',
                      '날이 되면 오답노트 맨 위로 올라온다. 비워 두면 결과를 넣을 때 매각일 +3달'),
                  const Gap(8),
                  _reviewDateRow(),
                  const Gap(10),
                  TextField(
                    controller: _reviewNote,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '다시 보니 — 그때 분석이 맞았나',
                      hintText: '예) 전세가 2.4억에 바로 맞춰졌다. 낙찰자가 옳았다',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const Gap(8),
                  _seg(kVerdicts.keys.toList(), _verdict, kVerdicts,
                      (v) => setState(() => _verdict = _verdict == v ? null : v)),
                ],
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: AppFont.label, fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ),
          const Gap(8),
          Expanded(
            flex: 2,
            child: SaveKey(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  textStyle: const TextStyle(
                      fontSize: AppFont.label, fontWeight: FontWeight.w800),
                  backgroundColor: _accent,
                  foregroundColor: const Color(0xFF2A1D00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _ready ? _submit : null,
                child: const Text('저장'),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _draftBanner() => Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.history_rounded, size: 16, color: _accent),
          const Gap(6),
          Expanded(
            child: Text(
              '임시저장된 내용을 불러왔습니다 (${Dates.md(_restoredAt!)} '
              '${_restoredAt!.hour.toString().padLeft(2, '0')}:'
              '${_restoredAt!.minute.toString().padLeft(2, '0')})',
              style: const TextStyle(fontSize: AppFont.caption, color: _accent),
            ),
          ),
          TextButton(onPressed: _discardDraft, child: const Text('버리기')),
        ]),
      );

  Widget _step(int n, String title, String hint) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$n',
                style: const TextStyle(
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w900,
                    color: _accent)),
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: AppFont.body, fontWeight: FontWeight.w800)),
                Text(hint,
                    style: const TextStyle(
                        fontSize: AppFont.caption, color: AppColors.textFaint)),
              ],
            ),
          ),
        ],
      );

  /// 금액 칸 밑 «감정가의 77% · 최저가의 121%».
  Widget _rateLine(double v) {
    if (v <= 0 || it.appraisal <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        '감정가의 ${_pct(v / it.appraisal)}'
        '${it.minPrice > 0 ? ' · 최저가의 ${_pct(v / it.minPrice)}' : ''}',
        style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textSecondary),
      ),
    );
  }

  /// 낙찰가를 넣으면 바로 — 낙찰가율 · 2위와 차이 · 내 예상/입찰과 비교.
  Widget _metrics() {
    if (_sold <= 0) return const SizedBox.shrink();
    final lines = <(String, Color)>[
      if (it.appraisal > 0)
        ('낙찰가율 ${_pct(_sold / it.appraisal)}'
            '${it.minPrice > 0 ? ' · 최저가의 ${_pct(_sold / it.minPrice)}' : ''}', _accent),
      if (_second > 0)
        ('2위와 ${Won.compact(_sold - _second)} 차이 — 그만큼 더 썼다', AppColors.textSecondary),
      if (_guess > 0)
        ('내 예상보다 ${Pct.signed((_sold - _guess) / _guess * 100)} '
            '(${_sold >= _guess ? '낮게 봤다' : '높게 봤다'})',
            ((_sold - _guess) / _guess).abs() <= 0.03 ? AppColors.primary : AppColors.rose),
      if (_myBid > 0)
        (_myBid >= _sold
            ? '내 입찰가가 낙찰가 이상 — 내가 낙찰받았다면 여기'
            : '내 입찰가가 ${Won.compact(_sold - _myBid)} 모자랐다',
            _myBid >= _sold ? AppColors.primary : AppColors.rose),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (t, c) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(t,
                  style: TextStyle(
                      fontSize: AppFont.label, fontWeight: FontWeight.w700, color: c)),
            ),
        ],
      ),
    );
  }

  /// 한 줄에 같은 폭 버튼 — 하나만 고른다(다시 누르면 해제).
  Widget _seg(List<String> opts, String? value, Map<String, Color> colors,
      ValueChanged<String> onTap) {
    return Row(children: [
      for (final o in opts) ...[
        if (o != opts.first) const Gap(6),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap(o),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value == o
                    ? (colors[o] ?? _accent).withValues(alpha: 0.22)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: value == o ? (colors[o] ?? _accent) : AppColors.border),
              ),
              child: Text(o,
                  style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w800,
                    color: value == o ? (colors[o] ?? _accent) : AppColors.textSecondary,
                  )),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _reasonGroup(String title, List<String> opts, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: AppFont.caption, fontWeight: FontWeight.w700, color: c)),
          const Gap(6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final o in opts)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(
                    () => _reasons.contains(o) ? _reasons.remove(o) : _reasons.add(o)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _reasons.contains(o) ? c.withValues(alpha: 0.18) : Colors.transparent,
                    border: Border.all(
                        color: _reasons.contains(o) ? c : AppColors.border,
                        width: _reasons.contains(o) ? 1.4 : 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o,
                      style: TextStyle(
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700,
                        color: _reasons.contains(o) ? c : AppColors.textSecondary,
                      )),
                ),
              ),
          ]),
        ],
      );

  Widget _reviewDateRow() {
    DateTime plus(int months) =>
        DateTime(it.saleDate.year, it.saleDate.month + months, it.saleDate.day);
    Widget quick(String label, DateTime d) => OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w700),
          ),
          onPressed: () => setState(() => _reviewOn = d),
          child: Text(label),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            side: BorderSide(color: _reviewOn == null ? AppColors.border : _accent),
            foregroundColor: _reviewOn == null ? AppColors.textSecondary : _accent,
            textStyle: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w800),
          ),
          onPressed: () async {
            final d = await pickDay(context, initial: _reviewOn ?? plus(3));
            if (d != null && mounted) setState(() => _reviewOn = d);
          },
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(_reviewOn == null
              ? '다시 볼 날'
              : '${Dates.ymd(_reviewOn!)} ${Dates.dday(_reviewOn!)}'),
        ),
        quick('+1달', plus(1)),
        quick('+3달', plus(3)),
        quick('+6달', plus(6)),
        if (_reviewOn != null)
          IconButton(
            tooltip: '지우기',
            onPressed: () => setState(() => _reviewOn = null),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    );
  }
}
