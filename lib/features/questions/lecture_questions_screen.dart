import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

/// 오프라인 경매 강의에서 강사에게 물어볼 질문 목록.
///
/// 내 상황: 부부 / 현재 무주택 / 에어비앤비 운영 주소에 전입신고 / 가용 현금 1,000만원
/// 고민: 빌라 경매를 하면 1주택이 되어 청약·생애최초가 날아가는 것 아닌가.
///       청약을 유지할지, 청약은 놔두고 경매를 갈지.
///       특히 생애최초는 한 번 쓰면 끝인 카드 → 소유 이력만 생겨도 영구 결격일 수 있음.
const _kQuestionColor = Color(0xFFF97316);
final _urlRe = RegExp(r'https?://\S+');

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
  final int week; // 1주차 / 2주차
  const _QSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
    this.week = 1,
  });
}

const _situation = [
  '무주택 신혼부부 · 세대 전원 무주택',
  '가용 자금 약 8,100만원',
  '생애최초 특별공급 «가능» (부부 모두 소유 이력 없음, 미사용)',
  '에어비앤비 운영 주소에 전입신고 되어 있음',
  '전략: 모아·신통 빌라 경매/매매 (법인 공시가1억↓ 단타·플피)',
];

const _sections = <_QSection>[
  _QSection(
    title: '1. 자금 — 8,100만으로 가능한가',
    subtitle: '현실성 체크',
    icon: Icons.payments_rounded,
    color: AppColors.gold,
    items: [
      _Q('현금 8,100만으로 낙찰까지 실제 가능한가요? 보증금·잔금·취득세·명도·수리 다 합치면 최소 얼마가 필요한가요?',
          want: '총 필요자금 항목별 금액', core: true),
      _Q('제 자금으로 접근할 수 있는 물건 가격대는 어디까지고, 그 구간이 수익이 나나요?',
          want: '접근 가격대·수익성'),
      _Q('경락잔금대출은 무주택 기준 LTV·금리가 어떻게 되나요? 빌라는 아파트보다 얼마나 깎이나요?',
          want: 'LTV·금리·빌라 감액', core: true),
      _Q('명도비·수리비 예비비는 얼마나 잡아야 하나요? 강제집행까지 가면 비용·기간은요?',
          want: '예비비 기준'),
      _Q('공동입찰이나 지분투자, 초보한테 권하시나요?'),
    ],
  ),
  _QSection(
    title: '2. 청약 vs 경매 — 무주택 자격 (핵심)',
    subtitle: '낙찰하면 청약이 정말 날아가는가',
    icon: Icons.confirmation_number_rounded,
    color: _kQuestionColor,
    items: [
      _Q('낙찰받으면 청약에서 유주택자가 되는 시점이 언제인가요? 잔금 납부일인가요, 소유권 이전 등기일인가요?',
          core: true),
      _Q('소형·저가주택은 청약에서 무주택으로 인정되죠? 전용 60㎡ 이하 + 공시가격 기준, 지금 금액이 얼마인가요? (수도권/지방)',
          core: true),
      _Q('그 예외가 특별공급(신혼·공공)에서도 무주택으로 인정되나요, 아니면 민영 가점제만인가요?',
          core: true),
      _Q('청약 살리면서 경매하려면 60㎡ 이하 + 공시가 이하 빌라만 골라야 하나요? 그런 물건이 수익이 나나요?',
          core: true),
      _Q('공동명의와 단독명의가 청약 무주택 판단에 차이가 있나요? 세대 기준이라 결국 같은가요?'),
      _Q('유주택이 돼도 청약통장은 유지되나요? 나중에 팔아 무주택이 되면 무주택 기간 가점은 어떻게 계산되나요?',
          core: true),
      _Q('저희 조건(무주택·가점 낮음)에서 청약과 경매 중 어느 쪽이 유리한지 판단 기준이 뭔가요? 청약을 접고 경매로 가라는 건 어떤 경우인가요?',
          core: true),
    ],
  ),
  _QSection(
    title: '3. 생애최초 — 한 번 쓰면 끝인 카드',
    subtitle: '가점보다 이게 더 아까울 수 있다',
    icon: Icons.card_giftcard_rounded,
    color: AppColors.rose,
    items: [
      _Q('빌라를 낙찰받으면, 나중에 팔아 무주택이 돼도 생애최초 자격은 영구히 사라지나요?',
          core: true),
      _Q('소형·저가주택 예외는 생애최초 특공엔 적용 안 되나요? 가점은 살려도 생애최초는 못 살리는 게 결론인가요?',
          core: true),
      _Q('신혼부부 특공도 같이 날아가나요? 생애최초와 소유 요건이 다른가요?', core: true),
      _Q('배우자 단독명의로 낙찰하면 나머지 한 명의 생애최초는 남나요, 세대 합산인가요?',
          core: true),
      _Q('생애최초 취득세 감면(200만)도 경매에 적용되나요? 여기 쓰면 나중 아파트엔 못 쓰나요?'),
      _Q('생애최초 특공 한 장과 경매 빌라 한 채, 바꿀 만한가요? 저희 당첨 현실성은 어느 정도로 보시나요?',
          core: true),
      _Q('생애최초를 지키려면 주택 아닌 물건(토지·상가·오피스텔)으로 시작하는 방법이 있나요?',
          core: true),
    ],
  ),
  _QSection(
    title: '4. 에어비앤비 · 전입신고 · 세금',
    subtitle: '현재 운영 상태가 낙찰에 영향을 주는지',
    icon: Icons.house_rounded,
    color: AppColors.sky,
    items: [
      _Q('에어비앤비 주소에 전입신고가 돼 있는데, 이게 낙찰·대출·세금(취득세 중과·1세대 판단)에 문제가 되나요?',
          core: true),
      _Q('무주택 세대가 낙찰하면 취득세는 어떻게 되나요? 빌라 1채면 기본세율인가요, 중과되나요?'),
      _Q('낙찰 빌라에 실거주 전입하는 게 대출·세금에 유리한가요, 아니면 바로 임대가 나은가요?'),
      _Q('에어비앤비 운영하면서 낙찰 빌라를 임대·숙박으로 돌릴 때 사업자·신고 문제가 있나요?'),
      _Q('단기 매도하면 양도세 중과(1년 미만 등)를 감안해 최소 보유기간을 얼마로 잡아야 하나요?'),
    ],
  ),
  _QSection(
    title: '5. 결론 — 어떤 순서로 실행할까',
    subtitle: '강의 끝나기 전에 방향을 받아오기',
    icon: Icons.route_rounded,
    color: AppColors.primary,
    items: [
      _Q(
        '저희 상황(무주택 신혼부부·자금 8,100·에어비앤비)에서 어느 쪽인가요?\n'
        'ⓐ 청약·생애최초 지키고 경매는 보류\n'
        'ⓑ 주택 아닌 물건으로 시작해 생애최초 보존\n'
        'ⓒ 소형·저가 빌라로 (가점만 살리고 생애최초 포기)\n'
        'ⓓ 다 포기하고 경매 집중\n'
        '그리고 그 근거는요?',
        core: true,
      ),
      _Q('첫 경매는 권리 깨끗한 물건만 보는 게 맞나요, 아니면 명도까지 경험하는 게 나은가요?'),
      _Q('지금 8,100으로 시작해도 되나요, 아니면 얼마까지 모으는 게 좋을까요?', core: true),
      _Q('절대 피해야 할 빌라 유형은요? (반지하·근저당 과다·대항력 임차인·미납관리비 큰 물건 등)'),
      _Q('지금 제 자금으로 접근할 만한 지역이 있나요? 수도권에서 가능한가요, 지방으로 가야 하나요?'),
      _Q('혼자 연습할 때 입찰 전 조사에서 초보가 가장 많이 놓치는 게 뭔가요?'),
    ],
  ),
  // ── 2주차 ─────────────────────────────────────────────
  _QSection(
    title: '모아타운 조합원 승계 · 현금청산',
    subtitle: '조합설립된 물건 경매로 사도 되나',
    icon: Icons.groups_rounded,
    color: Color(0xFFEF4444),
    week: 2,
    items: [
      _Q(
        '조합설립된 모아타운 물건을 경매로 낙찰받으면 조합원 승계가 되나요, 현금청산 대상인가요? 현금청산이면 매매가 나은지, 조합설립 전후로 갈리는지. 그리고 주택도시보증공사(HUG)가 신청채권자인 물건(포르테하임2)도 제가 낙찰받아도 되나요?\n'
        'https://www.hauction.co.kr/search/auction/1600821',
        core: true,
      ),
    ],
  ),
];

