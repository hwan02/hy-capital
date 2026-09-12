// 정비구역(모아타운·신통) 조합원 매물 수익 계산기.
//
// 출처: 자료실 「부자되는세상 정비사업 수익 계산기」(서울투자반).
// 그 표를 «행 순서 그대로» 옮겼다. 엑셀에서 파란 숫자(0070C0)가 직접 넣는
// 칸이고 나머지는 수식인데, 여기서도 파란 칸 7개만 채우면 끝난다.
//
//   조합원분양가 · 감정가 · 비례율 · 추가분담금 · 전월세가 · 매매가 · 예상시세
//
//   권리가액   = 감정가 × 비례율            (비례율 미확정이면 100% 가정)
//   분담금     = 조합원분양가 − 권리가액     (음수면 오히려 환급)
//   실투자금   = 매매가 − 전월세가[또는 이주비대출]
//   총 매매가  = 매매가 + 분담금 + 추가분담금
//   예상수익금 = 대장아파트 예상시세 − 총 매매가
//   예상수익률 = 예상수익금 ÷ 실투자금        ← 분모가 «실»투자금인 게 핵심
//
// «정밀 계산»을 켜면 취득세·법무비·중개비·양도세가 붙는다. 원본 표엔 없는데,
// 공시가 1억↓ 법인 1.1% 와 중과 12% 가 수익률을 뒤집고(자료실 「명의전략_법인」)
// 내 전략이 법인 단기매도라 세후가 진짜 수익이기 때문이다.
// 끄면 «엑셀과 숫자가 완전히 같다» — 그래서 기본은 꺼짐이다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/edit/plain_controller.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import 'calc_fields.dart';
import 'calc_history.dart';

/// 장세별 매수 기준 — 실투자금 대비 몇 %가 남아야 «Yes» 인가.
/// 부자되는세상 기준(엑셀 C17 주석) 그대로.
enum Market {
  earlyBull('상승장 초반', 80),
  midBull('상승장 중후반', 100),
  bear('하락장', 150);

  final String label;
  final int cut;
  const Market(this.label, this.cut);
}

/// 엑셀의 «파란 숫자» = 내가 넣는 칸. 화면에서도 파랗게 둔다.
const _input = calcInputAccent;

class RedevCalculator extends ConsumerStatefulWidget {
  const RedevCalculator({super.key});

  @override
  ConsumerState<RedevCalculator> createState() => _RedevCalculatorState();
}

class _RedevCalculatorState extends ConsumerState<RedevCalculator> {
  final _label = PlainController();
  String? _editingId;
  int _rev = 0;

  // 엑셀 파란 칸 7개 + 평형(라벨용)
  double size = 0;
  double memberPrice = 0, appraisal = 0, propRate = 100, extra = 0;
  double jeonse = 0, price = 0, exitPrice = 0;

  // 정밀 계산 — 기본 꺼짐. 끄면 엑셀과 숫자가 같다.
  bool precise = false;
  double acqPct = 1.1, legal = 0, agent = 0, etc = 0, taxPct = 20;

  Market market = Market.midBull;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Map<String, dynamic> _inputs() => {
        'size': size,
        'memberPrice': memberPrice, 'appraisal': appraisal,
        'propRate': propRate, 'extra': extra,
        'jeonse': jeonse, 'price': price, 'exitPrice': exitPrice,
        'precise': precise ? 1 : 0,
        'acqPct': acqPct, 'legal': legal, 'agent': agent, 'etc': etc,
        'taxPct': taxPct, 'market': market.name,
      };

  void _load(CalcRecord r) {
    setState(() {
      _editingId = r.id;
      _label.text = r.label;
      size = r.num_('size');
      memberPrice = r.num_('memberPrice'); appraisal = r.num_('appraisal');
      propRate = r.num_('propRate'); extra = r.num_('extra');
      jeonse = r.num_('jeonse'); price = r.num_('price');
      exitPrice = r.num_('exitPrice');
      precise = r.num_('precise') == 1;
      acqPct = r.num_('acqPct'); legal = r.num_('legal');
      agent = r.num_('agent'); etc = r.num_('etc'); taxPct = r.num_('taxPct');
      market = Market.values.firstWhere((m) => m.name == r.str_('market'),
          orElse: () => Market.midBull);
      _rev++;
    });
  }

  void _reset() {
    setState(() {
      _editingId = null; _label.clear();
      size = 0;
      memberPrice = 0; appraisal = 0; propRate = 100; extra = 0;
      jeonse = 0; price = 0; exitPrice = 0;
      precise = false;
      acqPct = 1.1; legal = 0; agent = 0; etc = 0; taxPct = 20;
      market = Market.midBull;
      _rev++;
    });
  }

  Future<void> _save() async {
    final id = await saveCalcRecord(context, ref,
        kind: 'redev', label: _label.text,
        inputs: _inputs(), editingId: _editingId);
    if (mounted && id != null) setState(() => _editingId = id);
  }

