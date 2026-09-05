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

/// 강의 질문 — 내가 하나씩 만든다. 프리셋 없음. 팝업 없이 그 자리에서 편집.
const _kQuestionColor = Color(0xFFF97316);
final _urlRe = RegExp(r'https?://\S+');

/// Cmd(⌘)+Enter 또는 Ctrl+Enter 로 [onDo] 실행 — 저장/편집완료.
Widget _cmdEnter(VoidCallback onDo, Widget child) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): onDo,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): onDo,
      },
      child: child,
    );

/// 내 상황 기본값(편집하면 DB의 __situation__ 이 우선).
const _defaultSituation = [
  '무주택 신혼부부 · 세대 전원 무주택',
  '가용 자금 약 8,100만원',
  '생애최초 특별공급 가능 (부부 모두 소유 이력 없음, 미사용)',
  '에어비앤비 운영 주소에 전입신고 되어 있음',
  '전략: 모아·신통 빌라 경매/매매 (법인 공시가1억↓ 단타·플피)',
];

String _asPlainText(Map<String, LectureAnswer> recs) {
  final b = StringBuffer()
    ..writeln('[경매 강의 질문]')
    ..writeln();
  final sitRec = recs['__situation__'];
  final sit = (sitRec?.answer.trim().isNotEmpty ?? false)
      ? sitRec!.answer.trim().split('\n')
      : _defaultSituation;
  b.writeln('내 상황');
  for (final s in sit) {
    if (s.trim().isNotEmpty) b.writeln('- ${s.trim()}');
  }
  b.writeln();
  final qs = recs.entries.where((e) => e.key.startsWith('custom-')).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (var i = 0; i < qs.length; i++) {
    final r = qs[i].value;
    b.writeln('${r.asked ? '[v]' : '[ ]'} ${i + 1}) ${r.question.replaceAll('\n', ' ')}');
    if (r.hasAnswer) {
      for (final line in r.answer.trim().split('\n')) {
        b.writeln('    → ${line.trim()}');
      }
    }
  }
  return b.toString();
}

class LectureQuestionsView extends ConsumerStatefulWidget {
  const LectureQuestionsView({super.key});

  @override
  ConsumerState<LectureQuestionsView> createState() =>
      _LectureQuestionsViewState();
}

class _LectureQuestionsViewState extends ConsumerState<LectureQuestionsView> {
  bool _answeredOnly = false;
  bool _adding = false;
  int _week = 0; // 0=전체, 1=1주차, 2=2주차
  final _addCtl = TextEditingController();

  @override
  void dispose() {
    _addCtl.dispose();
    super.dispose();
  }

  /// 질문의 주차 — qkey 에 'custom-w{N}-' 로 박아둔다. 없으면 1주차.
  int _weekOf(String qkey) {
    final m = RegExp(r'^custom-w(\d+)-').firstMatch(qkey);
    return m != null ? int.parse(m.group(1)!) : 1;
  }