String _asPlainText([Map<String, LectureAnswer> recs = const {}]) {
  final b = StringBuffer();
  b.writeln('[경매 강의 질문]');
  b.writeln();
  b.writeln('내 상황');
  for (final s in _situation) {
    b.writeln('- $s');
  }
  for (var si = 0; si < _sections.length; si++) {
    final s = _sections[si];
    b.writeln();
    b.writeln(s.title);
    for (var i = 0; i < s.items.length; i++) {
      final rec = recs['$si-$i'];
      final mark = (rec?.asked ?? false) ? '[v]' : '[ ]';
      b.writeln('$mark ${i + 1}) ${s.items[i].text.replaceAll('\n', ' ')}');
      if (rec != null && rec.hasAnswer) {
        for (final line in rec.answer.trim().split('\n')) {
          b.writeln('    → ${line.trim()}');
        }
      }
    }
  }
  return b.toString();
}

/// 강의 질문 본문 — 경매 화면의 '강의 질문' 탭에서 그대로 재사용한다.
/// 복사·핵심만보기 버튼은 자체 툴바로 들고 있어 어디에 끼워도 동작한다.
class LectureQuestionsView extends ConsumerStatefulWidget {
  const LectureQuestionsView({super.key});

  @override
  ConsumerState<LectureQuestionsView> createState() =>
      _LectureQuestionsViewState();
}

