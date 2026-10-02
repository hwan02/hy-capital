// 책 — 읽는 «순서»를 나무로 본다.
//
//   뿌리(입문) → 줄기(분야) → 가지(개별 책)
//
// 목록이 아니라 트리인 이유: 어떤 책은 앞의 책을 읽어야 읽힌다.
// 순서를 모르면 어려운 책을 먼저 집었다가 덮는다.
//
// 표지는 직접 올린다(base64). 올리기 전엔 제목으로 만든 표지를 그린다 —
// 빈 칸을 두면 나무가 앙상해 보인다.
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

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
import '../../core/edit/plain_controller.dart';

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
  bool _calendar = false; // 나무 ↔ 달력

  Future<void> _save(Book b, Map<String, dynamic> patch) async {
    final books = ref.read(supabaseProvider).from('books');
    try {
      try {
        await books.update(patch).eq('id', b.id);
      } catch (e) {
        // 0059(reads 칸) 실행 전이면 회독 목록만 빼고 저장한다 —
        // 상태·날짜는 예전 칸에도 같이 들어가므로 읽기 기록은 남는다.
        if (!patch.containsKey('reads') || !'$e'.contains('reads')) rethrow;
        await books.update({...patch}..remove('reads')).eq('id', b.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패 — $e')));
      return;
    }
    ref.invalidate(booksProvider);
  }

  /// 안 읽음 → 읽는 중 → 읽음 → (다시 읽기) 읽는 중 …  한 번 눌러 넘긴다.
  ///
  /// 전에는 «읽음»에서 누르면 «안 읽음»으로 지워졌다. 책은 여러 번 읽는다 —
  /// 이제 다 읽은 책을 누르면 새 회독이 시작된다. 기록을 지우려면 수정 창에서.
  Future<void> _cycle(Book b) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reads = [...b.reads];
    if (reads.isNotEmpty && reads.last.ongoing) {
      reads[reads.length - 1] = reads.last.copyWith(end: today, done: true);
    } else {
      reads.add(BookRead(start: today));
    }
    await _save(b, Book.readsPatch(reads));
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

                Wrap(spacing: 8, runSpacing: 8, children: [
                  ModuleTab(
                      label: '나무',
                      icon: Icons.park_rounded,
                      color: _bookColor,
                      selected: !_calendar,
                      onTap: () => setState(() => _calendar = false)),
                  ModuleTab(
                      label: '달력',
                      icon: Icons.calendar_month_rounded,
                      color: _bookColor,
                      selected: _calendar,
                      onTap: () => setState(() => _calendar = true)),
                ]),
                const Gap(16),

                if (_calendar)
                  _ReadingCalendar(books: books, onEdit: _editBook)
                else ...[
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
                    // 번호가 겹치면 정렬이 흔들린다 — 제목으로 한 번 더 갈라
                    // 「번호 정리」 전후로 순서가 튀지 않게 한다.
                    final all = books.where((b) => b.branch == br.key).toList()
                      ..sort((a, b) => a.sortOrder != b.sortOrder
                          ? a.sortOrder.compareTo(b.sortOrder)
                          : a.title.compareTo(b.title));
                    if (all.isEmpty) return const SizedBox.shrink();
                    var mine = all;
                    if (_todoOnly) {
                      mine = all.where((b) => !b.isDone).toList();
                      if (mine.isEmpty) return const SizedBox.shrink();
                    }
                    return _BranchBlock(
                      branch: br,
                      books: mine,
                      branchAll: all,
                      last: i == _branches.length - 1,
                      onCycle: _cycle,
                      onCover: _pickCover,
                      onEdit: (b) => _editBook(b),
                      onRenumber: _renumber,
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
              ],
            );
          },
        ),
      ],
    );
  }

  // ── 추가 / 수정 ──────────────────────────────────────────

  /// 지금 카테고리의 책들 — 새 책 번호를 «마지막 다음»으로 매기는 데 쓴다.
  List<Book> _siblings() =>
      (ref.read(booksProvider).value ?? const <Book>[])
          .where((b) => b.category == _category)
          .toList();

  /// 줄기 번호를 보이는 순서 그대로 1..N 으로 다시 매긴다.
  /// 새 책이 전부 1 번으로 들어가 겹쳐 버린 것을 여기서 편다.
  Future<void> _renumber(List<Book> branchBooks) async {
    final sb = ref.read(supabaseProvider);
    for (var i = 0; i < branchBooks.length; i++) {
      final want = i + 1;
      if (branchBooks[i].sortOrder == want) continue;
      await sb.from('books').update({'sort_order': want})
          .eq('id', branchBooks[i].id);
    }
    ref.invalidate(booksProvider);
  }

  Future<void> _addBook() async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BookDialog(siblings: _siblings()),
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
      builder: (_) => _BookDialog(book: b, siblings: _siblings()),
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

  /// 이 줄기의 «전부». books 는 「읽을 것만」 필터가 걸려 있을 수 있어서,
  /// 번호 판정·정리는 반드시 이쪽으로 한다 — 필터된 목록으로 매기면
  /// 다 읽은 책이 빠진 채 번호가 다시 밀린다.
  final List<Book> branchAll;

  /// 이 줄기의 번호를 순서대로 1..N 으로 다시 매긴다.
  final Future<void> Function(List<Book>) onRenumber;

  const _BranchBlock({
    required this.branch,
    required this.books,
    required this.last,
    required this.onCycle,
    required this.onCover,
    required this.onEdit,
    required this.branchAll,
    required this.onRenumber,
  });

  /// 번호가 «겹치는» 줄기인가. 겹칠 때만 정리 버튼을 띄운다.
  bool get _dup =>
      branchAll.map((b) => b.sortOrder).toSet().length != branchAll.length;

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
                    // 같은 번호가 둘 이상인 줄기에만 — 평소엔 안 보인다.
                    if (_dup)
                      TextButton.icon(
                        onPressed: () => onRenumber(branchAll),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: branch.color),
                        icon: const Icon(Icons.low_priority_rounded, size: 14),
                        label: const Text('번호 정리',
                            style: TextStyle(
                                fontSize: AppFont.caption,
                                fontWeight: FontWeight.w800)),
                      ),
                    const Gap(6),
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
                          : '${book.timesRead > 0 ? '${book.timesRead + 1}회독 ' : ''}'
                              '${book.startedOn == null ? '읽는 중' : '${Dates.ymd(book.startedOn!)} 시작'}',
                      style: TextStyle(
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.w700,
                          color: done ? AppColors.primary : color),
                    ),
                    if (book.timesRead >= 2) ...[
                      const Gap(8),
                      Pill('${book.timesRead}회독', color: AppColors.primary),
                    ],
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
                _ => '다시 읽기 (${book.timesRead + 1}회독)',
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