  Widget _weekChips() {
    Widget chip(int v, String label) {
      final on = _week == v;
      return InkWell(
        onTap: () => setState(() => _week = v),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color:
                on ? _kQuestionColor.withValues(alpha: 0.18) : Colors.transparent,
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

  Future<void> _toggleAsked(String qkey, String question, bool now) =>
      _save(qkey, question, {'asked': !now});
  Future<void> _saveAnswer(String qkey, String question, String v) =>
      _save(qkey, question,
          {'answer': v, if (v.trim().isNotEmpty) 'asked': true});
  Future<void> _saveQuestion(String qkey, String v) => _save(qkey, v, {});
  Future<void> _saveSituation(String v) =>
      _save('__situation__', '내 상황', {'answer': v});

  Future<void> _addQuestion() async {
    final t = _addCtl.text.trim();
    if (t.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    final w = _week == 0 ? 1 : _week; // 전체에서 추가하면 1주차로
    await _save('custom-w$w-${DateTime.now().microsecondsSinceEpoch}', t, {});
    _addCtl.clear();
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _deleteQuestion(String qkey) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('lecture_answers')
          .delete()
          .eq('qkey', qkey);
      ref.invalidate(lectureAnswersProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lectureAnswersProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (recs) {
        final sitRec = recs['__situation__'];
        final sitText = (sitRec?.answer.trim().isNotEmpty ?? false)
            ? sitRec!.answer.trim()
            : _defaultSituation.join('\n');
        final sitLines = sitText
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final qs = recs.entries
            .where((e) => e.key.startsWith('custom-'))
            .where((e) => _week == 0 || _weekOf(e.key) == _week)
            .where((e) => !_answeredOnly || e.value.hasAnswer)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(4),
            Row(children: [
              Expanded(child: _weekChips()),
              IconButton(
                tooltip: '질문+답 전체 복사',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_all_rounded, size: 19),
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                      ClipboardData(text: _asPlainText(recs)));
                  m.showSnackBar(
                      const SnackBar(content: Text('질문과 답을 복사했어요')));
                },
              ),
              IconButton(
                tooltip: _answeredOnly ? '전체 보기' : '답 적은 것만',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                    _answeredOnly
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color:
                        _answeredOnly ? AppColors.primary : AppColors.textFaint),
                onPressed: () => setState(() => _answeredOnly = !_answeredOnly),
              ),
            ]),
            const Gap(10),
            _SituationCard(
                lines: sitLines, currentText: sitText, onSave: _saveSituation),
            const Gap(Insets.gap),
            // 작은 질문 추가 버튼.
            if (!_adding)
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => setState(() => _adding = true),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kQuestionColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 15, color: Colors.white),
                      Gap(4),
                      Text('질문 추가',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            if (!_adding) const Gap(Insets.gap),
            if (_adding) ...[
              GlassCard(
                accent: _kQuestionColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cmdEnter(
                      _addQuestion,
                      TextField(
                        controller: _addCtl,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(
                            fontSize: AppFont.body, height: 1.5),
                        decoration: const InputDecoration(
                            hintText: '질문을 입력하세요 (⌘/Ctrl+Enter로 추가)'),
                        onSubmitted: (_) => _addQuestion(),
                      ),
                    ),
                    const Gap(10),
                    Row(children: [
                      const Spacer(),
                      TextButton(
                          onPressed: () {
                            _addCtl.clear();
                            setState(() => _adding = false);
                          },
                          child: const Text('취소')),
                      const Gap(8),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: _kQuestionColor),
                          onPressed: _addQuestion,
                          child: const Text('추가')),
                    ]),
                  ],
                ),
              ),
              const Gap(Insets.gap),
            ],
            if (qs.isEmpty && !_adding)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text('질문이 없어요. 「질문 추가」로 하나씩 만드세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textFaint)),
              ),
            for (var i = 0; i < qs.length; i++) ...[
              _QuestionRow(
                key: ValueKey(qs[i].key),
                number: i + 1,
                rec: qs[i].value,
                onToggle: () => _toggleAsked(
                    qs[i].key, qs[i].value.question, qs[i].value.asked),
                onEditQuestion: (v) => _saveQuestion(qs[i].key, v),
                onEditAnswer: (v) =>
                    _saveAnswer(qs[i].key, qs[i].value.question, v),
                onDelete: () => _deleteQuestion(qs[i].key),
              ),
              const Gap(10),
            ],
          ],
        );
      },
    );
  }
}

/// 강의 질문 단독 페이지(직접 URL 접근용).
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

/// 내 상황 — 연필을 누르면 그 자리에서 바로 편집(팝업 없음).
class _SituationCard extends StatefulWidget {
  final List<String> lines;
  final String currentText;
  final Future<void> Function(String) onSave;
  const _SituationCard(
      {required this.lines, required this.currentText, required this.onSave});

  @override
  State<_SituationCard> createState() => _SituationCardState();
}

class _SituationCardState extends State<_SituationCard> {
  bool _edit = false;
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.currentText);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _doSave() async {
    await widget.onSave(_c.text);
    if (mounted) setState(() => _edit = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('내 상황',
                  style: TextStyle(
                      fontSize: AppFont.title, fontWeight: FontWeight.w700)),
            ),
            if (!_edit)
              InkWell(
                onTap: () {
                  _c.text = widget.currentText;
                  setState(() => _edit = true);
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_rounded,
                      size: 18, color: AppColors.textFaint),
                ),
              ),
          ]),
          const Gap(12),
          if (_edit) ...[
            _cmdEnter(
              _doSave,
              TextField(
                controller: _c,
                autofocus: true,
                minLines: 5,
                maxLines: 12,
                style: const TextStyle(fontSize: AppFont.body, height: 1.5),
                decoration: const InputDecoration(
                    hintText: '한 줄에 하나씩 (⌘/Ctrl+Enter로 저장)'),
              ),
            ),
            const Gap(10),
            Row(children: [
              const Spacer(),
              TextButton(
                  onPressed: () => setState(() => _edit = false),
                  child: const Text('취소')),
              const Gap(8),
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: _kQuestionColor),
                onPressed: _doSave,
                icon: const Icon(Icons.save_rounded, size: 17),
                label: const Text('저장'),
              ),
            ]),
          ] else
            for (final s in widget.lines)
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
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              color: AppColors.textPrimary,
                              height: 1.45)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// 질문 한 개 — 질문·답 모두 그 칸에서 바로 편집. 번호를 누르면 물어봤음 체크.
