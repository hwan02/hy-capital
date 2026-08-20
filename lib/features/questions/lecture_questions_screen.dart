import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';

/// 오프라인 경매 강의에서 강사에게 물어볼 질문 목록.
///
/// 내 상황: 부부 / 현재 무주택 / 에어비앤비 운영 주소에 전입신고 / 가용 현금 1,000만원
/// 고민: 빌라 경매를 하면 1주택이 되어 청약·생애최초가 날아가는 것 아닌가.
///       청약을 유지할지, 청약은 놔두고 경매를 갈지.
///       특히 생애최초는 한 번 쓰면 끝인 카드 → 소유 이력만 생겨도 영구 결격일 수 있음.
const _kQuestionColor = Color(0xFFF97316);

class _Q {
  final String text;

  /// 왜 묻는지 · 답변에서 꼭 받아와야 할 것.
  final String? want;

  /// 이번 강의에서 반드시 물어야 하는 핵심 질문.
  final bool core;

  const _Q(this.text, {this.want, this.core = false});
}

class _QSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_Q> items;
  const _QSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });
}

const _situation = [
  '부부 · 현재 세대 전원 무주택',
  '에어비앤비 운영 주소에 전입신고 되어 있음',
  '가용 현금 약 1,000만원',
  '생애최초 특별공급 카드 미사용 (부부 모두 주택 소유 이력 없음)',
  '관심 물건: 빌라(다세대) 경매',
  '걱정: 낙찰 = 1주택 → 청약·생애최초 자격 소멸?',
];

