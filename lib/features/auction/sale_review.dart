// 경공매 오답노트 — 달력 물건 하나에 «내 예상 → 실제 결과 → 왜 → 나중에 다시 보기».
//
// ① 매각 전에 «얼마에 낙찰될까»를 적어 둔다(입찰했다면 내 입찰가도).
// ② 매각 뒤 낙찰가·응찰자·2위 가격을 넣으면 낙찰가율·예상 오차가 바로 나온다.
// ③ 왜 그 가격이었나 — 앱이 먼저 숫자로 풀어 주고(자동 분석), 내가 태그 + 글로 남긴다.
// ④ 몇 달 뒤(기본 매각일 +3달) 다시 열어 그 분석이 맞았는지 판정한다.
//
// 「분석」은 쌓인 노트를 모아 본다 — 유찰 횟수·응찰자·구역·이유별 낙찰가율,
// 내 예상 성적, 교훈 모음. 매각 전 물건에는 «기록으로 보면 감정가 몇 %»를 붙인다.
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

/// 예상이 이만큼 안에 들면 «맞혔다».
const kGuessHit = 0.03;

// 크기 — 칸·칩·버튼 높이를 하나로(자산 편집 창과 같은 규칙).
const _chipH = 36.0;
const _segH = 44.0;
const _btnH = 48.0;
const _fieldText = TextStyle(fontSize: AppFont.section);

