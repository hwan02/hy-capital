// 정비구역(모아타운·신통) 조합원 매물 수익 계산기.
//
// 출처: 자료실 「부자되는세상 정비사업 수익 계산기」(서울투자반) 표를 옮긴 것.
// 경매 계산기와 «절차가 아예 달라» 화면을 나눴다. 낙찰가·입찰보증금이 아니라
// 매매가 + 분담금으로 총투자금이 잡히고, 출구는 «대장아파트 시세»다.
//
//   권리가액   = 감정가 × 비례율            (비례율 미확정이면 100% 가정)
//   분담금     = 조합원분양가 − 권리가액     (음수면 오히려 환급)
//   실투자금   = 매매가 − 전월세가[또는 이주비대출] + 취득비용
//   총투자금   = 매매가 + 분담금 + 추가분담금 + 취득비용
//   예상수익금 = 대장아파트 예상시세 − 총투자금
//   수익률     = 예상수익금 ÷ 실투자금        ← 분모가 «실»투자금인 게 핵심
//
// 원본 표와 다른 점 두 가지 — 둘 다 «일부러» 더한 것이다.
//  · 취득세·법무비·중개비: 원본엔 없다. 공시가 1억↓ 법인 1.1% 와 중과 12% 가
//    수익률을 뒤집는데 무시할 수 없다(자료실 「명의전략_법인」).
//  · 양도세·법인세: 원본엔 없다. 내 전략이 «법인 단기매도»라 세후가 진짜 수익이다.
//    다만 «투자선택» 판정은 원본 기준대로 «세전» 수익률로 한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/edit/plain_controller.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'calc_fields.dart';
import 'calc_history.dart';

/// 장세별 매수 기준 — 실투자금 대비 몇 %가 남아야 «Yes» 인가.
/// 부자되는세상 기준(서울투자반 교안)을 그대로 쓴다.
enum Market {
  earlyBull('상승장 초반', 80),
  midBull('상승장 중후반', 100),
  bear('하락장', 150);

  final String label;
  final int cut;
  const Market(this.label, this.cut);
}

class RedevCalculator extends ConsumerStatefulWidget {
  const RedevCalculator({super.key});

  @override
  ConsumerState<RedevCalculator> createState() => _RedevCalculatorState();
}

class _RedevCalculatorState extends ConsumerState<RedevCalculator> {
  final _label = PlainController();
  String? _editingId;
  int _rev = 0;

  // 매물
  double size = 0, price = 0, jeonse = 0;
  double acqPct = 1.1, legal = 0, agent = 0, etc = 0;
  // 권리 (조합 발표)
  double memberPrice = 0, appraisal = 0, propRate = 100, extra = 0;
  // 출구
  double exitPrice = 0, taxPct = 20;
  Market market = Market.midBull;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Map<String, dynamic> _inputs() => {
        'size': size, 'price': price, 'jeonse': jeonse,
        'acqPct': acqPct, 'legal': legal, 'agent': agent, 'etc': etc,
        'memberPrice': memberPrice, 'appraisal': appraisal,
        'propRate': propRate, 'extra': extra,
        'exitPrice': exitPrice, 'taxPct': taxPct, 'market': market.name,
      };

  void _load(CalcRecord r) {
    setState(() {
      _editingId = r.id;
      _label.text = r.label;
      size = r.num_('size'); price = r.num_('price'); jeonse = r.num_('jeonse');
      acqPct = r.num_('acqPct'); legal = r.num_('legal');
      agent = r.num_('agent'); etc = r.num_('etc');
      memberPrice = r.num_('memberPrice'); appraisal = r.num_('appraisal');
      propRate = r.num_('propRate'); extra = r.num_('extra');
      exitPrice = r.num_('exitPrice'); taxPct = r.num_('taxPct');
      market = Market.values.firstWhere((m) => m.name == r.str_('market'),
          orElse: () => Market.midBull);
      _rev++;
    });
  }

  void _reset() {
    setState(() {
      _editingId = null; _label.clear();
      size = 0; price = 0; jeonse = 0;
      acqPct = 1.1; legal = 0; agent = 0; etc = 0;
      memberPrice = 0; appraisal = 0; propRate = 100; extra = 0;
      exitPrice = 0; taxPct = 20; market = Market.midBull;
      _rev++;
    });
  }

  Future<void> _save() async {
    final id = await saveCalcRecord(context, ref,
        kind: 'redev',
        label: _label.text,
        inputs: _inputs(),
        editingId: _editingId);
    if (mounted && id != null) setState(() => _editingId = id);
  }