const _sections = <_QSection>[
  _QSection(
    title: '1. 자금 — 1,000만원으로 실제 가능한가',
    subtitle: '가장 먼저 확인할 현실성 체크',
    icon: Icons.payments_rounded,
    color: AppColors.gold,
    items: [
      _Q(
        '현금 1,000만원으로 빌라 경매 낙찰까지 실제로 가능합니까? '
        '입찰보증금 + 잔금 + 취득세·등기비 + 명도비 + 수리비까지 합쳤을 때, '
        '최소 몇 백만/천만원이 있어야 "시작 가능"이라고 보십니까?',
        want: '총 필요자금 = 보증금 + 자기부담 잔금 + 부대비용. 항목별 실제 금액대.',
        core: true,
      ),
      _Q(
        '보증금이 최저매각가의 10%라면, 1,000만원이면 최저가 1억 내외 물건까지 '
        '입찰이 가능하다는 계산인데 맞습니까? 그 가격대 빌라가 실제로 수익이 나는 구간입니까?',
        want: '내 자금으로 접근 가능한 물건 가격대와, 그 구간의 현실적인 수익성.',
      ),
      _Q(
        '경락잔금대출은 무주택자 기준으로 낙찰가의 몇 %까지 나오고 금리는 어느 정도입니까? '
        '빌라(다세대)는 아파트보다 한도가 많이 깎인다고 들었는데 실제 차이가 어느 정도입니까?',
        want: 'LTV 한도 · 금리 · 빌라 감액폭. 이게 자기자본 부담을 결정.',
        core: true,
      ),
      _Q(
        '명도비와 수리비는 보통 얼마를 예비비로 잡아야 합니까? '
        '점유자가 버틸 때 인도명령·강제집행까지 가면 비용과 기간이 어떻게 됩니까?',
        want: '예비비 기준 금액. 이걸 빼놓으면 1,000만원 계획이 무너짐.',
      ),
      _Q(
        '자금이 부족할 때 공동입찰이나 지분 투자는 실무적으로 권하십니까? '
        '초보가 하기에 리스크가 큰 방식입니까?',
      ),
    ],
  ),
  _QSection(
    title: '2. 청약 vs 경매 — 무주택 자격 (핵심)',
    subtitle: '낙찰하면 청약이 정말 날아가는가',
    icon: Icons.confirmation_number_rounded,
    color: _kQuestionColor,
    items: [
      _Q(
        '빌라를 낙찰받으면 청약에서 유주택자가 되는 시점이 정확히 언제입니까? '
        '잔금 납부일입니까, 소유권 이전 등기일입니까?',
        want: '유주택 전환 시점. 청약 넣을 시기와 겹치는지 계산하려면 필요.',
        core: true,
      ),
      _Q(
        '소형·저가주택은 청약에서 무주택으로 인정된다고 들었습니다. '
        '전용 60㎡ 이하 + 공시가격 일정액 이하 조건인데, 현재 기준 금액이 얼마입니까? '
        '(수도권/지방 각각) 그리고 이 예외가 지금도 유효합니까?',
        want: '현행 소형·저가주택 기준 금액. 이게 "청약 살리며 경매" 전략의 핵심.',
        core: true,
      ),
      _Q(
        '소형·저가주택 예외는 민영주택 일반공급 가점제에만 적용되고, '
        '공공분양이나 특별공급(신혼부부 등)에서는 무주택으로 안 봐준다고 알고 있습니다. 맞습니까? '
        '우리 부부가 노리는 청약 유형에 따라 결론이 달라지는 겁니까?',
        want: '내가 노리는 청약 유형에서 예외가 통하는지. 여기서 전략이 갈림.',
        core: true,
      ),
      _Q(
        '그러면 청약을 살리면서 경매를 하려면 "전용 60㎡ 이하 + 공시가격 기준 이하 빌라"만 '
        '골라야 하는 겁니까? 그 조건에 맞으면서 수익이 나는 물건이 실제로 시장에 있습니까?',
        want: '제약을 걸고도 실행 가능한지. 안 된다면 둘 중 하나를 포기해야 함.',
        core: true,
      ),
      _Q(
        '부부 공동명의와 단독명의(한 사람 명의)로 낙찰받는 것이 '
        '청약 무주택 판단에 차이가 있습니까? 세대 기준이니 결국 같은 겁니까?',
        want: '명의 분리로 청약을 지킬 수 있는지 여부. 보통 세대 기준이라 안 될 것 같은데 확인.',
      ),
      _Q(
        '유주택이 되어도 청약통장은 계속 유지·납입할 수 있습니까? '
        '나중에 매도해서 다시 무주택이 되면 무주택 기간 가점은 어떻게 계산됩니까? '
        '(처분 시점부터 다시 쌓는 건지, 그동안 쌓인 게 사라지는 건지)',
        want: '경매를 하더라도 청약을 완전히 버리는 게 아닌지. 복구 가능성.',
        core: true,
      ),
      _Q(
        '냉정하게, 저희 부부 조건(무주택 · 청약통장 보유 · 가점 낮음)에서 '
        '청약 당첨 기대값과 경매 실행 기대값을 어떤 기준으로 비교해야 합니까? '
        '"청약은 사실상 포기하고 경매로 가라"는 판단은 어떤 조건일 때 내리십니까?',
        want: '판단 기준 자체. 강사의 실제 의사결정 프레임을 받아오기.',
        core: true,
      ),
    ],
  ),
  _QSection(
    title: '3. 생애최초 — 한 번 쓰면 끝인 카드',
    subtitle: '가점보다 이게 더 아까울 수 있다',
    icon: Icons.card_giftcard_rounded,
    color: AppColors.rose,
    items: [
      _Q(
        '생애최초 특별공급은 본인과 배우자 모두 "과거에 주택을 소유한 사실이 없어야" 하는 '
        '요건으로 알고 있습니다. 그러면 빌라를 낙찰받는 순간 — 나중에 팔아서 다시 무주택이 되어도 — '
        '생애최초 자격은 영구히 사라지는 겁니까?',
        want: '소유 이력 자체가 결격이면 되돌릴 방법이 없다. 이게 사실이면 비용이 가장 큼.',
        core: true,
      ),
      _Q(
        '앞에서 말한 소형·저가주택 예외(60㎡ 이하 + 공시가격 이하)는 '
        '생애최초 특별공급에는 적용되지 않는 게 맞습니까? '
        '즉 "청약 가점은 살릴 수 있어도 생애최초는 못 살린다"가 결론입니까?',
        want: '예외의 적용 범위. 여기가 ⓑ 전략(청약 살리며 경매)의 최대 구멍.',
        core: true,
      ),
      _Q(
        '신혼부부 특별공급도 같이 날아갑니까? '
        '생애최초와 신혼부부 특공의 주택 소유 요건이 서로 다릅니까?',
        want: '남는 특공 카드가 하나라도 있는지 확인.',
        core: true,
      ),
      _Q(
        '낙찰을 배우자 단독명의로 하면 나머지 한 사람의 생애최초 자격은 남습니까? '
        '아니면 부부 합산·세대 기준이라 둘 다 같이 날아가는 겁니까?',
        want: '명의 분리로 카드 한 장을 지킬 수 있는지. 부부 합산이면 불가.',
        core: true,
      ),
      _Q(
        '생애최초 취득세 감면(최대 200만원)도 경매 낙찰에 적용됩니까? '
        '적용된다면 그 감면을 이번 빌라에 써버리면 나중에 아파트를 살 때는 못 쓰는 겁니까? '
        '소득·주택가격 요건이 어떻게 됩니까?',
        want: '취득세 감면을 여기 쓸지 아낄지. 부대비용 계산에도 영향.',
      ),
      _Q(
        '냉정하게 여쭙습니다. 생애최초 특공 카드 한 장과 경매 빌라 한 채를 '
        '맞바꾸는 게 맞는 거래입니까? 저희 조건에서 생애최초 특공 당첨 현실성을 '
        '어느 정도로 보십니까? (지역·소득·경쟁률 기준으로)',
        want: '포기하는 것의 실제 기대값. 이 답으로 ⓐ/ⓒ가 갈린다.',
        core: true,
      ),
      _Q(
        '만약 생애최초를 지키기로 한다면, 주택을 취득하지 않고 경매로 할 수 있는 게 있습니까? '
        '(토지·상가·오피스텔 등 주택 수에 안 들어가는 물건으로 시작하는 방법)',
        want: '생애최초를 지키면서 경매 경험을 쌓는 우회로. 실행 가능하면 이게 답일 수 있음.',
        core: true,
      ),
    ],
  ),
  _QSection(
    title: '4. 에어비앤비 · 전입신고 · 세금',
    subtitle: '현재 운영 상태가 낙찰에 영향을 주는지',
    icon: Icons.house_rounded,
    color: AppColors.sky,
    items: [
      _Q(
        '현재 에어비앤비 운영 주소에 전입신고가 되어 있습니다. '
        '이 상태가 낙찰·대출·세금(취득세 중과, 1세대 판단)에서 문제가 됩니까?',
        want: '지금 전입 상태를 그대로 둬도 되는지, 정리해야 하는지.',
        core: true,
      ),
      _Q(
        '무주택 세대라도 낙찰 시 취득세는 어떻게 계산됩니까? '
        '빌라 1채 취득이면 기본세율인지, 중과 대상이 되는 경우가 있습니까?',
        want: '취득세 실제 금액. 부대비용 계산에 직결.',
      ),
      _Q(
        '낙찰받은 빌라에 실거주 전입을 하는 것이 대출·세금 면에서 유리한 게 있습니까? '
        '아니면 전입 없이 바로 임대를 돌리는 게 낫습니까?',
      ),
      _Q(
        '에어비앤비를 계속 운영하면서 낙찰받은 빌라를 임대(또는 숙박)로 돌릴 때 '
        '주의할 점이 있습니까? 사업자 등록이나 신고 문제가 걸립니까?',
      ),
      _Q(
        '낙찰 후 단기 매도 시 양도세 중과(보유 1년 미만 등)를 감안하면, '
        '최소 보유 기간을 얼마로 잡고 출구 전략을 짜야 합니까?',
        want: '보유 기간 설계. 단기 차익 계획이면 세금에 다 먹힘.',
      ),
    ],
  ),
  _QSection(
    title: '5. 결론 — 어떤 순서로 실행할까',
    subtitle: '강의 끝나기 전에 방향을 받아오기',
    icon: Icons.route_rounded,
    color: AppColors.primary,
    items: [
      _Q(
        '저희 상황(부부·무주택·현금 1,000만원·에어비앤비 운영)에서 다음 네 가지 중 어느 쪽입니까?\n'
        'ⓐ 청약·생애최초 지키고, 경매는 자금 더 모을 때까지 보류\n'
        'ⓑ 주택 아닌 물건(토지·상가 등)으로 경매 시작 — 생애최초 보존\n'
        'ⓒ 소형·저가주택 빌라로 경매 (청약 가점만 살리고 생애최초는 포기)\n'
        'ⓓ 청약·생애최초 다 포기하고 경매에 집중\n'
        '그리고 그 판단의 근거는 무엇입니까?',
        want: '이 강의에서 반드시 받아올 한 문장. 선택지 ⓐⓑⓒⓓ로 답을 유도.',
        core: true,
      ),
      _Q(
        '첫 경매는 어떤 물건으로 시작하는 게 좋습니까? '
        '권리관계가 깨끗한 물건만 보는 게 맞습니까, 아니면 처음부터 명도까지 경험하는 게 낫습니까?',
      ),
      _Q(
        '1,000만원으로 지금 입찰을 시작하는 게 맞습니까, '
        '아니면 얼마까지 모아서 시작하라고 조언하시겠습니까?',
        core: true,
      ),
      _Q(
        '빌라 중에서 절대 피해야 할 유형을 꼽아주신다면 무엇입니까? '
        '(반지하, 근저당 과다, 대항력 있는 임차인, 미납관리비 큰 물건 등)',
        want: '제외 기준 리스트 → 물건 검색 필터로 그대로 쓰기.',
      ),
      _Q(
        '지금 시점에 제 자금대로 접근할 만한 지역이 있습니까? '
        '수도권에서 가능한 구간이 있습니까, 지방으로 가야 합니까?',
      ),
      _Q(
        '강의 이후에 혼자 연습할 때, 입찰 전 조사에서 초보가 가장 많이 놓치는 항목은 무엇입니까?',
      ),
    ],
  ),
];