class _QuestionRow extends StatefulWidget {
  final int number;
  final LectureAnswer rec;
  final VoidCallback onToggle;
  final ValueChanged<String> onEditQuestion;
  final ValueChanged<String> onEditAnswer;
  final VoidCallback onDelete;

  const _QuestionRow({
    super.key,
    required this.number,
    required this.rec,
    required this.onToggle,
    required this.onEditQuestion,
    required this.onEditAnswer,
    required this.onDelete,
  });

  @override
  State<_QuestionRow> createState() => _QuestionRowState();
}

class _QuestionRowState extends State<_QuestionRow> {
  late final TextEditingController _q;
  late final TextEditingController _a;
  late final FocusNode _qf;
  late final FocusNode _af;
  bool _qEdit = false; // 질문 편집 중?

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: widget.rec.question);
    _a = TextEditingController(text: widget.rec.answer);
    _qf = FocusNode()..addListener(_onQ);
    _af = FocusNode()..addListener(_onA);
  }

  void _onQ() {
    if (!_qf.hasFocus) {
      final v = _q.text.trim();
      if (v.isNotEmpty && v != widget.rec.question.trim()) {
        widget.onEditQuestion(v);
      }
      if (mounted) setState(() => _qEdit = false);
    }
  }

  void _onA() {
    if (!_af.hasFocus) {
      final v = _a.text.trim();
      if (v != widget.rec.answer.trim()) widget.onEditAnswer(v);
    }
  }

  @override
  void didUpdateWidget(covariant _QuestionRow old) {
    super.didUpdateWidget(old);
    if (!_qf.hasFocus && widget.rec.question != _q.text) {
      _q.text = widget.rec.question;
    }
    if (!_af.hasFocus && widget.rec.answer != _a.text) {
      _a.text = widget.rec.answer;
    }
  }

  @override
  void dispose() {
    _qf.dispose();
    _af.dispose();
    _q.dispose();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.rec.asked;
    final hasAnswer = _a.text.trim().isNotEmpty;
    final url = _urlRe.firstMatch(_q.text)?.group(0);
    return GlassCard(
      accent: done ? AppColors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 번호 + 질문 + 삭제 — 한 줄. 세로 중앙정렬로 배지와 글자를 맞춘다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.primary.withValues(alpha: 0.22)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: done ? AppColors.primary : AppColors.border),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: AppColors.primary)
                      : Center(
                          child: Text('${widget.number}',
                              style: const TextStyle(
                                  fontSize: AppFont.micro,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary))),
                ),
              ),
              const Gap(10),
              Expanded(
                child: _qEdit
                    ? _cmdEnter(
                        () => _qf.unfocus(),
                        TextField(
                          controller: _q,
                          focusNode: _qf,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              height: 1.4,
                              fontWeight: FontWeight.w700),
                          onChanged: (_) => setState(() {}),
                          onTapOutside: (_) => _qf.unfocus(),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '질문',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: () => setState(() => _qEdit = true),
                        child: Text(
                          _q.text.trim().isEmpty ? '질문 (탭해서 입력)' : _q.text,
                          style: TextStyle(
                              fontSize: AppFont.body,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: _q.text.trim().isEmpty
                                  ? AppColors.textFaint
                                  : AppColors.textPrimary),
                        ),
                      ),
              ),
              const Gap(4),
              InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textFaint),
                ),
              ),
            ],
          ),
          if (url != null)
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 14, color: _kQuestionColor),
                    Gap(5),
                    Text('링크 열기',
                        style: TextStyle(
                            fontSize: AppFont.caption,
                            color: _kQuestionColor,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          const Gap(8),
          // 답 — 번호 아래로 들여써서 정렬.
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: _cmdEnter(
              () => _af.unfocus(),
              TextField(
              controller: _a,
              focusNode: _af,
              minLines: 3,
              maxLines: 10,
              style: const TextStyle(fontSize: AppFont.label, height: 1.45),
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => _af.unfocus(),
              decoration: InputDecoration(
                hintText: '답 적기',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: hasAnswer
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surfaceAlt,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(
                        color: hasAnswer
                            ? AppColors.primary.withValues(alpha: 0.45)
                            : AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