/// 글 칸 — MoneyField 와 같게 라벨은 늘 위, 같은 글자 크기. 힌트는 칸 안에 보인다.
InputDecoration _field(String label, {String? hint, String? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(fontSize: AppFont.label),
      hintStyle: const TextStyle(fontSize: AppFont.body, color: AppColors.textFaint),
      hintMaxLines: 3,
    );

String _pct(double r) => Pct.of(r * 100, digits: r * 100 >= 100 ? 0 : 1);

bool _isPastOrToday(DateTime d, DateTime today) =>
    !DateTime(d.year, d.month, d.day)
        .isAfter(DateTime(today.year, today.month, today.day));

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

/// 오답노트에 들어오는 물건 — 관심·임장·입찰예정 태그를 달았거나 뭐라도 적은 것.
/// 200건을 다 띄우면 묻힌다. «패스»는 120건이 넘어 다 넣으면 «결과 넣기»가 끝없이
/// 쌓인다 — 패스했는데 궁금한 물건은 달력에서 열어 「오답노트」를 쓰면 들어온다.
ReviewStage? reviewStageOf(SaleItem it, DateTime today) {
  if (!it.hasNote && (it.tag == null || it.tag == '패스')) return null;
  final day = DateTime(today.year, today.month, today.day);
  final sale = DateTime(it.saleDate.year, it.saleDate.month, it.saleDate.day);
  if (it.result == null) {
    return sale.isBefore(day) ? ReviewStage.awaitingResult : ReviewStage.upcoming;
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

// ─────────────────────────────── 분석 ───────────────────────────────

double? _avg(Iterable<double> xs) =>
    xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

/// 유찰 횟수 구간 — 신건 · 1회 · 2회 · 3회+.
String failBucket(int fails) => switch (fails) {
      0 => '신건',
      1 => '유찰 1회',
      2 => '유찰 2회',
      _ => '유찰 3회+',
    };

/// 응찰자 구간 — 단독 · 2~4명 · 5명+.
String bidderBucket(int n) => n <= 1 ? '단독' : (n <= 4 ? '2~4명' : '5명+');

/// 한 묶음의 낙찰가율 평균.
typedef RateGroup = ({String key, double rate, double? overMin, int n});

List<RateGroup> _group(
  Iterable<SaleItem> sold,
  Iterable<String> Function(SaleItem) keysOf, {
  List<String>? order,
}) {
  final m = <String, List<SaleItem>>{};
  for (final it in sold) {
    for (final k in keysOf(it)) {
      m.putIfAbsent(k, () => []).add(it);
    }
  }
  final out = [
    for (final e in m.entries)
      (
        key: e.key,
        rate: _avg(e.value.map((it) => it.soldRate!))!,
        overMin: _avg([
          for (final it in e.value)
            if (it.minPrice > 0) it.soldPrice! / it.minPrice,
        ]),
        n: e.value.length,
      ),
  ];
  if (order != null) {
    out.sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
  } else {
    out.sort((a, b) => b.n != a.n ? b.n - a.n : a.key.compareTo(b.key));
  }
  return out;
}

/// 쌓인 노트에서 배우는 숫자 — 입찰가를 정할 때 «이런 물건은 몇 %에 팔리나».
class ReviewStats {
  final List<SaleItem> soldItems;
  final double? avgRate; // 평균 낙찰가율
  final double? avgOverMin; // 최저가 대비 평균
  final double? avgBidders;
  final double? avgAbsError; // 내 예상 평균 오차(절댓값)
  final double? avgError; // 부호 있는 평균 — +면 늘 낮게 본다
  final int errorN;
  final int hits; // 예상이 ±3% 안에 든 수
  final Map<String, int> verdicts;
  final List<RateGroup> byFails;
  final List<RateGroup> byBidders;
  final List<RateGroup> byZone;
  final List<RateGroup> byReason;
  final List<SaleItem> lessons;

  const ReviewStats._({
    required this.soldItems,
    required this.avgRate,
    required this.avgOverMin,
    required this.avgBidders,
    required this.avgAbsError,
    required this.avgError,
    required this.errorN,
    required this.hits,
    required this.verdicts,
    required this.byFails,
    required this.byBidders,
    required this.byZone,
    required this.byReason,
    required this.lessons,
  });

  int get sold => soldItems.length;

  factory ReviewStats.of(Iterable<SaleItem> items) {
    final sold = items.where((it) => it.soldRate != null).toList()
      ..sort((a, b) => b.saleDate.compareTo(a.saleDate));
    final errs = [for (final it in sold) if (it.guessError != null) it.guessError!];
    final verdicts = <String, int>{};
    for (final it in items) {
      if (it.verdict != null) verdicts[it.verdict!] = (verdicts[it.verdict!] ?? 0) + 1;
    }
    return ReviewStats._(
      soldItems: sold,
      avgRate: _avg(sold.map((it) => it.soldRate!)),
      avgOverMin: _avg([
        for (final it in sold)
          if (it.minPrice > 0) it.soldPrice! / it.minPrice,
      ]),
      avgBidders: _avg([
        for (final it in sold)
          if (it.bidders != null) it.bidders!.toDouble(),
      ]),
      avgAbsError: _avg(errs.map((e) => e.abs())),
      avgError: _avg(errs),
      errorN: errs.length,
      hits: errs.where((e) => e.abs() <= kGuessHit).length,
      verdicts: verdicts,
      byFails: _group(sold, (it) => [failBucket(it.fails)],
          order: ['신건', '유찰 1회', '유찰 2회', '유찰 3회+']),
      byBidders: _group(
          sold.where((it) => it.bidders != null), (it) => [bidderBucket(it.bidders!)],
          order: ['단독', '2~4명', '5명+']),
      byZone: _group(sold, (it) => [it.zone]),
      byReason: _group(sold, (it) => it.reasons),
      lessons: [
        for (final it in [...items]..sort((a, b) => b.saleDate.compareTo(a.saleDate)))
          if ((it.lesson ?? '').trim().isNotEmpty) it,
      ],
    );
  }
}

/// 매각 전 물건의 «기록으로 보면» — 같은 구역 → 같은 유찰 횟수 → 전체 순으로 찾는다.
({double rate, String basis, int n})? rateGuide(SaleItem it, Iterable<SaleItem> history) {
  final sold = history.where((h) => h.id != it.id && h.soldRate != null).toList();
  if (sold.isEmpty) return null;
  ({double rate, String basis, int n}) of(List<SaleItem> xs, String basis) =>
      (rate: _avg(xs.map((h) => h.soldRate!))!, basis: basis, n: xs.length);
  final zone = sold.where((h) => h.zone == it.zone).toList();
  if (zone.isNotEmpty) return of(zone, '같은 구역');
  final fails = sold.where((h) => failBucket(h.fails) == failBucket(it.fails)).toList();
  if (fails.isNotEmpty) return of(fails, failBucket(it.fails));
  return of(sold, '전체 기록');
}

/// 낙찰 결과를 숫자로 풀어 쓴다 — «왜 이 가격?»의 첫 줄.
/// 추천 이유 태그도 같이 낸다(내가 고르는 건 따로).
({List<String> lines, Set<String> tags}) autoAnalysis({
  required SaleItem it,
  required double sold,
  int? bidders,
  double second = 0,
  Iterable<SaleItem> history = const [],
}) {
  final lines = <String>[];
  final tags = <String>{};
  if (sold <= 0) return (lines: lines, tags: tags);
  final rate = it.appraisal > 0 ? sold / it.appraisal : null;
  final minRate = it.appraisal > 0 && it.minPrice > 0 ? it.minPrice / it.appraisal : null;

  // 1) 유찰 → 최저가 → 얼마나 더 썼나
  if (rate != null) {
    if (it.fails == 0) {
      lines.add('신건(유찰 없음)인데 감정가의 ${_pct(rate)}에 낙찰');
    } else if (minRate != null) {
      lines.add('유찰 ${it.fails}회로 최저가가 감정가의 ${_pct(minRate)}까지 내려왔고, '
          '최저가보다 ${Won.compact(sold - it.minPrice)} 더 써서(최저가의 ${_pct(sold / it.minPrice)}) 가져갔다');
    }
    if (rate >= 1) {
      lines.add('감정가를 넘겼다 — 감정가가 시세보다 낮았거나 구역 기대감이 붙었다');
      tags.add('구역 기대감');
    }
    if (it.fails >= 2 && rate < 0.8) tags.add('유찰 누적');
  }

  // 2) 응찰자
  if (bidders != null && bidders > 0) {
    if (bidders == 1) {
      lines.add('단독 응찰 — 경쟁 없이 혼자 가져갔다');
      tags.add('관심 적음');
    } else if (bidders >= 5) {
      lines.add('응찰 $bidders명 — 몰렸다${it.fails >= 2 ? '. 유찰로 값이 내려오자 사람이 붙었다' : ''}');
      tags.add('경쟁 과열');
    } else {
      lines.add('응찰 $bidders명 — 보통 경쟁');
    }
  }

  // 3) 2위와 차이
  if (second > 0 && second <= sold) {
    final gap = (sold - second) / sold;
    if (gap <= 0.01) {
      lines.add('2위와 ${Won.compact(sold - second)} 차이(${_pct(gap)}) — 박빙. 여럿이 비슷한 값을 봤다');
    } else if (gap >= 0.05) {
      lines.add('2위보다 ${_pct(gap)} 높게 — 낙찰자 혼자 비싸게 봤다(실거주·확신)');
    } else {
      lines.add('2위와 ${Won.compact(sold - second)} 차이(${_pct(gap)})');
    }
  }

  // 4) 내 기록과 견주기
  if (rate != null) {
    final past = history.where((h) => h.id != it.id && h.soldRate != null).toList();
    final zone = past.where((h) => h.zone == it.zone).toList();
    final sameFails = past.where((h) => failBucket(h.fails) == failBucket(it.fails)).toList();
    String vs(List<SaleItem> xs, String what) {
      final a = _avg(xs.map((h) => h.soldRate!))!;
      final d = (rate - a) * 100;
      return '$what ${xs.length}건 평균 ${_pct(a)} — 이번은 '
          '${d.abs() < 1 ? '거의 같다' : '${d.abs().toStringAsFixed(1)}%p ${d > 0 ? '높다' : '낮다'}'}';
    }

    if (zone.isNotEmpty) lines.add(vs(zone, '같은 구역(${it.zone})'));
    if (sameFails.isNotEmpty) lines.add(vs(sameFails, failBucket(it.fails)));
  }
  return (lines: lines, tags: tags);
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
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.edit_note_rounded,
        message: '아직 노트가 없어요 — 달력에서 물건을 눌러 관심·임장 태그를 달거나 「오답노트」를 쓰면 여기 모입니다',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in ReviewStage.values)
          if ((groups[s] ?? const []).isNotEmpty) ...[
            SectionHeader('${s.title} ${groups[s]!.length}', subtitle: s.hint),
            const Gap(8),
            for (final it in groups[s]!) ...[
              _NoteCard(it, stage: s, history: items),
              const Gap(8),
            ],
            const Gap(14),
          ],
      ],
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final SaleItem it;
  final ReviewStage stage;
  final List<SaleItem> history;
  const _NoteCard(this.it, {required this.stage, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const cap = TextStyle(fontSize: AppFont.caption, color: AppColors.textSecondary);
    final rate = it.soldRate;
    final err = it.guessError;
    final guide = stage == ReviewStage.upcoming || stage == ReviewStage.awaitingResult
        ? rateGuide(it, history)
        : null;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => openSaleReview(context, ref, it),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _caseTitle(it)),
            const Gap(6),
            if (it.tag != null) ...[Pill(it.tag!, color: AppColors.textSecondary), const Gap(6)],
            Text(
              '${Dates.md(it.saleDate)} ${Dates.dday(it.saleDate)}',
              style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint),
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
          if (guide != null && it.appraisal > 0) ...[
            const Gap(4),
            Text(
              '기록으로 보면 감정가의 ${_pct(guide.rate)} ≈ ${Won.compact(it.appraisal * guide.rate)}'
              ' (${guide.basis} ${guide.n}건)',
              style: const TextStyle(
                  fontSize: AppFont.caption, fontWeight: FontWeight.w700, color: _accent),
            ),
          ],
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
                      color: err.abs() <= kGuessHit ? AppColors.primary : AppColors.rose),
                if (it.verdict != null)
                  Pill('다시 보니 ${it.verdict}', color: kVerdicts[it.verdict] ?? _accent),
              ],
            ),
          ],
          if (it.reasons.isNotEmpty) ...[
            const Gap(8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in it.reasons) Pill(r, color: kReasonsDown.contains(r) ? _down : _up),
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

Widget _caseTitle(SaleItem it, {double size = AppFont.body}) => Text.rich(
      TextSpan(children: [
        TextSpan(text: it.caseNo, style: const TextStyle(fontWeight: FontWeight.w800)),
        TextSpan(
          text: '  ${it.source == '공매' ? '공' : '경'}',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: it.source == '공매' ? AppColors.violet : AppColors.sky),
        ),
        TextSpan(text: '  ${it.zone}', style: const TextStyle(color: AppColors.textSecondary)),
      ]),
      style: TextStyle(fontSize: size),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

// ─────────────────────────────── 모아 보기 ───────────────────────────────

/// 「분석」 — 쌓인 노트를 모아서. 입찰가를 정할 때 펼쳐 보는 곳.
class SaleAnalysisView extends ConsumerWidget {
  final List<SaleItem> items;
  const SaleAnalysisView({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ReviewStats.of(items);
    if (s.sold == 0 && s.lessons.isEmpty && s.verdicts.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_rounded,
        message: '낙찰 결과를 넣으면 여기 모입니다 — 유찰 횟수·응찰자·구역·이유별 낙찰가율, '
            '내 예상이 얼마나 맞았는지, 「다음엔」 교훈 모음',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(s),
        if (s.sold > 0) ...[
          const Gap(14),
          // 넓으면 2단, 폰이면 1단. 카드 높이가 제각각이라 고정 비율 그리드는 안 쓴다.
          LayoutBuilder(builder: (context, c) {
            const gap = 14.0;
            final w = c.maxWidth >= 720 ? (c.maxWidth - gap) / 2 : c.maxWidth;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final card in [
                _RateCard('유찰 횟수별', '유찰이 쌓이면 몇 %까지 내려가나', s.byFails),
                if (s.byBidders.isNotEmpty)
                  _RateCard('응찰자별', '사람이 몰리면 얼마나 더 쓰나', s.byBidders),
                _RateCard('구역별', '이 구역은 몇 %에 팔리나', s.byZone),
                if (s.byReason.isNotEmpty)
                  _RateCard('이유별', '그 이유가 붙은 물건의 낙찰가율', s.byReason,
                      colorOf: (k) => kReasonsDown.contains(k) ? _down : _up),
              ])
                SizedBox(width: w, child: card),
            ]);
          }),
        ],
        if (s.lessons.isNotEmpty) ...[
          const Gap(18),
          SectionHeader('다음엔 — 교훈 ${s.lessons.length}', subtitle: '노트마다 적은 «다음엔»을 한곳에'),
          const Gap(8),
          for (final it in s.lessons) ...[
            GlassCard(
              padding: const EdgeInsets.all(14),
              onTap: () => openSaleReview(context, ref, it),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.lesson!, style: const TextStyle(fontSize: AppFont.body)),
                  const Gap(4),
                  Text(
                    '${it.zone} · ${it.caseNo} · ${Dates.ymd(it.saleDate)}'
                    '${it.soldRate != null ? ' · 낙찰 ${_pct(it.soldRate!)}' : ''}',
                    style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
            const Gap(8),
          ],
        ],
        if (s.sold > 0) ...[
          const Gap(18),
          SectionHeader('낙찰 기록 ${s.sold}', subtitle: '최근 매각부터 — 누르면 노트'),
          const Gap(8),
          for (final it in s.soldItems) ...[_RecordRow(it), const Gap(6)],
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final ReviewStats s;
  const _Summary(this.s);

  @override
  Widget build(BuildContext context) {
    Widget big(String label, String value, String sub, {Color? color}) => SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textSecondary)),
              const Gap(2),
              Text(value,
                  style: TextStyle(
                      fontSize: AppFont.display,
                      fontWeight: FontWeight.w800,
                      color: color ?? AppColors.textPrimary)),
              Text(sub, style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
            ],
          ),
        );
    final err = s.avgError;
    return GlassCard(
      accent: _accent,
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          big('평균 낙찰가율', s.avgRate == null ? '—' : _pct(s.avgRate!),
              '감정가 대비 · 낙찰 ${s.sold}건', color: _accent),
          big('최저가 대비', s.avgOverMin == null ? '—' : _pct(s.avgOverMin!), '최저가보다 얼마나 더 썼나'),
          big('평균 응찰', s.avgBidders == null ? '—' : '${s.avgBidders!.toStringAsFixed(1)}명',
              '응찰자를 적은 것만'),
          big(
            '내 예상 적중',
            s.errorN == 0 ? '—' : '${s.hits}/${s.errorN}',
            err == null
                ? '예상을 적고 결과를 넣으면 나온다'
                : '±${(kGuessHit * 100).round()}% 안 · 평균 ±${_pct(s.avgAbsError!)} · '
                    '${err >= 0 ? '늘 낮게 봤다' : '늘 높게 봤다'}',
            color: s.errorN == 0 ? null : AppColors.primary,
          ),
          if (s.verdicts.isNotEmpty)
            big('다시 보니', '${s.verdicts['맞았다'] ?? 0} / ${s.verdicts['틀렸다'] ?? 0}',
                '맞았다 / 틀렸다 · 반반 ${s.verdicts['반반'] ?? 0}'),
        ],
      ),
    );
  }
}