/// base64 data URL → 바이트. 아니면 null.
Uint8List? _bytes(String? dataUrl) {
  if (dataUrl == null) return null;
  final i = dataUrl.indexOf(',');
  if (i < 0 || !dataUrl.startsWith('data:')) return null;
  try {
    return base64Decode(dataUrl.substring(i + 1));
  } catch (_) {
    return null;
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
          // data: URL 은 Image.network 로 안 그려진다. 바이트로 풀어서 그린다.
          child: _bytes(book.cover) != null
              ? Image.memory(_bytes(book.cover)!,
                  fit: BoxFit.cover, gaplessPlayback: true)
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
  /// 같은 카테고리의 책 전부. «새 책»의 순서를 그 줄기의 마지막 다음으로
  /// 잡으려고 받는다 — 안 주면 전부 1 로 들어가 번호가 겹친다.
  final List<Book> siblings;
  final Book? book;
  const _BookDialog({this.book, this.siblings = const []});

  /// [branch] 줄기에서 «다음 순서». 비어 있으면 1.
  int nextOrder(String branch) {
    final n = siblings
        .where((b) => b.branch == branch)
        .fold<int>(0, (m, b) => b.sortOrder > m ? b.sortOrder : m);
    return n + 1;
  }

  @override
  State<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<_BookDialog> {
  late final _title = PlainController(text: widget.book?.title ?? '');
  late final _author = PlainController(text: widget.book?.author ?? '');
  late final _tags =
      PlainController(text: widget.book?.tags.join(', ') ?? '');
  late final _why = PlainController(text: widget.book?.why ?? '');
  late final _memo = PlainController(text: widget.book?.memo ?? '');
  late final _link = PlainController(text: widget.book?.link ?? '');
  late String _branch = widget.book?.branch ?? '입문';
  late final _order = PlainController(
      text: '${widget.book?.sortOrder ?? widget.nextOrder(_branch)}');
  late int _level = widget.book?.level ?? 1;
  late int _rating = widget.book?.rating ?? 0;

  // 회독 기록 — 예전에 읽은 책은 날짜를 «직접» 넣어야 한다.
  // 목록의 순환 버튼은 오늘 날짜만 박으므로 여기서 고친다.
  // 상태(안 읽음·읽는 중·읽음)는 마지막 회독에서 저절로 정해진다.
  late final List<BookRead> _reads = [...?widget.book?.reads];

  Future<void> _pick(int i, bool start) async {
    final now = DateTime.now();
    final r = _reads[i];
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? r.start : r.end) ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: start ? '${i + 1}회독 시작한 날' : '${i + 1}회독 다 읽은 날',
    );
    if (d == null) return;
    setState(() {
      // 다 읽은 날을 넣으면 그 회독은 «읽음»이 된다.
      _reads[i] = start ? r.copyWith(start: d) : r.copyWith(end: d, done: true);
    });
  }

  String get _statusLabel {
    if (_reads.isEmpty) return '안 읽음';
    final done = _reads.where((r) => r.done).length;
    return _reads.last.done ? '읽음 · $done회독' : '${_reads.length}회독 읽는 중';
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
                  onChanged: (v) => setState(() {
                    _branch = v ?? '입문';
                    // 줄기를 옮기면 번호도 그 줄기 끝으로. 이미 있는 책은
                    // 사용자가 정한 번호라 건드리지 않는다.
                    if (widget.book == null) {
                      _order.text = '${widget.nextOrder(_branch)}';
                    }
                  }),
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
                const Text('읽은 기록',
                    style: TextStyle(
                        fontSize: AppFont.label,
                        color: AppColors.textSecondary)),
                const Gap(10),
                Pill(_statusLabel, color: _bookColor),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _reads.add(BookRead(
                      start: DateTime(DateTime.now().year,
                          DateTime.now().month, DateTime.now().day)))),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('회독 추가'),
                  style: TextButton.styleFrom(foregroundColor: _bookColor),
                ),
              ]),
              const Gap(6),
              if (_reads.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('아직 기록이 없다 — 「회독 추가」로 시작',
                      style: TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textFaint)),
                ),
              for (var i = 0; i < _reads.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text('${i + 1}회독',
                            style: const TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w800,
                                color: _bookColor)),
                      ),
                      _DateChip(
                        label: '시작',
                        value: _reads[i].start,
                        onTap: () => _pick(i, true),
                        onClear: () => setState(() =>
                            _reads[i] = _reads[i].copyWith(clearStart: true)),
                      ),
                      _DateChip(
                        label: '읽은 날',
                        value: _reads[i].end,
                        onTap: () => _pick(i, false),
                        onClear: () => setState(() =>
                            _reads[i] = _reads[i].copyWith(clearEnd: true)),
                      ),
                      // 날짜를 몰라도 «다 읽었다»는 남길 수 있다.
                      if (_reads[i].end == null)
                        FilterChip(
                          label: const Text('다 읽음',
                              style: TextStyle(fontSize: AppFont.caption)),
                          selected: _reads[i].done,
                          onSelected: (v) => setState(
                              () => _reads[i] = _reads[i].copyWith(done: v)),
                          selectedColor: _bookColor.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surfaceAlt,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      IconButton(
                        tooltip: '이 회독 지우기',
                        onPressed: () => setState(() => _reads.removeAt(i)),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 17, color: AppColors.textFaint),
                      ),
                    ],
                  ),
                ),
              const Text('예전에 읽은 책은 여기서 날짜를 직접 넣는다 · 여러 번 읽었으면 회독을 추가',
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
                minLines: 2,
                maxLines: null,
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
                ...Book.readsPatch(_reads),
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

// ══════════════════════════════════════════════════════════
// 달력 — 언제 무엇을 읽었나
// ══════════════════════════════════════════════════════════

/// 회독 하나를 달력에 놓을 기간으로.
class _Span {
  final Book book;
  final int nth; // 몇 회독
  final DateTime from;
  final DateTime to;
  final bool ongoing;
  final Color color;
  const _Span(this.book, this.nth, this.from, this.to, this.ongoing, this.color);

  bool covers(DateTime d) => !d.isBefore(from) && !d.isAfter(to);
  bool overlaps(DateTime a, DateTime b) => !to.isBefore(a) && !from.isAfter(b);
}

const _spanColors = [
  AppColors.primary, AppColors.sky, AppColors.gold, AppColors.rose,
  AppColors.violet, Color(0xFF14B8A6), Color(0xFFFB923C), Color(0xFFE879F9),
];

class _ReadingCalendar extends StatefulWidget {
  final List<Book> books;
  final void Function(Book) onEdit;
  const _ReadingCalendar({required this.books, required this.onEdit});

  @override
  State<_ReadingCalendar> createState() => _ReadingCalendarState();
}

class _ReadingCalendarState extends State<_ReadingCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day; // 누른 날 — 그날 읽던 책만 아래에 보인다

  // 표지는 base64 라 칸마다 풀면 느리다 — 책마다 한 번만 푼다.
  // 표지를 바꾸면 cover 문자열이 달라지므로 그걸 키로 쓴다.
  final _covers = <String, Uint8List?>{};
  Uint8List? _cover(Book b) =>
      _covers.putIfAbsent('${b.id}:${b.cover?.length}', () => _bytes(b.cover));

  static DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 날짜가 있는 회독만 달력에 오른다. 시작만 있으면 «읽는 중»(오늘까지),
  /// 끝만 있으면 그 하루.
  List<_Span> _spans() {
    final today = _only(DateTime.now());
    final withReads = widget.books.where((b) => b.reads.isNotEmpty).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final out = <_Span>[];
    for (var i = 0; i < withReads.length; i++) {
      final b = withReads[i];
      final color = _spanColors[i % _spanColors.length];
      for (var n = 0; n < b.reads.length; n++) {
        final r = b.reads[n];
        final from = r.start ?? r.end;
        if (from == null) continue;
        final to = r.end ?? (r.done ? from : today);
        out.add(_Span(b, n + 1, _only(from),
            _only(to.isBefore(from) ? from : to), !r.done, color));
      }
    }
    return out;
  }

  String _md(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final spans = _spans();
    final first = _month;
    final last = DateTime(_month.year, _month.month + 1, 0);
    final inMonth = spans.where((s) => s.overlaps(first, last)).toList()
      ..sort((a, b) => a.from.compareTo(b.from));
    final finished = inMonth
        .where((s) => !s.ongoing && !s.to.isBefore(first) && !s.to.isAfter(last))
        .length;
    final reading = inMonth.where((s) => s.ongoing).length;
    final today = _only(DateTime.now());

    // 일요일 시작. 첫 칸 앞을 비운다.
    final lead = first.weekday % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= last.day; d++) DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final shown = _day == null
        ? inMonth
        : inMonth.where((s) => s.covers(_day!)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
                _day = null;
              }),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(children: [
                Text('${_month.year}년 ${_month.month}월',
                    style: const TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w800)),
                const Gap(2),
                Text('다 읽음 $finished권 · 읽는 중 $reading권',
                    style: const TextStyle(
                        fontSize: AppFont.caption, color: AppColors.textFaint)),
              ]),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
                _day = null;
              }),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          const Gap(8),
          Row(children: [
            for (final (i, w) in const ['일', '월', '화', '수', '목', '금', '토'].indexed)
              Expanded(
                child: Center(
                  child: Text(w,
                      style: TextStyle(
                          fontSize: AppFont.micro,
                          fontWeight: FontWeight.w700,
                          color: i == 0
                              ? AppColors.rose
                              : (i == 6 ? AppColors.sky : AppColors.textFaint))),
                ),
              ),
          ]),
          const Gap(6),
          for (var w = 0; w < cells.length ~/ 7; w++)
            Row(children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _dayCell(cells[w * 7 + c], spans, today)),
            ]),
        ]),
      ),
      const Gap(14),
      SectionHeader(
        _day == null ? '이번 달 읽은 책' : '${_md(_day!)} 읽던 책',
        trailing: _day == null
            ? null
            : TextButton(
                onPressed: () => setState(() => _day = null),
                child: const Text('달 전체 보기')),
      ),
      const Gap(8),
      if (shown.isEmpty)
        const EmptyState(
            icon: Icons.calendar_month_rounded,
            message: '이 기간에 읽은 기록이 없어요.\n책 수정 창에서 회독 날짜를 넣으면 여기 표시됩니다.')
      else
        for (final s in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => widget.onEdit(s.book),
              child: Row(children: [
                _Thumb(bytes: _cover(s.book), color: s.color, w: 34, h: 48),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w700)),
                      const Gap(2),
                      Text(
                          s.ongoing
                              ? '${_md(s.from)} 시작 · 읽는 중'
                              : (s.from == s.to
                                  ? '${_md(s.to)} 읽음'
                                  : '${_md(s.from)} ~ ${_md(s.to)}'),
                          style: const TextStyle(
                              fontSize: AppFont.caption,
                              color: AppColors.textFaint)),
                    ],
                  ),
                ),
                Pill('${s.nth}회독', color: s.color),
              ]),
            ),
          ),
    ]);
  }

  /// 하루 칸 — 그날 읽던 책을 색 막대로. 시작한 날은 막대 왼쪽이 둥글고,
  /// 다 읽은 날은 ✓.
  Widget _dayCell(DateTime? d, List<_Span> spans, DateTime today) {
    if (d == null) return const SizedBox(height: 84);
    final on = spans.where((s) => s.covers(d)).toList()
      ..sort((a, b) => a.from.compareTo(b.from));
    final isToday = d == today;
    final picked = _day == d;
    final finishedHere = on.any((s) => !s.ongoing && s.to == d);
    // 표지는 «다 읽은 날»에, 아직 읽는 중이면 «시작한 날»에 붙인다.
    // 기간 전체에 붙이면 칸이 표지로 도배된다 — 기간은 막대가 보여준다.
    final covers = [
      ...on.where((s) => !s.ongoing && s.to == d),
      ...on.where((s) => s.ongoing && s.from == d),
    ];
    return InkWell(
      onTap: () => setState(() => _day = picked ? null : d),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 84,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: picked ? _bookColor.withValues(alpha: 0.18) : null,
          border: Border.all(
              color: isToday ? _bookColor : Colors.transparent, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('${d.day}',
                  style: TextStyle(
                      fontSize: AppFont.micro,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                      color: d.isAfter(today)
                          ? AppColors.textFaint
                          : AppColors.textSecondary)),
              const Spacer(),
              if (finishedHere)
                const Icon(Icons.check_rounded,
                    size: 12, color: AppColors.primary),
            ]),
            const Gap(3),
            if (covers.isNotEmpty) ...[
              // 폰에서는 칸이 46px 남짓 — 들어가는 만큼만 놓고 나머지는 +n.
              LayoutBuilder(builder: (context, c) {
                final room = ((c.maxWidth + 2) / 22).floor().clamp(1, 3);
                final fit = covers.length > room ? room - 1 : covers.length;
                final n = fit < 1 ? 1 : fit;
                return Row(children: [
                  for (final s in covers.take(n)) ...[
                    _Thumb(
                        bytes: _cover(s.book),
                        color: s.color,
                        w: 20,
                        h: 28,
                        faded: s.ongoing),
                    const Gap(2),
                  ],
                  if (covers.length > n)
                    Flexible(
                      child: Text('+${covers.length - n}',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              fontSize: AppFont.micro,
                              color: AppColors.textFaint)),
                    ),
                ]);
              }),
              const Gap(3),
            ],
            for (final s in on.take(covers.isEmpty ? 3 : 2))
              Container(
                height: 5,
                margin: EdgeInsets.only(
                    bottom: 2,
                    left: s.from == d ? 2 : 0,
                    right: s.to == d ? 2 : 0),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: s.ongoing ? 0.55 : 0.9),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(s.from == d ? 3 : 0),
                    right: Radius.circular(s.to == d ? 3 : 0),
                  ),
                ),
              ),
            if (covers.isEmpty && on.length > 3)
              Text('+${on.length - 3}',
                  style: const TextStyle(
                      fontSize: AppFont.micro, color: AppColors.textFaint)),
          ],
        ),
      ),
    );
  }
}

/// 작은 표지. 표지가 없으면 책등 색만 칠한다(칸이 작아 제목은 못 넣는다).
class _Thumb extends StatelessWidget {
  final Uint8List? bytes;
  final Color color;
  final double w;
  final double h;
  final bool faded; // 아직 읽는 중
  const _Thumb({
    required this.bytes,
    required this.color,
    required this.w,
    required this.h,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.6 : 1,
      child: Container(
        width: w,
        height: h,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        ),
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : Align(
                alignment: Alignment.centerLeft,
                child: Container(width: w * 0.18, color: color),
              ),
      ),
    );
  }
}
