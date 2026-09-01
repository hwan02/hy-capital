// 책 — 읽는 «순서»를 나무로 본다.
//
//   뿌리(입문) → 줄기(분야) → 가지(개별 책)
//
// 목록이 아니라 트리인 이유: 어떤 책은 앞의 책을 읽어야 읽힌다.
// 순서를 모르면 어려운 책을 먼저 집었다가 덮는다.
//
// 표지는 직접 올린다(base64). 올리기 전엔 제목으로 만든 표지를 그린다 —
// 빈 칸을 두면 나무가 앙상해 보인다.
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/record_form.dart' show confirmDelete;
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

const _bookColor = Color(0xFFB4844E); // 나무 — 갈색

/// 줄기 하나. 순서가 곧 읽는 순서다.
class _Branch {
  final String key;
  final String label;
  final String role; // 뿌리 / 줄기 / 가지 중 어디인가
  final String goal;
  final IconData icon;
  final Color color;
  const _Branch(this.key, this.label, this.role, this.goal, this.icon, this.color);
}

/// 부동산 나무. 위에서 아래로 읽는다.
const _branches = <_Branch>[
  _Branch('입문', '입문', '뿌리', '왜 하는지와 계약의 바닥을 깐다',
      Icons.park_rounded, AppColors.primary),
  _Branch('경매', '경매·공매', '줄기', '내 주력. 권리분석 → 명도 → 특수물건',
      Icons.gavel_rounded, Color(0xFF14B8A6)),
  _Branch('아파트', '아파트·내집마련', '줄기', '입지를 보는 눈과 세금',
      Icons.apartment_rounded, AppColors.sky),
  _Branch('수익형', '수익형', '가지', '주택 규제 밖 — 상가·공장',
      Icons.storefront_rounded, AppColors.gold),
  _Branch('토지', '토지', '가지', '규제를 읽는 게임',
      Icons.terrain_rounded, Color(0xFFB4844E)),
  _Branch('법인', '법인', '가지', '개인으로 한계가 오면',
      Icons.corporate_fare_rounded, AppColors.violet),
];

class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});

  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
  String _category = '부동산';
  bool _todoOnly = false;

  Future<void> _save(Book b, Map<String, dynamic> patch) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('books')
          .update(patch)
          .eq('id', b.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패 — $e')));
      return;
    }
    ref.invalidate(booksProvider);
  }

  /// 안 읽음 → 읽는 중 → 읽음 → 안 읽음. 한 번 눌러 넘긴다.
  Future<void> _cycle(Book b) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    switch (b.status) {
      case 'todo':
        await _save(b, {'status': 'reading', 'started_on': today});
      case 'reading':
        await _save(b, {'status': 'done', 'read_on': today});
      default:
        await _save(b, {'status': 'todo', 'read_on': null, 'started_on': null});
    }
  }

  Future<void> _pickCover(Book b) async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final reader = html.FileReader()..readAsDataUrl(files.first);
    await reader.onLoad.first;
    await _save(b, {'cover': reader.result as String});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(booksProvider);
    return ModulePage(
      title: '책',
      subtitle: '읽는 순서 — 뿌리부터 가지까지',
      icon: Icons.menu_book_rounded,
      color: _bookColor,
      action: IconButton(
        tooltip: '책 추가',
        onPressed: () => _addBook(),
        icon: const Icon(Icons.add_rounded, color: _bookColor),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (all) {
            if (all.isEmpty) {
              return const EmptyState(
                icon: Icons.menu_book_rounded,
                message: '아직 책이 없어요.\n'
                    'scripts/seed_books.py 를 돌리거나 ＋로 추가하세요.',
              );
            }
            final cats = {for (final b in all) b.category}.toList()..sort();
            final books = all.where((b) => b.category == _category).toList();
            final done = books.where((b) => b.isDone).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 카테고리 (지금은 부동산 하나. 늘어나면 여기 붙는다)
                if (cats.length > 1) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in cats)
                      ModuleTab(
                          label: c,
                          icon: Icons.folder_rounded,
                          color: _bookColor,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c)),
                  ]),
                  const Gap(16),
                ],

                _Summary(
                  books: books,
                  todoOnly: _todoOnly,
                  onToggle: () => setState(() => _todoOnly = !_todoOnly),
                ),
                const Gap(20),

                // ── 나무 ────────────────────────────────────
                for (var i = 0; i < _branches.length; i++)
                  Builder(builder: (context) {
                    final br = _branches[i];
                    var mine = books.where((b) => b.branch == br.key).toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                    if (mine.isEmpty) return const SizedBox.shrink();
                    if (_todoOnly) {
                      mine = mine.where((b) => !b.isDone).toList();
                      if (mine.isEmpty) return const SizedBox.shrink();
                    }
                    return _BranchBlock(
                      branch: br,
                      books: mine,
                      last: i == _branches.length - 1,
                      onCycle: _cycle,
                      onCover: _pickCover,
                      onEdit: (b) => _editBook(b),
                    );
                  }),

                const Gap(10),
                Center(
                  child: Text('$done / ${books.length}권 읽음',
                      style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: AppFont.caption)),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── 추가 / 수정 ──────────────────────────────────────────
  Future<void> _addBook() async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _BookDialog(),
    );
    if (res == null) return;
    final sb = ref.read(supabaseProvider);
    await sb.from('books').insert({
      ...res,
      'user_id': sb.auth.currentUser!.id,
      'category': _category,
    });
    ref.invalidate(booksProvider);
  }

  Future<void> _editBook(Book b) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BookDialog(book: b),
    );
    if (res == null) return;
    if (res['__delete'] == true) {
      await ref.read(supabaseProvider).from('books').delete().eq('id', b.id);
      ref.invalidate(booksProvider);
      return;
    }
    await _save(b, res);
  }
}

