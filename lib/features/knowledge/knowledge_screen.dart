import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

const _amber = Color(0xFFF59E0B);

/// 자료실 메모 추가/수정 다이얼로그 (외부에서도 호출 가능).
Future<void> showKnowledgeNoteEditor(BuildContext context, WidgetRef ref,
        {KnowledgeNote? note}) =>
    _noteDialog(context, ref, note: note);

/// 부동산 지식 자료실 본문 — 강의 Q&A·칼럼·메모를 키워드/태그로 검색.
/// 경매 화면의 '자료실' 탭에서도 그대로 재사용한다.
class KnowledgeView extends ConsumerStatefulWidget {
  const KnowledgeView({super.key});

  @override
  ConsumerState<KnowledgeView> createState() => _KnowledgeViewState();
}

class _KnowledgeViewState extends ConsumerState<KnowledgeView> {
  final _q = TextEditingController();
  String _tag = '전체';
  String _kind = 'all'; // all | qa | article | note
  bool _starOnly = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(knowledgeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (all) {
            if (all.isEmpty) {
              return const EmptyState(
                icon: Icons.menu_book_rounded,
                message: '자료가 없어요.\n강의 Q&A·칼럼을 불러오거나 메모를 추가하세요.',
              );
            }
            // 태그 집계
            final counts = <String, int>{};
            for (final n in all) {
              for (final t in n.tags) {
                counts[t] = (counts[t] ?? 0) + 1;
              }
            }
            final tags = counts.keys.toList()
              ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

            final kw = _q.text.trim().toLowerCase();
            final list = all.where((n) {
              if (_starOnly && !n.starred) return false;
              if (_kind != 'all' && n.kind != _kind) return false;
              if (_tag != '전체' && !n.tags.contains(_tag)) return false;
              if (kw.isEmpty) return true;
              return kw.split(RegExp(r'\s+')).every(n.haystack.contains);
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 검색창
                TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '검색 (예: 취득세, 공주가 1억, 매매사업자, 분담금)',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: kw.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _q.clear()),
                          ),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const Gap(12),
                // 종류 구분 (강의 Q&A / 칼럼 / 내 메모)
                Row(children: [
                  for (final k in const [
                    ('all', '전체', Icons.apps_rounded),
                    ('qa', '강의 Q&A', Icons.forum_rounded),
                    ('article', '칼럼', Icons.article_rounded),
                    ('note', '내 메모', Icons.edit_note_rounded),
                  ]) ...[
                    _kindTab(k.$1, k.$2, k.$3,
                        all.where((n) => k.$1 == 'all' || n.kind == k.$1).length),
                    const Gap(6),
                  ],
                ]),
                const Gap(12),
                // 태그 필터
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('전체', all.length, _tag == '전체',
                        () => setState(() => _tag = '전체')),
                    const Gap(6),
                    _starChip(all.where((n) => n.starred).length),
                    const Gap(6),
                    for (final t in tags) ...[
                      _chip(t, counts[t]!, _tag == t,
                          () => setState(() => _tag = _tag == t ? '전체' : t)),
                      const Gap(6),
                    ],
                  ]),
                ),
                const Gap(14),
                Text('${list.length}건',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 12.5)),
                const Gap(8),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Text('검색 결과가 없어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                for (final n in list) ...[
                  _NoteCard(
                    note: n,
                    keyword: kw,
                    onStar: () => _toggleStar(ref, n),
                    onEdit: n.kind == 'note'
                        ? () => _noteDialog(context, ref, note: n)
                        : null,
                    onDelete: () => _delete(context, ref, n),
                  ),
                  const Gap(10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kindTab(String kind, String label, IconData icon, int n) {
    final sel = _kind == kind;
    return InkWell(
      onTap: () => setState(() => _kind = kind),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _amber.withValues(alpha: 0.16) : AppColors.surfaceAlt,
          border: Border.all(color: sel ? _amber : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: sel ? _amber : AppColors.textFaint),
          const Gap(5),
          Text('$label $n',
              style: TextStyle(
                  color: sel ? _amber : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _chip(String label, int n, bool sel, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? _amber.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
                color: sel ? _amber : AppColors.border, width: sel ? 1.4 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$label $n',
              style: TextStyle(
                  color: sel ? _amber : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ),
      );

  Widget _starChip(int n) => InkWell(
        onTap: () => setState(() => _starOnly = !_starOnly),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color:
                _starOnly ? AppColors.gold.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
                color: _starOnly ? AppColors.gold : AppColors.border,
                width: _starOnly ? 1.4 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded,
                size: 14,
                color: _starOnly ? AppColors.gold : AppColors.textSecondary),
            const Gap(4),
            Text('$n',
                style: TextStyle(
                    color: _starOnly ? AppColors.gold : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Future<void> _toggleStar(WidgetRef ref, KnowledgeNote n) async {
    await ref
        .read(supabaseProvider)
        .from('knowledge_notes')
        .update({'starred': !n.starred}).eq('id', n.id);
    invalidateAll(ref);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, KnowledgeNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('삭제할까요?', style: TextStyle(fontSize: 16)),
        content: Text(n.title,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(supabaseProvider)
        .from('knowledge_notes')
        .delete()
        .eq('id', n.id);
    invalidateAll(ref);
  }

}

/// 메모 추가/수정 다이얼로그.
Future<void> _noteDialog(BuildContext context, WidgetRef ref,
    {KnowledgeNote? note}) async {
    final t = TextEditingController(text: note?.title ?? '');
    final b = TextEditingController(text: note?.body ?? '');
    final g = TextEditingController(text: note?.tags.join(', ') ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(note == null ? '메모 추가' : '메모 수정',
            style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: t,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '제목')),
              const Gap(10),
              TextField(
                  controller: b,
                  minLines: 4,
                  maxLines: 12,
                  decoration: const InputDecoration(labelText: '내용')),
              const Gap(10),
              TextField(
                  controller: g,
                  decoration: const InputDecoration(
                      labelText: '태그 (쉼표로 구분)', hintText: '재개발, 세금')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _amber),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (saved != true || t.text.trim().isEmpty) return;
    final sb = ref.read(supabaseProvider);
    final tags = g.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final data = {
      'kind': 'note',
      'title': t.text.trim(),
      'body': b.text.trim(),
      'tags': tags,
      'source': '내 메모',
    };
    try {
      if (note == null) {
        await sb.from('knowledge_notes').insert({
          ...data,
          'user_id': sb.auth.currentUser!.id,
          'source_date': DateTime.now().toIso8601String().substring(0, 10),
        });
      } else {
        await sb.from('knowledge_notes').update(data).eq('id', note.id);
      }
      invalidateAll(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: AppColors.rose),
        );
      }
    }
  }

class _NoteCard extends StatefulWidget {
  final KnowledgeNote note;
  final String keyword;
  final VoidCallback onStar;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  const _NoteCard({
    required this.note,
    required this.keyword,
    required this.onStar,
    this.onEdit,
    required this.onDelete,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final body = n.body ?? '';
    final long = body.length > 110;
    final (kindLabel, kindColor, kindIcon) = switch (n.kind) {
      'qa' => ('강의 Q&A', AppColors.sky, Icons.forum_rounded),
      'article' => ('칼럼', _amber, Icons.article_rounded),
      'note' => ('내 메모', AppColors.primary, Icons.edit_note_rounded),
      _ => ('자료', AppColors.textFaint, Icons.description_rounded),
    };
    final hasUrl = (n.url ?? '').isNotEmpty;
    return GlassCard(
      accent: kindColor,
      onTap: hasUrl
          ? () => launchUrl(Uri.parse(n.url!),
              mode: LaunchMode.externalApplication)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 종류 배지
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kindColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(kindIcon, size: 12, color: kindColor),
                const Gap(4),
                Text(kindLabel,
                    style: TextStyle(
                        color: kindColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            if (hasUrl) ...[
              const Gap(6),
              Icon(Icons.open_in_new_rounded, size: 13, color: kindColor),
              const Gap(3),
              Text('원문',
                  style: TextStyle(
                      color: kindColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ]),
          const Gap(6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35)),
              ),
              const Gap(6),
              InkWell(
                onTap: widget.onStar,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                      n.starred
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 19,
                      color: n.starred ? AppColors.gold : AppColors.textFaint),
                ),
              ),
              RecordMenu(
                  onEdit: widget.onEdit ?? widget.onStar,
                  onDelete: widget.onDelete),
            ],
          ),
          const Gap(6),
          InkWell(
            onTap: long ? () => setState(() => _open = !_open) : null,
            child: _open
                ? _RichBody(body: body, accent: kindColor)
                : Text(
                    body
                        .replaceAll(RegExp(r'[【】■·]'), '')
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary),
                  ),
          ),
          if (long) ...[
            const Gap(4),
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Text(_open ? '접기' : '더 보기',
                  style: const TextStyle(
                      color: _amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
          const Gap(8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final t in n.tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(t,
                      style: const TextStyle(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              if (n.source != null)
                Text(
                    '· ${n.source}${n.sourceDate == null ? '' : ' · ${n.sourceDate!.year}.${n.sourceDate!.month}.${n.sourceDate!.day}'}',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 11)),
              if (n.asker != null)
                Text('· 질문 ${n.asker}',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 자료실 단독 페이지 (직접 URL 접근용). 사이드 메뉴에는 노출하지 않고
/// 경매 화면의 '자료실' 탭으로 접근한다.
class KnowledgeScreen extends ConsumerWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ModulePage(
      title: '자료실',
      icon: Icons.menu_book_rounded,
      color: _amber,
      action: AddButton(
        color: _amber,
        label: '메모',
        onTap: () => _noteDialog(context, ref),
      ),
      children: const [KnowledgeView()],
    );
  }
}


/// 자료실 본문을 구조화해서 보여준다.
/// 【블록제목】 → 라벨 · ■ 소제목 → 굵게 · · 불릿 → 들여쓰기 목록
class _RichBody extends StatelessWidget {
  final String body;
  final Color accent;
  const _RichBody({required this.body, required this.accent});

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (final raw in body.split('\n')) {
      final l = raw.trim();
      if (l.isEmpty) {
        out.add(const Gap(8));
        continue;
      }
      if (l.startsWith('【') && l.endsWith('】')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(l.replaceAll(RegExp(r'[【】]'), ''),
                style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ),
        ));
      } else if (l.startsWith('■')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 5),
          child: Row(children: [
            Container(width: 3, height: 13, color: accent),
            const Gap(7),
            Expanded(
              child: Text(l.substring(1).trim(),
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
          ]),
        ));
      } else if (l.startsWith('·') || l.startsWith('•') || l.startsWith('-')) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                    color: AppColors.textFaint, shape: BoxShape.circle),
              ),
            ),
            const Gap(7),
            Expanded(
              child: Text(l.substring(1).trim(),
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textSecondary)),
            ),
          ]),
        ));
      } else {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(l,
              style: const TextStyle(
                  fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
        ));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}