/// 묶음별 낙찰가율 막대 — 막대는 감정가 120% 를 끝으로.
class _RateCard extends StatelessWidget {
  final String title;
  final String hint;
  final List<RateGroup> rows;
  final Color Function(String key)? colorOf;
  const _RateCard(this.title, this.hint, this.rows, {this.colorOf});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          Text(hint, style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
          const Gap(12),
          for (final r in rows) ...[
            Row(children: [
              SizedBox(
                width: 84,
                child: Text(r.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ProgressBar(
                  value: (r.rate / 1.2).clamp(0.0, 1.0),
                  color: colorOf?.call(r.key) ?? _accent,
                ),
              ),
              const Gap(8),
              SizedBox(
                width: 54,
                child: Text(_pct(r.rate),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w800)),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 84, top: 2, bottom: 10),
              child: Text(
                '${r.n}건${r.overMin != null ? ' · 최저가의 ${_pct(r.overMin!)}' : ''}',
                style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends ConsumerWidget {
  final SaleItem it;
  const _RecordRow(this.it);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final err = it.guessError;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => openSaleReview(context, ref, it),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _caseTitle(it, size: AppFont.label)),
            Text(Dates.ymd(it.saleDate),
                style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
          ]),
          const Gap(4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('낙찰 ${_pct(it.soldRate!)}',
                  style: const TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.w800, color: _accent)),
              Text(
                '${failBucket(it.fails)} · 최저 ${_pct(it.ratio)}'
                '${it.minPrice > 0 ? ' → 최저가의 ${_pct(it.soldPrice! / it.minPrice)}' : ''}'
                '${it.bidders != null ? ' · ${it.bidders}명' : ''}',
                style: const TextStyle(fontSize: AppFont.caption, color: AppColors.textSecondary),
              ),
              if (err != null)
                Pill('예상 ${Pct.signed(err * 100)}',
                    color: err.abs() <= kGuessHit ? AppColors.primary : AppColors.rose),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── 편집 ───────────────────────────────

String _draftKey(SaleItem it) => 'sale_review:${it.id}';

/// 오답노트 창만 — 저장을 누르면 sale_items 에 넣을 patch, 닫으면 null.
/// [history] 는 자동 분석·«기록으로 보면»에 쓰는 다른 물건들.
Future<Map<String, dynamic>?> showSaleReviewSheet(
  BuildContext context,
  SaleItem it, {
  List<SaleItem> history = const [],
}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReviewSheet(it, history: history),
    );

/// 오답노트 열기 → 저장하면 sale_items 한 줄을 고친다.
Future<void> openSaleReview(BuildContext context, WidgetRef ref, SaleItem it) async {
  final history = ref.read(saleItemsProvider).value ?? const <SaleItem>[];
  final patch = await showSaleReviewSheet(context, it, history: history);
  if (patch == null) return;
  try {
    await ref.read(supabaseProvider).from('sale_items').update(patch).eq('id', it.id);
  } catch (e) {
    // 쓴 글은 임시저장에 남아 있다 — 다시 열면 채워진다.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.rose,
        content: Text('저장 실패 — 쓴 글은 임시저장됨, 다시 열면 채워진다\n$e'),
      ));
    }
    return;
  }
  await FormDraft.clear(_draftKey(it));
  ref.invalidate(saleItemsProvider);
}

class _ReviewSheet extends StatefulWidget {
  final SaleItem it;
  final List<SaleItem> history;
  const _ReviewSheet(this.it, {required this.history});

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

  /// 매각 전엔 ① 만 — 결과·분석 칸은 매각일이 지나야 연다(미리 보이면 어지럽다).
  late bool _afterSale =
      _isPastOrToday(it.saleDate, DateTime.now()) || it.result != null;

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
    if (_result != null) _afterSale = true;
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
    _saveDraft(); // 창이 그냥 닫혀도(닫기·바깥 누름) 쓴 건 남긴다
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
        (_result != null ? it.saleDate.add(const Duration(days: kReviewAfterDays)) : null);
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
    final guide = rateGuide(it, widget.history);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오답노트 · ${it.zone}',
              style: const TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
          const Gap(4),
          Text(
            '${it.caseNo} · ${Dates.ymd(it.saleDate)} ${Dates.dday(it.saleDate)}\n'
            '감정 ${Won.compact(it.appraisal)} · 최저 ${Won.compact(it.minPrice)}'
            '${it.appraisal > 0 ? ' (${_pct(it.ratio)})' : ''}'
            '${it.fails > 0 ? ' · 유찰 ${it.fails}' : ''}',
            style: const TextStyle(fontSize: AppFont.label, color: AppColors.textSecondary),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: !_ready
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_restoredAt != null) ...[_draftBanner(), const Gap(14)],
                  // ① 매각 전 — 내 예상
                  _step(1, '매각 전 — 내 예상', '결과를 보기 전에 적어야 나중에 맞춰 본다'),
                  const Gap(12),
                  MoneyField(
                    label: '내 예상 낙찰가',
                    initial: _guess,
                    accent: _accent,
                    onChanged: (v) => setState(() => _guess = v),
                  ),
                  _note(_rateText(_guess) ??
                      (guide != null && it.appraisal > 0
                          ? '기록으로 보면 감정가의 ${_pct(guide.rate)} ≈ '
                              '${Won.compact(it.appraisal * guide.rate)} (${guide.basis} ${guide.n}건)'
                          : null)),
                  const Gap(12),
                  MoneyField(
                    label: '내 입찰가 (입찰했으면)',
                    initial: _myBid,
                    accent: _accent,
                    onChanged: (v) => setState(() => _myBid = v),
                  ),
                  _note(_rateText(_myBid)),
                  const Gap(22),
                  if (!_afterSale)
                    _beforeSaleBox()
                  else ...[
                    // ② 결과
                    _step(2, '결과', '행크옥션 «매각 결과»에서 옮긴다'),
                    const Gap(12),
                    _seg(kReviewResults, _result,
                        {for (final r in kReviewResults) r: _accent},
                        (v) => setState(() => _result = _result == v ? null : v)),
                    if (_result == '낙찰') ...[
                      const Gap(14),
                      MoneyField(
                        label: '낙찰가',
                        initial: _sold,
                        accent: _accent,
                        onChanged: (v) => setState(() => _sold = v),
                      ),
                      const Gap(12),
                      MoneyField(
                        label: '2위 입찰가',
                        initial: _second,
                        accent: _accent,
                        onChanged: (v) => setState(() => _second = v),
                      ),
                      const Gap(12),
                      TextField(
                        controller: _bidders,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: _fieldText,
                        decoration: _field('응찰자', hint: '몇 명', suffix: '명'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const Gap(12),
                      _metrics(),
                    ],
                    if (_result != null) ...[
                      const Gap(22),
                      // ③ 왜 이 가격?
                      _step(3, _result == '낙찰' ? '왜 이 가격?' : '왜 $_result?',
                          '앱이 숫자로 먼저 풀고, 내가 이유를 고르고 한 줄 쓴다'),
                      const Gap(12),
                      if (_result == '낙찰') _autoBox(),
                      _reasonGroup('↑ 값을 올린 것', kReasonsUp, _up),
                      const Gap(12),
                      _reasonGroup('↓ 값을 누른 것', kReasonsDown, _down),
                      const Gap(14),
                      TextField(
                        controller: _why,
                        minLines: 3,
                        maxLines: 8,
                        style: _fieldText,
                        decoration: _field('왜 이 가격에 낙찰됐나',
                            hint: '예) 4차라 최저가가 64%까지 내려와 6명이 몰렸다'),
                      ),
                      const Gap(12),
                      TextField(
                        controller: _lesson,
                        minLines: 2,
                        maxLines: 6,
                        style: _fieldText,
                        decoration: _field('다음엔 — 내가 쓴다면',
                            hint: '예) 이 구역 다세대는 감정가 75~80%를 써야 들어간다'),
                      ),
                      const Gap(22),
                      // ④ 나중에 다시 보기
                      _step(4, '나중에 다시 보기',
                          '날이 되면 오답노트 맨 위로 올라온다 · 비우면 매각일 +3달'),
                      const Gap(12),
                      _reviewDateRow(),
                      const Gap(12),
                      TextField(
                        controller: _reviewNote,
                        minLines: 2,
                        maxLines: 6,
                        style: _fieldText,
                        decoration: _field('다시 보니 — 그때 분석이 맞았나',
                            hint: '예) 전세가 2.4억에 바로 맞춰졌다. 낙찰자가 옳았다'),
                      ),
                      const Gap(12),
                      _seg(kVerdicts.keys.toList(), _verdict, kVerdicts,
                          (v) => setState(() => _verdict = _verdict == v ? null : v)),
                    ],
                  ],
                ],
              ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [
        SizedBox(
          height: _btnH,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w800),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
            const Gap(10),
            Expanded(
              flex: 2,
              child: SaveKey(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF2A1D00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _ready ? _submit : null,
                  child: const Text('저장'),
                ),
              ),
            ),
          ]),
        ),
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
              style: const TextStyle(fontSize: AppFont.label, color: _accent),
            ),
          ),
          TextButton(onPressed: _discardDraft, child: const Text('버리기')),
        ]),
      );

  Widget _step(int n, String title, String hint) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$n',
                style: const TextStyle(
                    fontSize: AppFont.label, fontWeight: FontWeight.w900, color: _accent)),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w800)),
                const Gap(2),
                Text(hint,
                    style: const TextStyle(fontSize: AppFont.label, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      );

  /// 칸 밑 한 줄 설명 — 칸과 같은 왼쪽 선.
  Widget _note(String? text) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6, left: 12),
          child: Text(text,
              style: const TextStyle(fontSize: AppFont.label, color: AppColors.textSecondary)),
        );

  /// «감정가의 77% · 최저가의 121%».
  String? _rateText(double v) {
    if (v <= 0 || it.appraisal <= 0) return null;
    return '감정가의 ${_pct(v / it.appraisal)}'
        '${it.minPrice > 0 ? ' · 최저가의 ${_pct(v / it.minPrice)}' : ''}';
  }

  Widget _beforeSaleBox() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.lock_clock_rounded, size: 18, color: AppColors.textFaint),
          const Gap(10),
          Expanded(
            child: Text(
              '매각일(${Dates.md(it.saleDate)})이 지나면 ② 결과 · ③ 왜 이 가격? · ④ 다시 보기가 열립니다',
              style: const TextStyle(fontSize: AppFont.label, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _afterSale = true),
            child: const Text('지금 열기'),
          ),
        ]),
      );

  /// 낙찰가를 넣으면 바로 — 낙찰가율 · 2위와 차이 · 내 예상/입찰과 비교.
  Widget _metrics() {
    if (_sold <= 0) return const SizedBox.shrink();
    final lines = <(String, Color)>[
      if (it.appraisal > 0)
        ('낙찰가율 ${_pct(_sold / it.appraisal)}'
            '${it.minPrice > 0 ? ' · 최저가의 ${_pct(_sold / it.minPrice)}' : ''}', _accent),
      if (_guess > 0)
        ('내 예상보다 ${Pct.signed((_sold - _guess) / _guess * 100)} '
            '(${_sold >= _guess ? '낮게 봤다' : '높게 봤다'})',
            ((_sold - _guess) / _guess).abs() <= kGuessHit ? AppColors.primary : AppColors.rose),
      if (_myBid > 0)
        (_myBid >= _sold
            ? '내 입찰가가 낙찰가 이상 — 내가 썼다면 가져왔다'
            : '내 입찰가가 ${Won.compact(_sold - _myBid)} 모자랐다',
            _myBid >= _sold ? AppColors.primary : AppColors.rose),
    ];
    return _box(lines.map((l) => Text(l.$1,
        style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w800, color: l.$2))));
  }

  /// 자동 분석 — 숫자로 먼저 풀고, 추천 이유를 한 번에 넣는다.
  Widget _autoBox() {
    final a = autoAnalysis(
      it: it,
      sold: _sold,
      bidders: int.tryParse(_bidders.text.trim()),
      second: _second,
      history: widget.history,
    );
    if (a.lines.isEmpty) return const SizedBox.shrink();
    final missing = a.tags.difference(_reasons);
    final whyEmpty = _why.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _box([
        const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.violet),
          Gap(6),
          Text('자동 분석',
              style: TextStyle(
                  fontSize: AppFont.label, fontWeight: FontWeight.w800, color: AppColors.violet)),
        ]),
        for (final l in a.lines)
          Text('· $l', style: const TextStyle(fontSize: AppFont.body, height: 1.4)),
        if (missing.isNotEmpty || whyEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, _chipH),
                foregroundColor: AppColors.violet,
                side: const BorderSide(color: AppColors.violet),
                textStyle: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w800),
              ),
              onPressed: () => setState(() {
                _reasons.addAll(a.tags);
                if (_why.text.trim().isEmpty) _why.text = a.lines.join('\n');
              }),
              icon: const Icon(Icons.south_rounded, size: 16),
              label: Text([
                if (missing.isNotEmpty) '이유 ${missing.join('·')}',
                if (whyEmpty) '글',
              ].join(' + ') + ' 넣기'),
            ),
          ),
      ]),
    );
  }

  Widget _box(Iterable<Widget> children) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const Gap(6), c],
          ],
        ),
      );

  /// 한 줄에 같은 폭 버튼 — 하나만 고른다(다시 누르면 해제).
  Widget _seg(List<String> opts, String? value, Map<String, Color> colors,
      ValueChanged<String> onTap) {
    return SizedBox(
      height: _segH,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final o in opts) ...[
          if (o != opts.first) const Gap(8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(o),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == o
                      ? (colors[o] ?? _accent).withValues(alpha: 0.22)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: value == o ? (colors[o] ?? _accent) : AppColors.border),
                ),
                child: Text(o,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w800,
                      color: value == o ? (colors[o] ?? _accent) : AppColors.textSecondary,
                    )),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _reasonGroup(String title, List<String> opts, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w800, color: c)),
          const Gap(8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in opts)
              InkWell(
                borderRadius: BorderRadius.circular(_chipH / 2),
                onTap: () => setState(
                    () => _reasons.contains(o) ? _reasons.remove(o) : _reasons.add(o)),
                child: Container(
                  height: _chipH,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _reasons.contains(o) ? c.withValues(alpha: 0.18) : Colors.transparent,
                    border: Border.all(
                        color: _reasons.contains(o) ? c : AppColors.border,
                        width: _reasons.contains(o) ? 1.4 : 1),
                    borderRadius: BorderRadius.circular(_chipH / 2),
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
    ButtonStyle style(bool on) => OutlinedButton.styleFrom(
          minimumSize: const Size(0, _chipH),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: BorderSide(color: on ? _accent : AppColors.border),
          foregroundColor: on ? _accent : AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_chipH / 2)),
          textStyle: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w800),
        );
    bool same(DateTime d) =>
        _reviewOn != null &&
        _reviewOn!.year == d.year &&
        _reviewOn!.month == d.month &&
        _reviewOn!.day == d.day;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          style: style(_reviewOn != null),
          onPressed: () async {
            final d = await pickDay(context, initial: _reviewOn ?? plus(3));
            if (d != null && mounted) setState(() => _reviewOn = d);
          },
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(_reviewOn == null
              ? '날짜 고르기'
              : '${Dates.ymd(_reviewOn!)} ${Dates.dday(_reviewOn!)}'),
        ),
        for (final m in [1, 3, 6])
          OutlinedButton(
            style: style(same(plus(m))),
            onPressed: () => setState(() => _reviewOn = plus(m)),
            child: Text('+$m달'),
          ),
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