class _LectureQuestionsViewState extends ConsumerState<LectureQuestionsView> {
  /// 핵심 질문만 보기.
  bool _coreOnly = false;

  /// 답 적은 것만 보기.
  bool _answeredOnly = false;

  /// 주차 필터. 0 = 전체, 1 = 1주차, 2 = 2주차.
  int _week = 0;

  /// 물어봤는지 토글 — 바로 저장한다(강의장에서 잃어버리면 안 됨).
  Future<void> _toggleAsked(String qkey, String question, bool now) =>
      _save(qkey, question, {'asked': !now});

  Future<void> _save(
      String qkey, String question, Map<String, dynamic> patch) async {
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('lecture_answers').upsert({
        'user_id': uid,
        'qkey': qkey,
        'question': question,
        ...patch,
      }, onConflict: 'user_id,qkey');
      ref.invalidate(lectureAnswersProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
    }
  }

  /// 답 적기 시트 — 강의장에서 폰으로 쓰므로 큰 입력창 + 저장 버튼.
  Future<void> _editAnswer(
      String qkey, String question, String current) async {
    final c = TextEditingController(text: current);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(question,
                style: const TextStyle(
                    fontSize: AppFont.body, fontWeight: FontWeight.w700)),
            const Gap(12),
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 8,
              minLines: 4,
              style: const TextStyle(fontSize: AppFont.body, height: 1.5),
              decoration: const InputDecoration(),
            ),
            const Gap(12),
            Row(children: [
              if (current.trim().isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('답 지우기',
                      style: TextStyle(color: AppColors.rose)),
                ),
              const Spacer(),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소')),
              const Gap(8),
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: _kQuestionColor),
                onPressed: () => Navigator.pop(ctx, c.text),
                icon: const Icon(Icons.save_rounded, size: 17),
                label: const Text('저장'),
              ),
            ]),
          ],
        ),
      ),
    );
    if (saved == null) return;
    // 답을 적으면 '물어봤음'도 자동으로 켠다.
    await _save(qkey, question,
        {'answer': saved, if (saved.trim().isNotEmpty) 'asked': true});
  }

  /// 내 질문 추가 — 새 테이블 없이 lecture_answers.question 을 쓴다.
  /// qkey 가 'custom-' 으로 시작하면 사용자가 추가한 질문이다.
  Future<void> _addCustom() async {
    final c = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('질문 추가',
                style: TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            const Gap(12),
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(fontSize: AppFont.body, height: 1.5),
              decoration: const InputDecoration(
                  hintText: '강사에게 물어볼 질문을 적으세요.'),
            ),
            const Gap(12),
            Row(children: [
              const Spacer(),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소')),
              const Gap(8),
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: _kQuestionColor),
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('추가'),
              ),
            ]),
          ],
        ),
      ),
    );
    if (text == null || text.isEmpty) return;
    await _save('custom-${DateTime.now().microsecondsSinceEpoch}', text, {});
  }

  Future<void> _deleteCustom(String qkey, String question) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('질문 삭제',
            style: TextStyle(fontSize: AppFont.section)),
        content: Text(question, style: const TextStyle(fontSize: AppFont.body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sb = ref.read(supabaseProvider);
    try {
      await sb.from('lecture_answers').delete().eq('qkey', qkey);
      ref.invalidate(lectureAnswersProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('삭제 실패: $e'), backgroundColor: AppColors.rose));
    }
  }

  Widget _weekChips() {
    Widget chip(int v, String label) {
      final on = _week == v;
      return InkWell(
        onTap: () => setState(() => _week = v),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on
                ? _kQuestionColor.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
                color: on ? _kQuestionColor : AppColors.border,
                width: on ? 1.4 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? _kQuestionColor : AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: [
      chip(0, '전체'),
      chip(1, '1주차'),
      chip(2, '2주차'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lectureAnswersProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (recs) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  tooltip: '질문+답 전체 복사',
                  icon: const Icon(Icons.copy_all_rounded, size: 20),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                        ClipboardData(text: _asPlainText(recs)));
                    messenger.showSnackBar(const SnackBar(
                        content: Text('질문과 답을 복사했어요')));
                  },
                ),
                IconButton(
                  tooltip: _answeredOnly ? '전체 보기' : '답 적은 것만',
                  icon: Icon(
                    _answeredOnly
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 19,
                    color: _answeredOnly
                        ? AppColors.primary
                        : AppColors.textFaint,
                  ),
                  onPressed: () =>
                      setState(() => _answeredOnly = !_answeredOnly),
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
            const Gap(6),
            const _SituationCard(),
            const Gap(Insets.gap),
            _weekChips(),
            const Gap(Insets.gap),
            for (var si = 0; si < _sections.length; si++)
              if (_week == 0 || _sections[si].week == _week) ...[
                _SectionCard(
                  section: _sections[si],
                  sectionIndex: si,
                  coreOnly: _coreOnly,
                  answeredOnly: _answeredOnly,
                  recs: recs,
                  onToggle: _toggleAsked,
                  onEditAnswer: _editAnswer,
                ),
                const Gap(Insets.gap),
              ],
            if (_week != 1) ...[
              _CustomSection(
                recs: recs,
                answeredOnly: _answeredOnly,
                onAdd: _addCustom,
                onToggle: _toggleAsked,
                onEditAnswer: _editAnswer,
                onDelete: _deleteCustom,
              ),
              const Gap(Insets.gap),
            ],
          ],
        );
      },
    );
  }
}