// ══════════════════════════════════════════════════════════
// 요약
// ══════════════════════════════════════════════════════════

class _Summary extends StatelessWidget {
  final List<Book> books;
  final bool todoOnly;
  final VoidCallback onToggle;
  const _Summary(
      {required this.books, required this.todoOnly, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final done = books.where((b) => b.isDone).length;
    final reading = books.where((b) => b.isReading).length;
    final ratio = books.isEmpty ? 0.0 : done / books.length;

    // 다음에 읽을 책 — 줄기 순서 → 그 안의 순서. 안 읽은 것 중 첫 번째.
    Book? next;
    for (final br in _branches) {
      final cands = books
          .where((b) => b.branch == br.key && !b.isDone)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final reading = cands.where((b) => b.isReading).toList();
      if (reading.isNotEmpty) {
        next = reading.first;
        break;
      }
      if (cands.isNotEmpty) {
        next = cands.first;
        break;
      }
    }

    return GlassCard(
      accent: _bookColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                  '${books.length}권 · 읽음 $done'
                  '${reading > 0 ? ' · 읽는 중 $reading' : ''}',
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor:
                    todoOnly ? _bookColor : AppColors.textSecondary,
              ),
              child: Text(todoOnly ? '전체 보기' : '안 읽은 것만',
                  style: const TextStyle(
                      fontSize: AppFont.label, fontWeight: FontWeight.w700)),
            ),
          ]),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(_bookColor),
            ),
          ),
          if (next != null) ...[
            const Gap(14),
            Row(children: [
              Icon(
                  next.isReading
                      ? Icons.bookmark_rounded
                      : Icons.play_arrow_rounded,
                  size: 16,
                  color: AppColors.primary),
              const Gap(8),
              Text(next.isReading ? '읽는 중' : '다음에 읽을 책',
                  style: const TextStyle(
                      fontSize: AppFont.caption,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const Gap(10),
              Expanded(
                child: Text(next.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFont.body, fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 줄기 하나 — 세로 선으로 이어 나무처럼 보이게
// ══════════════════════════════════════════════════════════

class _BranchBlock extends StatelessWidget {
  final _Branch branch;
  final List<Book> books;
  final bool last;
  final Future<void> Function(Book) onCycle;
  final Future<void> Function(Book) onCover;
  final void Function(Book) onEdit;

  const _BranchBlock({
    required this.branch,
    required this.books,
    required this.last,
    required this.onCycle,
    required this.onCover,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final done = books.where((b) => b.isDone).length;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 줄기 — 세로 선 + 마디
          SizedBox(
            width: 34,
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: branch.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: branch.color, width: 1.4),
                ),
                child: Icon(branch.icon, size: 15, color: branch.color),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border,
                  ),
                ),
            ]),
          ),
          const Gap(12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 줄기 제목
                  Row(children: [
                    Text(branch.label,
                        style: TextStyle(
                            fontSize: AppFont.title,
                            fontWeight: FontWeight.w900,
                            color: branch.color)),
                    const Gap(9),
                    Pill(branch.role, color: branch.color),
                    const Spacer(),
                    Text('$done/${books.length}',
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textFaint,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const Gap(3),
                  Text(branch.goal,
                      style: const TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textSecondary)),
                  const Gap(14),
                  // 가지 — 책들
                  for (final b in books)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BookCard(
                        book: b,
                        color: branch.color,
                        onCycle: () => onCycle(b),
                        onCover: () => onCover(b),
                        onEdit: () => onEdit(b),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 책 한 권
// ══════════════════════════════════════════════════════════

class _BookCard extends StatelessWidget {
  final Book book;
  final Color color;
  final VoidCallback onCycle;
  final VoidCallback onCover;
  final VoidCallback onEdit;

  const _BookCard({
    required this.book,
    required this.color,
    required this.onCycle,
    required this.onCover,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final done = book.isDone;
    return GlassCard(
      accent: done ? AppColors.primary : (book.isReading ? color : null),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 순번
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${book.sortOrder}',
                style: TextStyle(
                    color: color,
                    fontSize: AppFont.micro,
                    fontWeight: FontWeight.w900)),
          ),
          const Gap(10),
          // 표지
          _Cover(book: book, color: color, onTap: onCover),
          const Gap(12),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: done
                            ? AppColors.textSecondary
                            : AppColors.textPrimary)),
                if ((book.author ?? '').isNotEmpty) ...[
                  const Gap(3),
                  Text(book.author!,
                      style: const TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textFaint)),
                ],
                const Gap(6),
                Row(children: [
                  _Level(level: book.level, color: color),
                  const Gap(10),
                  Expanded(
                    child: Text(book.tags.map((t) => '#$t').join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.micro,
                            color: AppColors.textFaint)),
                  ),
                ]),
                if ((book.why ?? '').isNotEmpty) ...[
                  const Gap(7),
                  Text(book.why!,
                      style: const TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textSecondary,
                          height: 1.5)),
                ],
                // 읽은 기록
                if (done || book.isReading) ...[
                  const Gap(8),
                  Row(children: [
                    Icon(done ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        size: 13,
                        color: done ? AppColors.primary : color),
                    const Gap(6),
                    Text(
                      done
                          ? (book.readOn == null
                              ? '읽음'
                              : '${Dates.ymd(book.readOn!)} 읽음')
                          : (book.startedOn == null
                              ? '읽는 중'
                              : '${Dates.ymd(book.startedOn!)} 시작'),
                      style: TextStyle(
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.w700,
                          color: done ? AppColors.primary : color),
                    ),
                    if (book.rating != null) ...[
                      const Gap(10),
                      for (var i = 0; i < book.rating!; i++)
                        const Icon(Icons.star_rounded,
                            size: 13, color: AppColors.gold),
                    ],
                  ]),
                ],
                if ((book.memo ?? '').isNotEmpty) ...[
                  const Gap(7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(book.memo!,
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textSecondary,
                            height: 1.55)),
                  ),
                ],
              ],
            ),
          ),
          const Gap(6),
          Column(children: [
            IconButton(
              tooltip: switch (book.status) {
                'todo' => '읽기 시작',
                'reading' => '다 읽음',
                _ => '안 읽음으로',
              },
              onPressed: onCycle,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                switch (book.status) {
                  'todo' => Icons.radio_button_unchecked_rounded,
                  'reading' => Icons.timelapse_rounded,
                  _ => Icons.check_circle_rounded,
                },
                size: 20,
                color: switch (book.status) {
                  'todo' => AppColors.textFaint,
                  'reading' => color,
                  _ => AppColors.primary,
                },
              ),
            ),
            IconButton(
              tooltip: '메모·수정',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_note_rounded,
                  size: 19, color: AppColors.textFaint),
            ),
          ]),
        ],
      ),
    );
  }
}