  // ── 계산 ──
  double get acqTax => price * acqPct / 100;
  double get costTotal => acqTax + legal + agent + etc;
  /// 갭 — 취득비용 전. 원본 표의 «실투자금»이 이 값이다.
  double get gap => price - jeonse;
  /// 전세가율. 매매가가 0이면 표시하지 않는다.
  double get jeonseRate => price > 0 ? jeonse / price * 100 : 0;
  /// 지금 당장 나가는 내 돈. 분담금은 관리처분 이후라 여기 들어가지 않는다.
  double get netInvest => gap + costTotal;
  double get rightsValue => appraisal * propRate / 100;
  /// 음수면 환급받는다(권리가액 > 조합원분양가).
  double get contribution => memberPrice - rightsValue;
  double get totalInvest => price + contribution + extra + costTotal;
  double get gain => exitPrice - totalInvest;
  double get capTax => gain > 0 ? gain * taxPct / 100 : 0;
  double get netGain => gain - capTax;
  double get yieldPre => netInvest > 0 ? gain / netInvest * 100 : 0;
  double get yieldPost => netInvest > 0 ? netGain / netInvest * 100 : 0;

  /// 판정할 수 있을 만큼 입력이 찼나.
  bool get ready => netInvest > 0 && exitPrice > 0 && memberPrice > 0;
  bool get pass => ready && yieldPre >= market.cut;