/// 강의 질문 단독 페이지 (직접 URL 접근용). 사이드 메뉴에는 노출하지 않고
/// 경매 화면의 '강의 질문' 탭으로 접근한다.
class LectureQuestionsScreen extends StatelessWidget {
  const LectureQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePage(
        title: '강의 질문',
        subtitle: '오프라인 경매 강의에서 물어볼 것',
        icon: Icons.live_help_rounded,
        color: _kQuestionColor,
        children: [LectureQuestionsView()],
      );
}

class _SituationCard extends StatelessWidget {
  const _SituationCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('내 상황 (질문 전에 먼저 말할 것)'),
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
  final bool answeredOnly;
  final Map<String, LectureAnswer> recs;
  final Future<void> Function(String qkey, String question, bool now) onToggle;
  final Future<void> Function(String qkey, String question, String current)
      onEditAnswer;

  const _SectionCard({
    required this.section,
    required this.sectionIndex,
    required this.coreOnly,
    required this.answeredOnly,
    required this.recs,
    required this.onToggle,
    required this.onEditAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < section.items.length; i++)
        if ((!coreOnly || section.items[i].core) &&
            (!answeredOnly || (recs['$sectionIndex-$i']?.hasAnswer ?? false)))
          (i, section.items[i]),
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
              text: q.text,
              want: q.want,
              core: q.core,
              color: section.color,
              rec: recs['$sectionIndex-$i'],
              onToggle: () => onToggle('$sectionIndex-$i', q.text,
                  recs['$sectionIndex-$i']?.asked ?? false),
              onEditAnswer: () => onEditAnswer('$sectionIndex-$i', q.text,
                  recs['$sectionIndex-$i']?.answer ?? ''),
            ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  final int number;
  final String text;
  final String? want;
  final bool core;
  final Color color;
  final LectureAnswer? rec;
  final VoidCallback onToggle;
  final VoidCallback onEditAnswer;

  /// 사용자가 추가한 질문이면 삭제를 허용한다.
  final VoidCallback? onDelete;

  const _QuestionRow({
    required this.number,
    required this.text,
    this.want,
    this.core = false,
    required this.color,
    required this.rec,
    required this.onToggle,
    required this.onEditAnswer,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = rec?.asked ?? false;
    final answer = rec?.answer.trim() ?? '';
    final hasAnswer = answer.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 번호 배지 = 물어봤는지 체크 토글.
          GestureDetector(
            onTap: onToggle,
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
                Row(children: [
                  if (core)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5, right: 6),
                      child: Pill('핵심', color: _kQuestionColor),
                    ),
                  if (hasAnswer)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Pill('답 있음', color: AppColors.primary),
                    ),
                  const Spacer(),
                  if (onDelete != null)
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded,
                            size: 15, color: AppColors.textFaint),
                      ),
                    ),
                ]),
                // 질문을 누르면 답 적기. URL이 있으면 새 창으로 여는 버튼.
                Builder(builder: (_) {
                  final m = _urlRe.firstMatch(text);
                  final url = m?.group(0);
                  final qText =
                      url == null ? text : text.replaceFirst(url, '').trim();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onEditAnswer,
                        child: Text(
                          qText,
                          style: TextStyle(
                            fontSize: AppFont.body,
                            height: 1.5,
                            color: done
                                ? AppColors.textFaint
                                : AppColors.textPrimary,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textFaint,
                          ),
                        ),
                      ),
                      if (url != null) ...[
                        const Gap(7),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.open_in_new_rounded,
                                size: 14, color: color),
                            const Gap(5),
                            Text('링크 열기',
                                style: TextStyle(
                                    fontSize: AppFont.caption,
                                    color: color,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ],
                  );
                }),
                // 받은 답 — 있으면 보여주고, 없으면 적으라고 안내한다.
                const Gap(7),
                InkWell(
                  onTap: onEditAnswer,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasAnswer
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      border: Border.all(
                        color: hasAnswer
                            ? AppColors.primary.withValues(alpha: 0.45)
                            : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            hasAnswer
                                ? Icons.chat_bubble_rounded
                                : Icons.edit_note_rounded,
                            size: 14,
                            color: hasAnswer
                                ? AppColors.primary
                                : AppColors.textFaint),
                        const Gap(7),
                        Expanded(
                          child: Text(
                            hasAnswer ? answer : '답 적기',
                            style: TextStyle(
                              fontSize: AppFont.label,
                              height: 1.45,
                              color: hasAnswer
                                  ? AppColors.textPrimary
                                  : AppColors.textFaint,
                            ),
                          ),
                        ),
                      ],
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

