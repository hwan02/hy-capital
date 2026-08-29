import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// 부동산 세제·규제 일자별 타임라인 (시행일 기준).
/// 2026 세제개편(8.3 발표)은 국회 통과 전 → '개편안' 배지.
class _Item {
  final DateTime date;
  final String title;
  final String desc;
  final String kind; // 세제 · 정비
  final bool pending; // 국회 통과 전(확정 아님)
  const _Item(this.date, this.title, this.desc, this.kind,
      {this.pending = false});
}

final _items = <_Item>[
  _Item(DateTime(2020, 8, 12), '법인 주택 취득세 12% 중과',
      '법인이 주택 취득 시 대부분 12%. 공시가 1억 이하 등은 예외.', '세제'),
  _Item(DateTime(2026, 2, 27), '모아타운 조합설립 동의율 완화',
      '소규모재건축 75%→70%, 소규모재개발 80%→75%.', '정비'),
  _Item(DateTime(2026, 7, 10), '모아주택 심의기준 손질',
      '준주거 상향·용적률 최대 500%·제2종 층수제한 폐지(중고층 가능).', '정비'),
  _Item(DateTime(2026, 8, 18), '조합설립 기간 1년→4개월',
      '추진위 조기구성 + 75%↑ 동의 시 병행 처리. 365일→120일.', '정비'),
  _Item(DateTime(2026, 10, 1), '일시적 2주택 처분기간 3년→2년',
      '조정대상지역. 2026 세제개편안.', '세제', pending: true),
  _Item(DateTime(2027, 1, 1), '종부세 인상 + 양도세 공제 확대',
      '고가·다주택 보유세↑ (1주택 공제 거주 14억/비거주 9억, 공정시장가액비율 60→70%·3주택+ 80%). '
          '양도세: 10년 거주 1주택 기본공제 250만→2,500만.',
      '세제',
      pending: true),
  _Item(DateTime(2028, 1, 1), '장기보유특별공제 «거주 중심» 개편',
      '거주 연 8% + 보유 연 2%, 최대 80%. 보유공제 → 거주공제로 이동.', '세제', pending: true),
];

Color _kindColor(String k) => k == '정비' ? _teal : AppColors.violet;

const _teal = Color(0xFF14B8A6);

class TaxTimeline extends StatelessWidget {
  const TaxTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sorted = [..._items]..sort((a, b) => a.date.compareTo(b.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('부동산 세제·규제 타임라인',
            style:
                TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        const Text('시행일 기준 · 2026 세제개편은 8.3 발표안(국회 통과 전 → 변동 가능)',
            style:
                TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(16),
        for (var i = 0; i < sorted.length; i++)
          _row(sorted[i], now, first: i == 0, last: i == sorted.length - 1),
        const Gap(10),
        _legend(),
        const Gap(8),
        const Text(
          '※ 확정 아님(개편안)은 원문(기재부 보도자료)·세무사로 재확인. 규제지역 지정/해제·대출 규제는 자료실 참조. 자동 갱신 아님.',
          style: TextStyle(
              fontSize: AppFont.caption, color: AppColors.textFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _row(_Item it, DateTime now, {required bool first, required bool last}) {
    final future = it.date.isAfter(now);
    final dday = it.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final c = _kindColor(it.kind);
    final nodeColor = future ? c : AppColors.textFaint;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 축(선 + 노드)
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                    width: 2,
                    height: 6,
                    color: first ? Colors.transparent : AppColors.border),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: future ? c : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                      width: 2,
                      color: last ? Colors.transparent : AppColors.border),
                ),
              ],
            ),
          ),
          const Gap(12),
          // 카드
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                accent: future ? c : null,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                          '${it.date.year}.${it.date.month.toString().padLeft(2, '0')}.${it.date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w800,
                              color: future ? c : AppColors.textSecondary)),
                      const Gap(8),
                      Pill(it.kind, color: c),
                      if (it.pending) ...[
                        const Gap(6),
                        const Pill('개편안', color: AppColors.gold),
                      ],
                      const Spacer(),
                      Text(
                          future
                              ? (dday == 0 ? '오늘' : 'D-$dday')
                              : '시행',
                          style: TextStyle(
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w700,
                              color: future
                                  ? (dday <= 60 ? AppColors.rose : c)
                                  : AppColors.textFaint)),
                    ]),
                    const Gap(6),
                    Text(it.title,
                        style: const TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800,
                            height: 1.35)),
                    const Gap(4),
                    Text(it.desc,
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            color: AppColors.textSecondary,
                            height: 1.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() => Row(children: [
        _dot(_teal, '정비(모아타운·규제완화)'),
        const Gap(14),
        _dot(AppColors.violet, '세제'),
        const Gap(14),
        _dot(AppColors.gold, '개편안(국회 전)'),
      ]);

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const Gap(6),
        Text(label,
            style:
                const TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
      ]);
}