int get _totalCount =>
    _sections.fold<int>(0, (sum, s) => sum + s.items.length);

String _asPlainText() {
  final b = StringBuffer();
  b.writeln('[경매 강의 질문]');
  b.writeln();
  b.writeln('내 상황');
  for (final s in _situation) {
    b.writeln('- $s');
  }
  for (final s in _sections) {
    b.writeln();
    b.writeln(s.title);
    for (var i = 0; i < s.items.length; i++) {
      b.writeln('${i + 1}) ${s.items[i].text.replaceAll('\n', ' ')}');
    }
  }
  return b.toString();
}

class LectureQuestionsScreen extends StatefulWidget {
  const LectureQuestionsScreen({super.key});

  @override
  State<LectureQuestionsScreen> createState() =>
      _LectureQuestionsScreenState();
}

class _LectureQuestionsScreenState extends State<LectureQuestionsScreen> {
  /// 물어본 질문 표시 (강의 중 체크용).
  final Set<String> _asked = {};

  /// 핵심 질문만 보기.
  bool _coreOnly = false;

  void _toggle(String key) => setState(() {
        if (!_asked.remove(key)) _asked.add(key);
      });

  @override
  Widget build(BuildContext context) {
    final total = _totalCount;
    return ModulePage(
      title: '강의 질문',
      subtitle: '오프라인 경매 강의 · 물어본 것 $_askedCount/$total',
      icon: Icons.live_help_rounded,
      color: _kQuestionColor,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '전체 복사',
            icon: const Icon(Icons.copy_all_rounded, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _asPlainText()));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('질문 전체를 복사했어요')),
              );
            },
          ),
          IconButton(
            tooltip: _coreOnly ? '전체 질문 보기' : '핵심만 보기',
            icon: Icon(
              _coreOnly ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: _coreOnly ? _kQuestionColor : AppColors.textFaint,
            ),
            onPressed: () => setState(() => _coreOnly = !_coreOnly),
          ),
        ],
      ),
      children: [
        _ProgressCard(asked: _askedCount, total: total),
        const Gap(Insets.gap),
        const _SituationCard(),
        const Gap(Insets.gap),
        for (var si = 0; si < _sections.length; si++) ...[
          _SectionCard(
            section: _sections[si],
            sectionIndex: si,
            coreOnly: _coreOnly,
            asked: _asked,
            onToggle: _toggle,
          ),
          const Gap(Insets.gap),
        ],
        const _ClosingCard(),
      ],
    );
  }

  int get _askedCount => _asked.length;
}