/// 내가 추가한 질문 — lecture_answers 에서 qkey 가 'custom-' 인 행들.
class _CustomSection extends StatelessWidget {
  final Map<String, LectureAnswer> recs;
  final bool answeredOnly;
  final VoidCallback onAdd;
  final Future<void> Function(String qkey, String question, bool now) onToggle;
  final Future<void> Function(String qkey, String question, String current)
      onEditAnswer;
  final Future<void> Function(String qkey, String question) onDelete;

  const _CustomSection({
    required this.recs,
    required this.answeredOnly,
    required this.onAdd,
    required this.onToggle,
    required this.onEditAnswer,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final items = recs.entries
        .where((e) => e.key.startsWith('custom-'))
        .where((e) => !answeredOnly || e.value.hasAnswer)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return GlassCard(
      accent: AppColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_comment_rounded,
                    size: 18, color: AppColors.violet),
              ),
              const Gap(12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내가 추가한 질문',
                        style: TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800)),
                    Gap(2),
                    Text('강의 중 생각난 것을 바로 적어두기',
                        style: TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: AppFont.label, fontWeight: FontWeight.w800),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('질문 추가'),
              ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('아직 없어요. 「질문 추가」로 내 질문을 넣으세요.',
                  style: TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.label)),
            ),
          for (var i = 0; i < items.length; i++)
            _QuestionRow(
              number: i + 1,
              text: items[i].value.question,
              color: AppColors.violet,
              rec: items[i].value,
              onToggle: () => onToggle(items[i].key, items[i].value.question,
                  items[i].value.asked),
              onEditAnswer: () => onEditAnswer(
                  items[i].key, items[i].value.question, items[i].value.answer),
              onDelete: () =>
                  onDelete(items[i].key, items[i].value.question),
            ),
        ],
      ),
    );
  }
}
