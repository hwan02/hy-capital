import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// 재개발 절차 — 초기 → 중기 → 후기 단계별 흐름과 각 단계 핵심.
/// (교과서적 고정 절차라 하드코딩. 세제 타임라인처럼 자주 바뀌는 데이터가 아님)
const _teal = Color(0xFF14B8A6);

class _Stage {
  final String title;
  final String note;
  final bool star; // 특히 중요한 단계 강조
  const _Stage(this.title, this.note, {this.star = false});
}

class _Phase {
  final String name;
  final String sub;
  final Color color;
  final List<_Stage> stages;
  const _Phase(this.name, this.sub, this.color, this.stages);
}

const _phases = <_Phase>[
  _Phase('초기', '구역이 만들어지는 단계 · 불확실성 큼', AppColors.sky, [
    _Stage('기본계획 수립',
        '시·도가 10년 단위로 세우는 도시·주거환경정비 기본계획. 어디를 정비할지 큰 그림.'),
    _Stage('정비계획 수립',
        '구역 범위·용도지역·용적률·건폐율·기반시설을 구체화. 사업의 밑그림이 잡힌다.'),
    _Stage('정비구역 지정',
        '법적으로 정비구역이 지정되는 공식 출발점. 이때부터 토지거래허가·투기과열 등 규제와 프리미엄이 붙기 시작.'),
    _Stage('추진위원회 승인',
        '토지등소유자 과반 동의로 추진위 구성 승인. 조합설립을 준비하는 전 단계.'),
  ]),
  _Phase('중기', '조합·인가로 사업이 확정되는 단계', AppColors.gold, [
    _Stage('조합설립 인가',
        '토지등소유자 동의(재개발 기존 75%→8·13대책 70%, 면적 1/2↑)로 조합 설립. 이때 조합원 자격이 확정된다.'),
    _Stage('시공사 선정', '건설사(브랜드)·공사비 윤곽이 나온다. 사업이 눈에 보이기 시작.'),
    _Stage('사업시행 인가',
        '설계·분양계획 등 사업내용을 관할청이 인가 = 사업 확정. 종전자산 감정평가가 진행되고, 리스크가 크게 줄어드는 분기점.'),
    _Stage('분양공고 · 분양신청',
        '조합원이 새 아파트 분양을 신청. ★ 신청 안 하거나 포기하면 «현금청산» 대상 — 감정가로 현금만 받고 사업에서 빠진다(입주권 상실).',
        star: true),
  ]),
  _Phase('후기', '권리가 확정되고 실물이 되는 단계', _teal, [
    _Stage('관리처분 인가',
        '★ 종전 주택의 권리가액이 확정되고, «주택»이 «입주권»(새 아파트를 받을 권리)으로 바뀐다. 분담금·이주비 규모도 이때 확정. 이후 거래는 입주권 거래.',
        star: true),
    _Stage('이주 · 철거 및 착공',
        '★ 조합원·세입자가 이주 → 철거 → 착공. 집주인이 나갈 돈이 없으면 «이주비 대출»(보통 무이자·저리), 분담금 낼 돈은 «분담금 대출»로 조달. 세입자에겐 주거이전비·이사비 보상.',
        star: true),
    _Stage('준공 · 입주', '공사 완료·사용승인 후 입주. 입주권이 실제 아파트(소유권)로 실현된다.'),
    _Stage('조합 청산 · 해산', '정산을 마치고 조합을 해산. 사업 종료.'),
  ]),
];

class RedevelopmentFlow extends StatelessWidget {
  const RedevelopmentFlow({super.key});

  @override
  Widget build(BuildContext context) {
    var n = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('재개발 절차',
            style:
                TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        const Text('초기 → 중기 → 후기. 단계가 오를수록 불확실성↓·가격(프리미엄)↑',
            style:
                TextStyle(fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(16),
        _terms(),
        const Gap(18),
        for (final p in _phases) ...[
          _phaseHeader(p),
          const Gap(10),
          for (final s in p.stages) _stageRow(++n, s, p.color),
          const Gap(16),
        ],
        const Text(
          '※ 동의율·기간 등 세부 요건은 지자체·대책(예: 8·13)에 따라 바뀔 수 있어요. 구역별 현재 단계는 «진행» 탭에서 관리.',
          style: TextStyle(
              fontSize: AppFont.caption, color: AppColors.textFaint, height: 1.5),
        ),
      ],
    );
  }

  Widget _terms() => GlassCard(
        accent: AppColors.gold,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(children: [
              Icon(Icons.key_rounded, size: 18, color: AppColors.gold),
              Gap(7),
              Text('핵심 용어',
                  style: TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            ]),
            Gap(10),
            _Term('분담금',
                '새 아파트 조합원분양가 − 내 종전자산 권리가액. 내가 추가로 내야 하는 돈. (권리가액 > 분양가면 오히려 환급)'),
            _Term('입주권',
                '관리처분 인가 후 조합원이 갖는 «새 아파트를 받을 권리». 이때부터 주택이 아니라 입주권으로 거래된다.'),
            _Term('현금청산', '분양신청을 안 하거나 자격이 안 되면 감정가로 현금만 받고 사업에서 제외 — 입주권을 못 받는다.'),
            _Term('이주비 대출', '이주 단계에서 집주인이 나갈 자금이 없을 때 조합·은행이 지원(보통 무이자·저리).'),
            _Term('분담금 대출', '분담금을 낼 현금이 없을 때 받는 대출. 이주비와 별개.'),
          ],
        ),
      );

  Widget _phaseHeader(_Phase p) => Row(
        children: [
          Pill(p.name, color: p.color),
          const Gap(8),
          Expanded(
            child: Text(p.sub,
                style: const TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
          ),
        ],
      );

  Widget _stageRow(int n, _Stage s, Color c) {
    final accent = s.star ? AppColors.gold : c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        accent: s.star ? AppColors.gold : null,
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.4),
              ),
              child: Text('$n',
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      fontWeight: FontWeight.w800,
                      color: accent)),
            ),
            const Gap(11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(s.title,
                          style: const TextStyle(
                              fontSize: AppFont.section,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (s.star) ...[
                      const Gap(6),
                      const Pill('중요', color: AppColors.gold),
                    ],
                  ]),
                  const Gap(3),
                  Text(s.note,
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          color: AppColors.textSecondary,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Term extends StatelessWidget {
  final String term;
  final String desc;
  const _Term(this.term, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term,
              style: const TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold)),
          const Gap(2),
          Text(desc,
              style: const TextStyle(
                  fontSize: AppFont.body,
                  color: AppColors.textSecondary,
                  height: 1.5)),
        ],
      ),
    );
  }
}