/// 표지 — 없으면 제목으로 그린다. 누르면 올린다.
class _Cover extends StatelessWidget {
  final Book book;
  final Color color;
  final VoidCallback onTap;
  const _Cover({required this.book, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const w = 58.0, h = 82.0;
    return Tooltip(
      message: book.cover == null ? '표지 올리기' : '표지 바꾸기',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(1, 2)),
            ],
          ),
          child: book.cover != null
              ? Image.network(book.cover!, fit: BoxFit.cover)
              : Stack(children: [
                  // 책등
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    child: Container(width: 5, color: color),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 5, 6),
                    child: Text(
                      book.title,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 8.5,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ),
                  const Positioned(
                    right: 3, bottom: 3,
                    child: Icon(Icons.add_photo_alternate_outlined,
                        size: 11, color: AppColors.textFaint),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _Level extends StatelessWidget {
  final int level;
  final Color color;
  const _Level({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('난이도 ',
          style: TextStyle(fontSize: AppFont.micro, color: AppColors.textFaint)),
      for (var i = 1; i <= 5; i++)
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: i <= level ? color : Colors.transparent,
              border: Border.all(
                  color: i <= level ? color : AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════
// 추가 · 수정 다이얼로그
// ══════════════════════════════════════════════════════════

class _BookDialog extends StatefulWidget {
  final Book? book;
  const _BookDialog({this.book});

  @override
  State<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<_BookDialog> {
  late final _title = TextEditingController(text: widget.book?.title ?? '');
  late final _author = TextEditingController(text: widget.book?.author ?? '');
  late final _tags =
      TextEditingController(text: widget.book?.tags.join(', ') ?? '');
  late final _why = TextEditingController(text: widget.book?.why ?? '');
  late final _memo = TextEditingController(text: widget.book?.memo ?? '');
  late final _link = TextEditingController(text: widget.book?.link ?? '');
  late final _order =
      TextEditingController(text: '${widget.book?.sortOrder ?? 1}');
  late String _branch = widget.book?.branch ?? '입문';
  late int _level = widget.book?.level ?? 1;
  late int _rating = widget.book?.rating ?? 0;

  // 예전에 읽은 책은 날짜를 «직접» 넣어야 한다.
  // 목록의 순환 버튼은 오늘 날짜만 박으므로 여기서 고친다.
  late String _status = widget.book?.status ?? 'todo';
  late DateTime? _startedOn = widget.book?.startedOn;
  late DateTime? _readOn = widget.book?.readOn;

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final cur = start ? _startedOn : _readOn;
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: start ? '읽기 시작한 날' : '다 읽은 날',
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _startedOn = d;
      } else {
        _readOn = d;
        // 다 읽은 날을 넣으면 상태도 따라간다 — 따로 누르게 하지 않는다.
        if (_status != 'done') _status = 'done';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.book != null;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(editing ? '책 수정' : '책 추가',
          style: const TextStyle(fontSize: AppFont.section)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '제목')),
            const Gap(10),
            TextField(
                controller: _author,
                decoration: const InputDecoration(labelText: '저자')),
            const Gap(10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _branch,
                  decoration: const InputDecoration(labelText: '줄기'),
                  dropdownColor: AppColors.surfaceAlt,
                  items: [
                    for (final b in _branches)
                      DropdownMenuItem(value: b.key, child: Text(b.label)),
                  ],
                  onChanged: (v) => setState(() => _branch = v ?? '입문'),
                ),
              ),
              const Gap(10),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '순서'),
                ),
              ),
            ]),
            const Gap(14),
            Row(children: [
              const Text('난이도',
                  style: TextStyle(
                      fontSize: AppFont.label, color: AppColors.textSecondary)),
              const Gap(12),
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _level = i),
                  icon: Icon(
                      i <= _level
                          ? Icons.square_rounded
                          : Icons.crop_square_rounded,
                      size: 17,
                      color: i <= _level ? _bookColor : AppColors.border),
                ),
            ]),
            if (editing) ...[
              const Gap(6),
              const Divider(height: 1, color: AppColors.border),
              const Gap(12),
              Row(children: [
                const Text('상태',
                    style: TextStyle(
                        fontSize: AppFont.label,
                        color: AppColors.textSecondary)),
                const Gap(12),
                for (final (k, label) in const [
                  ('todo', '안 읽음'),
                  ('reading', '읽는 중'),
                  ('done', '읽음'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label,
                          style: const TextStyle(fontSize: AppFont.caption)),
                      selected: _status == k,
                      onSelected: (_) => setState(() => _status = k),
                      selectedColor: _bookColor.withValues(alpha: 0.25),
                      backgroundColor: AppColors.surfaceAlt,
                      side: BorderSide(
                          color: _status == k ? _bookColor : AppColors.border),
                    ),
                  ),
              ]),
              const Gap(10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _DateChip(
                  label: '시작',
                  value: _startedOn,
                  onTap: () => _pick(true),
                  onClear: () => setState(() => _startedOn = null),
                ),
                _DateChip(
                  label: '읽은 날',
                  value: _readOn,
                  onTap: () => _pick(false),
                  onClear: () => setState(() => _readOn = null),
                ),
              ]),
              const Gap(4),
              const Text('예전에 읽은 책은 여기서 날짜를 직접 넣는다',
                  style: TextStyle(
                      fontSize: AppFont.micro, color: AppColors.textFaint)),
              const Gap(12),
              Row(children: [
                const Text('내 평가',
                    style: TextStyle(
                        fontSize: AppFont.label,
                        color: AppColors.textSecondary)),
                const Gap(12),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _rating = _rating == i ? 0 : i),
                    icon: Icon(
                        i <= _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 19,
                        color: i <= _rating
                            ? AppColors.gold
                            : AppColors.border),
                  ),
              ]),
            ],
            const Gap(10),
            TextField(
                controller: _tags,
                decoration: const InputDecoration(
                    labelText: '태그 (쉼표로 구분)', hintText: '경매, 초보')),
            const Gap(10),
            TextField(
                controller: _why,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: '이 자리에 왜 있나',
                    hintText: '앞 책과 어떻게 이어지는지')),
            const Gap(10),
            TextField(
                controller: _memo,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                    labelText: '읽고 남긴 것', hintText: '핵심 3줄, 써먹을 것')),
            const Gap(10),
            TextField(
                controller: _link,
                decoration: const InputDecoration(labelText: '링크 (선택)')),
          ]),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context, name: widget.book!.title)) {
                if (context.mounted) {
                  Navigator.pop(context, {'__delete': true});
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('삭제'),
          ),
        if (editing && (widget.book!.link ?? '').isNotEmpty)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(widget.book!.link!),
                webOnlyWindowName: '_blank'),
            child: const Text('링크 열기'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _bookColor,
              foregroundColor: const Color(0xFF1B1400)),
          onPressed: () {
            final t = _title.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, {
              'title': t,
              'author': _author.text.trim(),
              'branch': _branch,
              'sort_order': int.tryParse(_order.text.trim()) ?? 1,
              'level': _level,
              'tags': _tags.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              'why': _why.text.trim(),
              'memo': _memo.text.trim(),
              'link': _link.text.trim(),
              if (widget.book != null) ...{
                'rating': _rating == 0 ? null : _rating,
                'status': _status,
                'started_on': _startedOn?.toIso8601String().substring(0, 10),
                'read_on': _readOn?.toIso8601String().substring(0, 10),
              },
            });
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 날짜 하나 — 누르면 고르고, ×로 지운다.
class _DateChip extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value == null;
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: empty ? AppColors.border : _bookColor.withValues(alpha: 0.6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_rounded,
                size: 14,
                color: empty ? AppColors.textFaint : _bookColor),
            const Gap(7),
            Text(empty ? '$label 없음' : '$label ${Dates.ymd(value!)}',
                style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700,
                    color:
                        empty ? AppColors.textFaint : AppColors.textPrimary)),
            if (!empty)
              IconButton(
                tooltip: '지우기',
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textFaint),
              )
            else
              const Gap(4),
          ]),
        ),
      ),
    );
  }
}