class _ProgressCard extends StatelessWidget {
  final int asked;
  final int total;
  const _ProgressCard({required this.asked, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : asked / total;
    return GlassCard(
      accent: _kQuestionColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '강의 중 물어본 질문을 눌러서 체크',
                  style: TextStyle(
                    fontSize: AppFont.section,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$asked / $total',
                style: const TextStyle(
                  fontSize: AppFont.display,
                  fontWeight: FontWeight.w800,
                  color: _kQuestionColor,
                ),
              ),
            ],
          ),
          const Gap(12),
          ProgressBar(value: ratio, color: _kQuestionColor),
          const Gap(8),
          const Text(
            '★ 표시는 이 강의에서 답을 꼭 받아와야 하는 핵심 질문',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFont.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationCard extends StatelessWidget {
  const _SituationCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            '내 상황 (질문 전에 먼저 말할 것)',
            subtitle: '강사가 조건을 알아야 답이 구체적으로 나온다',
          ),
          const Gap(14),
          for (final s in _situation)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle,
                        size: 5, color: AppColors.textFaint),
                  ),
                  const Gap(9),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: AppFont.body,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _QSection section;
  final int sectionIndex;
  final bool coreOnly;
  final Set<String> asked;
  final void Function(String key) onToggle;

  const _SectionCard({
    required this.section,
    required this.sectionIndex,
    required this.coreOnly,
    required this.asked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < section.items.length; i++)
        if (!coreOnly || section.items[i].core) (i, section.items[i]),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      accent: section.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(section.icon, size: 18, color: section.color),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: AppFont.section,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      section.subtitle,
                      style: const TextStyle(
                        fontSize: AppFont.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(6),
          for (final (i, q) in items)
            _QuestionRow(
              number: i + 1,
              q: q,
              color: section.color,
              done: asked.contains('$sectionIndex-$i'),
              onTap: () => onToggle('$sectionIndex-$i'),
            ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  final int number;
  final _Q q;
  final Color color;
  final bool done;
  final VoidCallback onTap;

  const _QuestionRow({
    required this.number,
    required this.q,
    required this.color,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 번호 배지 = 물어봤는지 체크 토글.
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 24,
              width: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color:
                    done ? color.withValues(alpha: 0.22) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: done ? color : AppColors.border),
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 15, color: color)
                  : Center(
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          fontSize: AppFont.micro,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (q.core)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Pill('핵심', color: _kQuestionColor),
                    ),
                  ),
                Text(
                  q.text,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    height: 1.5,
                    color: done ? AppColors.textFaint : AppColors.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textFaint,
                  ),
                ),
                if (q.want != null) ...[
                  const Gap(6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flag_rounded,
                            size: 13, color: AppColors.textFaint),
                        const Gap(7),
                        Expanded(
                          child: Text(
                            q.want!,
                            style: const TextStyle(
                              fontSize: AppFont.caption,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            '질문할 때 요령',
            subtitle: '시간이 짧으면 이 순서로',
          ),
          const Gap(12),
          for (final t in const [
            '① 「2번 청약」과 「3번 생애최초」부터 묻기. 여기 답이 나머지 전부를 결정한다.',
            '①-b 특히 3번. 가점은 다시 쌓을 수 있어도 생애최초는 한 번 쓰면 끝일 수 있다.',
            '② 내 상황을 15초 안에 요약해서 먼저 말하기 (무주택 부부 / 현금 1,000만 / 에어비앤비 전입).',
            '③ 「ⓐⓑⓒⓓ 중 어느 쪽입니까」처럼 선택지를 주고 물으면 두루뭉술한 답이 안 나온다.',
            '④ 질문에 적힌 숫자·기준(60㎡, 공시가격 한도 등)은 내 기억이므로 "이 기준이 맞습니까"로 확인받기.',
            '⑤ 답을 들으면 바로 이 화면 번호를 눌러 체크하고, 숫자는 메모에 남기기.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: AppFont.body,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