  // ── 계산 (엑셀 D7·D8·D12·D13·D15·D16 그대로) ──
  double get rightsValue => appraisal * propRate / 100;
  double get contribution => memberPrice - rightsValue;
  double get acqTax => precise ? price * acqPct / 100 : 0;
  double get costTotal => precise ? acqTax + legal + agent + etc : 0;
  double get netInvest => price - jeonse + costTotal;
  double get totalInvest => price + contribution + extra + costTotal;
  double get gain => exitPrice - totalInvest;
  double get capTax => precise && gain > 0 ? gain * taxPct / 100 : 0;
  double get netGain => gain - capTax;
  double get yieldPre => netInvest > 0 ? gain / netInvest * 100 : 0;
  double get yieldPost => netInvest > 0 ? netGain / netInvest * 100 : 0;

  bool get ready => netInvest > 0 && exitPrice > 0 && memberPrice > 0;
  bool get pass => ready && yieldPre >= market.cut;

  @override
  Widget build(BuildContext context) {
    final verdictColor =
        !ready ? AppColors.textFaint : (pass ? AppColors.primary : AppColors.rose);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
          child: Text('정비구역 매물 수익 계산기',
              style: TextStyle(
                  fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        ),
        if (_editingId != null)
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.add_rounded, size: 16),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            label: const Text('새 계산'),
          ),
      ]),
      const Gap(2),
      const Text('파란 띠가 붙은 칸 7개만 채우면 나머지는 자동으로 계산된다',
          style: TextStyle(fontSize: AppFont.caption, color: _input)),
      const Gap(14),

      Row(children: [
        Expanded(
          child: TextField(
            controller: _label,
            decoration: const InputDecoration(
                labelText: '구역·매물 (예: 화곡1동 354 우성빌라 201호)',
                isDense: true),
          ),
        ),
        const Gap(10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          onPressed: _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(_editingId != null ? '수정 저장' : '이력 저장'),
        ),
      ]),
      const Gap(16),

      // ── 엑셀 표 그대로. 한 줄에 하나씩, 위에서 아래로. ──
      GlassCard(
        accent: _input,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          calcGrid([
            calcNumRow2('평형신청', size, (v) => size = v, suffix: 'm²', blue: false),
            calcMoneyRow2('조합원분양가', memberPrice, (v) => memberPrice = v,
                note: '조합에서 발표한 조합원 대상 분양가격'),
            calcMoneyRow2('감정가', appraisal, (v) => appraisal = v,
                note: '조합에서 발표한 부동산 감정가격'),
            calcNumRow2('비례율', propRate, (v) => propRate = v, suffix: '%',
                note: '확정이 안 됐으면 100 그대로 둔다'),
          ]),

          calcDivider(),
          calcLine(calcRow('권리가액', rightsValue)),
          calcLine(calcTextRow(
              contribution < 0 ? '분담금 (권리가액이 더 커서 환급)' : '분담금',
              '${Won.compact(contribution.abs())}원',
              color: contribution < 0 ? AppColors.primary : null)),
          calcDivider(),

          calcGrid([
            calcMoneyRow2('추가분담금', extra, (v) => extra = v, note: '공사비 증액 시 기재'),
            calcMoneyRow2('전월세가 (또는 이주비대출)', jeonse, (v) => jeonse = v,
                note: '이주·철거 단계면 이주비대출 금액 · 미정이면 감정가의 60%'),
            calcMoneyRow2('매매가', price, (v) => price = v, note: '부동산에서 얘기한 가격'),
          ]),

          calcDivider(),
          calcLine(calcRow('실투자금', netInvest, strong: true, color: AppColors.gold)),
          calcLine(calcRow('총 매매가 (총 투자금)', totalInvest, strong: true, color: AppColors.gold)),
          calcDivider(),

          calcGrid([
            calcMoneyRow2('예상 시세 (대장아파트)', exitPrice, (v) => exitPrice = v,
                note: '동호수 추첨 전이면 낮은 층 · 호가와 실거래 차이가 크면 평균'),
          ]),

          calcDivider(),
          calcLine(calcRow('예상수익금', gain)),
          calcLine(calcTextRow('예상수익률',
              ready ? '${yieldPre.toStringAsFixed(1)}%' : '—',
              strong: true, color: verdictColor)),
        ]),
      ),
      const Gap(14),

      // ── 정밀 계산 — 끄면 위 숫자가 엑셀과 완전히 같다. ──
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SwitchListTile(
            value: precise,
            onChanged: (v) => setState(() => precise = v),
            activeThumbColor: AppColors.gold,
            contentPadding: EdgeInsets.zero,
            title: const Text('정밀 계산 — 취득세·양도세 반영',
                style: TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            subtitle: const Text(
                '끄면 원본 표와 숫자가 같다. 켜면 공시가 1억↓ 1.1% / 중과 12% 와 법인세가 붙는다.',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
          ),
          if (precise) ...[
            const Gap(6),
            calcGrid([
              calcNumRow2('취득세율', acqPct, (v) => acqPct = v, suffix: '%', blue: false),
              calcMoneyRow2('법무비용', legal, (v) => legal = v, blue: false),
              calcMoneyRow2('중개비', agent, (v) => agent = v, blue: false),
              calcMoneyRow2('기타비용', etc, (v) => etc = v, blue: false),
              calcNumRow2('양도세율 (법인세 포함)', taxPct, (v) => taxPct = v,
                  suffix: '%', blue: false),
            ]),
            const Gap(6),
            calcRow('취득세', acqTax),
            calcRow('취득비용 합계', costTotal),
            calcRow('양도세·법인세', capTax),
            calcRow('세후 수익금', netGain, strong: true, color: AppColors.primary),
            calcTextRow('세후 수익률',
                ready ? '${yieldPost.toStringAsFixed(1)}%' : '—'),
          ],
        ]),
      ),
      const Gap(14),

      // ── 투자선택 (엑셀 17행) ──
      GlassCard(
        accent: verdictColor,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader('투자선택', subtitle: '장세에 따라 기준이 달라진다'),
          const Gap(12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in Market.values)
              ChoiceChip(
                label: Text('${m.label} ${m.cut}%'),
                selected: market == m,
                onSelected: (_) => setState(() => market = m),
                labelStyle: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700,
                    color: market == m ? AppColors.violet : AppColors.textSecondary),
                selectedColor: AppColors.violet.withValues(alpha: 0.16),
                backgroundColor: Colors.transparent,
                side: BorderSide(
                    color: market == m ? AppColors.violet : AppColors.border),
              ),
          ]),
          const Gap(14),
          calcTextRow('기준', '실투자금 대비 ${market.cut}%'),
          calcTextRow('예상수익률', ready ? '${yieldPre.toStringAsFixed(1)}%' : '입력 중'),
          const Gap(8),
          calcTail(
              ready ? (pass ? '기준 통과' : '기준 미달') : '매매가·조합원분양가·예상 시세를 채우면 판정한다',
              ready ? (pass ? 'Yes' : 'No') : '—',
              verdictColor),
        ]),
      ),
      const Gap(22),

      CalcHistory(
        kind: 'redev',
        editingId: _editingId,
        onLoad: _load,
        onDelete: (id) {
          if (_editingId == id) setState(() => _editingId = null);
          deleteCalcRecord(ref, id);
        },
        summary: _summary,
        badge: _badge,
      ),
    ]);
  }

  // setState 를 씌운 얇은 어댑터 — 줄 모양은 calc_fields 가 정한다.
  Widget calcMoneyRow2(String label, double value, ValueChanged<double> set,
          {String? note, bool blue = true}) =>
      calcMoneyRow(label, value, (v) => setState(() => set(v)), _rev,
          note: note, blue: blue);

  Widget calcNumRow2(String label, double value, ValueChanged<double> set,
          {required String suffix, String? note, bool blue = true}) =>
      calcNumRow(label, value, (v) => setState(() => set(v)), _rev,
          suffix: suffix, note: note, blue: blue);

  // ── 이력 요약 ──
  static ({double net, double total, double contribution, double yield_})
      _calc(CalcRecord r) {
    final price = r.num_('price');
    final cost = r.num_('precise') == 1
        ? price * r.num_('acqPct') / 100 +
            r.num_('legal') + r.num_('agent') + r.num_('etc')
        : 0.0;
    final net = price - r.num_('jeonse') + cost;
    final contribution =
        r.num_('memberPrice') - r.num_('appraisal') * r.num_('propRate') / 100;
    final total = price + contribution + r.num_('extra') + cost;
    final exit = r.num_('exitPrice');
    return (
      net: net,
      total: total,
      contribution: contribution,
      yield_: (net > 0 && exit > 0) ? (exit - total) / net * 100 : double.nan,
    );
  }

  String _summary(CalcRecord r) {
    final c = _calc(r);
    final size = r.num_('size');
    final head = size > 0 ? '${size.toStringAsFixed(0)}m² · ' : '';
    return '$head실투자 ${Won.compact(c.net)} · 분담금 ${Won.compact(c.contribution)} · '
        '총투자 ${Won.compact(c.total)}';
  }

  Widget? _badge(CalcRecord r) {
    final y = _calc(r).yield_;
    if (y.isNaN) return null;
    final m = Market.values.firstWhere((x) => x.name == r.str_('market'),
        orElse: () => Market.midBull);
    final ok = y >= m.cut;
    return Pill('${y.toStringAsFixed(0)}% ${ok ? 'Yes' : 'No'}',
        color: ok ? AppColors.primary : AppColors.rose);
  }
}