  @override
  Widget build(BuildContext context) {
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
            style:
                TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            label: const Text('새 계산'),
          ),
      ]),
      const Gap(2),
      Text(
          _editingId != null
              ? '이력 수정 중 — 저장하면 갱신됩니다'
              : '조합원 매물(모아타운·신통) 전용 · 경매 물건은 «경매» 모드로',
          style: const TextStyle(
              fontSize: AppFont.caption, color: AppColors.textFaint)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          onPressed: _save,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(_editingId != null ? '수정 저장' : '이력 저장'),
        ),
      ]),
      const Gap(16),

      // ① 매물 — 지금 나가는 돈
      _card('① 매물 · 지금 나가는 돈', Icons.home_work_rounded, AppColors.gold, [
        calcMoney('매매가', price, (v) => setState(() => price = v), _rev),
        calcMoney('전월세가 · 이주비대출', jeonse, (v) => setState(() => jeonse = v), _rev),
        calcPct('취득세율', acqPct, (v) => setState(() => acqPct = v), _rev),
        calcMoney('법무비용', legal, (v) => setState(() => legal = v), _rev),
        calcMoney('중개비', agent, (v) => setState(() => agent = v), _rev),
        calcMoney('기타비용', etc, (v) => setState(() => etc = v), _rev),
      ], [
        calcRow('갭 (매매가 − 보증금)', gap),
        if (price > 0)
          calcTextRow('전세가율', '${jeonseRate.toStringAsFixed(1)}%'),
        calcRow('취득세', acqTax),
        calcRow('취득비용 합계', costTotal),
        const Divider(height: 20, color: AppColors.border),
        calcRow('실투자금', netInvest, strong: true, color: AppColors.gold),
      ], note: '이주·철거 단계면 전월세가 대신 «이주비대출»을 넣는다(미정이면 감정가 60%).'),
      const Gap(14),

      // ② 권리 — 나중에 나가는 돈
      _card('② 권리 · 나중에 나가는 돈', Icons.gavel_rounded, AppColors.sky, [
        calcNumber('평형신청', size, (v) => setState(() => size = v), _rev, suffix: 'm²'),
        calcMoney('조합원분양가', memberPrice, (v) => setState(() => memberPrice = v), _rev),
        calcMoney('감정가', appraisal, (v) => setState(() => appraisal = v), _rev),
        calcPct('비례율', propRate, (v) => setState(() => propRate = v), _rev),
        calcMoney('추가분담금', extra, (v) => setState(() => extra = v), _rev),
      ], [
        calcRow('권리가액 (감정가 × 비례율)', rightsValue),
        calcTextRow(
            contribution < 0 ? '환급금 (권리가액 > 분양가)' : '분담금 (분양가 − 권리가액)',
            '${Won.compact(contribution.abs())}원',
            color: contribution < 0 ? AppColors.primary : null),
        const Divider(height: 20, color: AppColors.border),
        calcRow('총투자금', totalInvest, strong: true, color: AppColors.sky),
      ], note: '비례율이 확정 전이면 100%로 둔다. 공사비가 오르면 «추가분담금»에 적는다.'),
      const Gap(14),

      // ③ 출구
      _card('③ 출구 · 대장아파트 시세', Icons.sell_rounded, AppColors.primary, [
        calcMoney('예상 시세 (대장아파트)', exitPrice, (v) => setState(() => exitPrice = v), _rev),
        calcPct('양도세율 (법인세 포함)', taxPct, (v) => setState(() => taxPct = v), _rev),
      ], [
        calcRow('예상수익금 (시세 − 총투자금)', gain),
        calcRow('양도세·법인세', capTax),
        calcRow('세후 수익금', netGain, strong: true, color: AppColors.primary),
        const Gap(6),
        calcTail(
            '수익률 (세전 · 실투자금 대비)',
            ready ? '${yieldPre.toStringAsFixed(1)}%' : '—',
            pass ? AppColors.primary : AppColors.gold),
        const Gap(4),
        calcTextRow('세후 수익률',
            ready ? '${yieldPost.toStringAsFixed(1)}%' : '—'),
      ], note: '동호수 추첨 전이면 낮은 층 기준. 호가와 실거래가 차이가 크면 평균으로.'),
      const Gap(14),

      _verdict(),
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

  // ── 투자선택 판정 ──
  Widget _verdict() {
    final color = !ready
        ? AppColors.textFaint
        : (pass ? AppColors.primary : AppColors.rose);
    return GlassCard(
      accent: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('투자선택',
            subtitle: '부자되는세상 기준 — 장세에 따라 컷이 달라진다'),
        const Gap(12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in Market.values)
            ModuleTab(
              label: '${m.label} ${m.cut}%',
              icon: Icons.trending_up_rounded,
              color: AppColors.violet,
              selected: market == m,
              onTap: () => setState(() => market = m),
            ),
        ]),
        const Gap(14),
        calcTextRow('기준', '실투자금 대비 ${market.cut}%'),
        calcTextRow('현재', ready ? '${yieldPre.toStringAsFixed(1)}%' : '입력 중'),
        const Gap(8),
        calcTail(
            ready ? (pass ? '기준 통과' : '기준 미달') : '입력이 더 필요하다',
            ready ? (pass ? 'Yes' : 'No') : '—',
            color),
        if (!ready) ...[
          const Gap(8),
          const Text('매매가 · 조합원분양가 · 예상 시세를 채우면 판정합니다.',
              style: TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint)),
        ],
      ]),
    );
  }

  Widget _card(String title, IconData icon, Color color, List<Widget> inputs,
      List<Widget> results, {String? note}) {
    return GlassCard(
      accent: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const Gap(8),
          Text(title,
              style: const TextStyle(
                  fontSize: AppFont.section, fontWeight: FontWeight.w800)),
        ]),
        if (note != null) ...[
          const Gap(4),
          Text(note,
              style: const TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint)),
        ],
        const Gap(12),
        ResponsiveGrid(minTileWidth: 150, spacing: 10, children: inputs),
        const Gap(12),
        ...results,
      ]),
    );
  }

  // ── 이력 요약 ──
  static double _yieldOf(CalcRecord r) {
    final price = r.num_('price');
    final cost = price * r.num_('acqPct') / 100 +
        r.num_('legal') + r.num_('agent') + r.num_('etc');
    final net = price - r.num_('jeonse') + cost;
    final contribution =
        r.num_('memberPrice') - r.num_('appraisal') * r.num_('propRate') / 100;
    final total = price + contribution + r.num_('extra') + cost;
    if (net <= 0 || r.num_('exitPrice') <= 0) return double.nan;
    return (r.num_('exitPrice') - total) / net * 100;
  }

  String _summary(CalcRecord r) {
    final price = r.num_('price');
    final cost = price * r.num_('acqPct') / 100 +
        r.num_('legal') + r.num_('agent') + r.num_('etc');
    final net = price - r.num_('jeonse') + cost;
    final contribution =
        r.num_('memberPrice') - r.num_('appraisal') * r.num_('propRate') / 100;
    final total = price + contribution + r.num_('extra') + cost;
    final size = r.num_('size');
    final head = size > 0 ? '${size.toStringAsFixed(0)}m² · ' : '';
    return '$head실투자 ${Won.compact(net)} · 분담금 ${Won.compact(contribution)} · '
        '총투자 ${Won.compact(total)}';
  }

  Widget? _badge(CalcRecord r) {
    final y = _yieldOf(r);
    if (y.isNaN) return null;
    final m = Market.values.firstWhere((x) => x.name == r.str_('market'),
        orElse: () => Market.midBull);
    final ok = y >= m.cut;
    return Pill('${y.toStringAsFixed(0)}% ${ok ? 'Yes' : 'No'}',
        color: ok ? AppColors.primary : AppColors.rose);
  }
}
