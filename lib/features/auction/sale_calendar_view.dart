// 경공매 달력 — 정비구역(모아·신통) 안에 뜬 경매·공매 물건을 «매각기일»에 꽂아 본다.
//
// 종이 달력에 「2025-51160 신통 OO마을 2.44/1.95」로 적던 것을 그대로 옮겼다.
// 칸(물건)을 누르면 행크옥션으로 가고, 오른쪽 작은 태그를 누르면
// 관심·임장·입찰예정·패스를 단다. 위 칩으로 태그별로 추린다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart' show AddButton;
import '../../core/edit/field_spec.dart';
import '../../core/edit/plain_controller.dart';
import '../../core/edit/record_form.dart' show showRecordForm, confirmDelete;
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/save_key.dart';
import '../../models/models.dart';

const _accent = AppColors.gold;

/// 태그 → 색. 순서가 곧 칩 순서다.
const kSaleTags = <String, Color>{
  '관심': AppColors.sky,
  '임장': AppColors.gold,
  '입찰예정': AppColors.primary,
  '패스': AppColors.textFaint,
};

/// 물건의 행크옥션 주소. 링크를 적어 둔 물건은 그걸 쓰고, 없으면 사건번호로 검색.
/// ※ 검색 주소 형식은 확인 전 — 틀리면 여기 한 곳만 고친다.
String hankUrlOf(SaleItem it) {
  final u = it.url?.trim();
  if (u != null && u.isNotEmpty) return u;
  return 'https://www.hankauction.com/search?keyword=${Uri.encodeComponent(it.caseNo)}';
}

/// 감정가·최저가를 종이 달력처럼 «억» 두 자리로. 348000000 → 3.48
String _eok(double v) => (v / 100000000).toStringAsFixed(2);

class SaleCalendarView extends ConsumerStatefulWidget {
  const SaleCalendarView({super.key});

  @override
  ConsumerState<SaleCalendarView> createState() => _SaleCalendarViewState();
}

class _SaleCalendarViewState extends ConsumerState<SaleCalendarView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _tagF; // null = 전체

  bool _inMonth(SaleItem it) =>
      it.saleDate.year == _month.year && it.saleDate.month == _month.month;

  Future<void> _patch(SaleItem it, Map<String, dynamic> patch) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('sale_items')
          .update(patch)
          .eq('id', it.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패 — $e'), backgroundColor: AppColors.rose),
      );
      return;
    }
    ref.invalidate(saleItemsProvider);
  }

  Future<void> _open(SaleItem it) async {
    final ok = await launchUrl(
      Uri.parse(hankUrlOf(it)),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크를 열지 못했어요')));
    }
  }

  /// 태그·메모·링크 한 창에서. 삭제도 여기서.
  Future<void> _editTag(SaleItem it) async {
    var tag = it.tag;
    final memo = PlainController(text: it.memo ?? '');
    final url = PlainController(text: it.url ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            '${it.zone} · ${it.caseNo}',
            style: const TextStyle(fontSize: AppFont.section),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((it.address ?? '').isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      it.address!,
                      style: const TextStyle(
                        fontSize: AppFont.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const Gap(12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in kSaleTags.entries)
                        ChoiceChip(
                          label: Text(e.key),
                          selected: tag == e.key,
                          selectedColor: e.value.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            fontSize: AppFont.label,
                            fontWeight: FontWeight.w700,
                            color: tag == e.key
                                ? e.value
                                : AppColors.textSecondary,
                          ),
                          onSelected: (_) =>
                              setS(() => tag = tag == e.key ? null : e.key),
                        ),
                    ],
                  ),
                ),
                const Gap(14),
                TextField(
                  controller: memo,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '메모',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
                const Gap(10),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(
                    labelText: '행크옥션 링크 (없으면 사건번호로 검색)',
                    prefixIcon: Icon(Icons.link_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          // Spacer(Expanded)는 actions(OverflowBar) 안에서 못 쓴다 — 회색 깨진 창.
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, 'delete'),
              child: const Text('삭제', style: TextStyle(color: AppColors.rose)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('취소'),
            ),
            SaveKey(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: const Color(0xFF2A1D00),
                ),
                onPressed: () => Navigator.pop(dctx, 'save'),
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || r == null) return;
    if (r == 'delete') {
      if (!await confirmDelete(context, name: '${it.zone} ${it.caseNo}')) {
        return;
      }
      await ref
          .read(supabaseProvider)
          .from('sale_items')
          .delete()
          .eq('id', it.id);
      ref.invalidate(saleItemsProvider);
      return;
    }
    final m = memo.text.trim();
    final u = url.text.trim();
    await _patch(it, {
      'tag': tag,
      'memo': m.isEmpty ? null : m,
      'url': u.isEmpty ? null : u,
    });
  }

  static const _fields = [
    FieldSpec(key: 'zone', label: '구역', type: FieldType.text, required: true),
    FieldSpec(
      key: 'case_no',
      label: '사건·관리번호',
      type: FieldType.text,
      required: true,
    ),
    FieldSpec(
      key: 'source',
      label: '종류',
      type: FieldType.select,
      required: true,
      options: ['경매', '공매'],
    ),
    FieldSpec(
      key: 'sale_date',
      label: '매각기일·입찰마감',
      type: FieldType.date,
      required: true,
    ),
    FieldSpec(key: 'kind', label: '물건종류 (다세대·오피스텔 …)', type: FieldType.text),
    FieldSpec(key: 'appraisal', label: '감정가', type: FieldType.money),
    FieldSpec(key: 'min_price', label: '최저가', type: FieldType.money),
    FieldSpec(key: 'fails', label: '유찰 횟수', type: FieldType.number),
    FieldSpec(key: 'address', label: '주소', type: FieldType.text),
    FieldSpec(key: 'url', label: '행크옥션 링크', type: FieldType.text),
  ];

  Future<void> _add() async {
    final v = await showRecordForm(
      context,
      title: '경공매 물건 추가',
      fields: _fields,
      accent: _accent,
      initial: {
        'source': '경매',
        'sale_date': _month.toIso8601String().substring(0, 10),
      },
    );
    if (v == null || !mounted) return;
    final sb = ref.read(supabaseProvider);
    try {
      await sb.from('sale_items').insert({
        ...v,
        'appraisal': v['appraisal'] ?? 0,
        'min_price': v['min_price'] ?? 0,
        'fails': v['fails'] ?? 0,
        'user_id': sb.auth.currentUser!.id,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가 실패 — $e'), backgroundColor: AppColors.rose),
      );
      return;
    }
    ref.invalidate(saleItemsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(saleItemsProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (all) {
        final monthItems = all.where(_inMonth).toList();
        final shown = monthItems
            .where((it) => _tagF == null || it.tag == _tagF)
            .toList();
        int cnt(String? t) =>
            monthItems.where((it) => t == null || it.tag == t).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 달 이동 + 건수 + 추가 ── 폰 폭에서는 줄을 바꾼다(Wrap).
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 2,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                      ),
                      Text(
                        '${_month.year}년 ${_month.month}월',
                        style: const TextStyle(
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                      ),
                      Text(
                        '${monthItems.length}건',
                        style: const TextStyle(
                          fontSize: AppFont.section,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AddButton(color: _accent, onTap: _add, label: '물건 추가'),
              ],
            ),
            const Gap(10),
            // ── 태그 필터 ──
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(null, '전체 ${cnt(null)}', _accent),
                for (final e in kSaleTags.entries)
                  _chip(e.key, '${e.key} ${cnt(e.key)}', e.value),
              ],
            ),
            const Gap(14),
            if (shown.isEmpty)
              const EmptyState(
                icon: Icons.calendar_month_rounded,
                message: '이 달엔 물건이 없어요 — 「물건 추가」로 넣거나 다른 달을 보세요',
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  return c.maxWidth < 720
                      ? _dayList(shown)
                      : _monthGrid(shown, c.maxWidth);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _chip(String? v, String label, Color c) {
    final on = _tagF == v;
    return InkWell(
      onTap: () => setState(() => _tagF = v),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
            color: on ? c : AppColors.border,
            width: on ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? c : AppColors.textSecondary,
            fontSize: AppFont.label,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── 넓은 화면: 종이 달력처럼 주 단위 격자(월~금, 주말은 물건이 있을 때만) ──
  Widget _monthGrid(List<SaleItem> items, double width) {
    final byDay = <int, List<SaleItem>>{};
    for (final it in items) {
      byDay.putIfAbsent(it.saleDate.day, () => []).add(it);
    }
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final hasWeekend = items.any((it) => it.saleDate.weekday >= 6);
    final cols = hasWeekend ? 7 : 5;
    const gap = 6.0;
    final w = (width - gap * (cols - 1)) / cols;
    final today = DateTime.now();

    // 월요일 시작 주 단위로 자른다.
    final weeks = <List<DateTime?>>[];
    var cur = first.subtract(Duration(days: first.weekday - 1));
    while (!cur.isAfter(DateTime(_month.year, _month.month, daysInMonth))) {
      weeks.add([
        for (var i = 0; i < cols; i++)
          (() {
            final d = cur.add(Duration(days: i));
            return d.month == _month.month ? d : null;
          })(),
      ]);
      cur = cur.add(const Duration(days: 7));
    }
    const names = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < cols; i++)
              SizedBox(
                width: w + (i < cols - 1 ? gap : 0),
                child: Text(
                  names[i],
                  style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700,
                    color: i >= 5 ? AppColors.rose : AppColors.textFaint,
                  ),
                ),
              ),
          ],
        ),
        const Gap(6),
        for (final week in weeks)
          if (week.any((d) => d != null))
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              // 한 주의 칸 높이를 맞추려 stretch — 세로가 무한인 Column 안이라
              // IntrinsicHeight 로 높이를 먼저 잰다(없으면 h=Infinity 로 터진다).
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cols; i++) ...[
                      SizedBox(
                        width: w,
                        child: week[i] == null
                            ? const SizedBox.shrink()
                            : _dayCell(
                                week[i]!,
                                byDay[week[i]!.day] ?? const [],
                                isToday:
                                    week[i]!.year == today.year &&
                                    week[i]!.month == today.month &&
                                    week[i]!.day == today.day,
                              ),
                      ),
                      if (i < cols - 1) const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _dayCell(DateTime d, List<SaleItem> items, {required bool isToday}) {
    final past = d.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: items.isEmpty
            ? AppColors.surface.withValues(alpha: 0.5)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday ? _accent : AppColors.border,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w800,
                  color: isToday
                      ? _accent
                      : (past ? AppColors.textFaint : AppColors.textSecondary),
                ),
              ),
              if (items.isNotEmpty) ...[
                const Gap(6),
                Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ],
          ),
          const Gap(6),
          for (final it in items) ...[_itemChip(it, dim: past), const Gap(5)],
        ],
      ),
    );
  }

  // ── 좁은 화면(폰): 날짜별 목록 ──
  Widget _dayList(List<SaleItem> items) {
    final days = <DateTime, List<SaleItem>>{};
    for (final it in items) {
      final k = DateTime(it.saleDate.year, it.saleDate.month, it.saleDate.day);
      days.putIfAbsent(k, () => []).add(it);
    }
    final keys = days.keys.toList()..sort();
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in keys) ...[
          Row(
            children: [
              Text(
                '${d.month}.${d.day} (${names[d.weekday - 1]})',
                style: const TextStyle(
                  fontSize: AppFont.section,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(8),
              Text(
                Dates.dday(d),
                style: const TextStyle(
                  fontSize: AppFont.label,
                  color: AppColors.textSecondary,
                ),
              ),
              const Gap(8),
              Text(
                '${days[d]!.length}건',
                style: const TextStyle(
                  fontSize: AppFont.label,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
          const Gap(8),
          for (final it in days[d]!) ...[_itemChip(it), const Gap(6)],
          const Gap(10),
        ],
      ],
    );
  }

  /// 물건 한 칸. 본체 = 행크옥션 열기 · 오른쪽 태그 = 태그 바꾸기.
  Widget _itemChip(SaleItem it, {bool dim = false}) {
    final tagColor = kSaleTags[it.tag];
    final c = tagColor ?? AppColors.border;
    final isPass = it.tag == '패스';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(it),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          decoration: BoxDecoration(
            color: (tagColor ?? AppColors.surfaceAlt).withValues(
              alpha: tagColor == null ? 1 : 0.10,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: c, width: 3)),
          ),
          child: Opacity(
            opacity: dim || isPass ? 0.55 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1줄: 사건번호 · 경/공 · 구역
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: it.caseNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: '  ${it.source == '공매' ? '공' : '경'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: it.source == '공매'
                                    ? AppColors.violet
                                    : AppColors.sky,
                              ),
                            ),
                            TextSpan(
                              text: '  ${it.zone}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: AppFont.caption),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      // 2줄: 감정/최저(억) · 유찰 — 종이 달력의 「2.44/1.95」
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '${_eok(it.appraisal)}/${_eok(it.minPrice)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (it.fails > 0)
                              TextSpan(
                                text: '  유찰${it.fails}',
                                style: TextStyle(
                                  color: it.fails >= 3
                                      ? AppColors.rose
                                      : AppColors.textFaint,
                                ),
                              ),
                            if ((it.kind ?? '').isNotEmpty)
                              TextSpan(
                                text: '  ${it.kind}',
                                style: const TextStyle(
                                  color: AppColors.textFaint,
                                ),
                              ),
                          ],
                        ),
                        style: const TextStyle(fontSize: AppFont.caption),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((it.memo ?? '').isNotEmpty) ...[
                        const Gap(2),
                        Text(
                          it.memo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFont.micro,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(4),
                // 태그 — 누르면 바꾸기. 없으면 「+」.
                Tooltip(
                  message: '태그 · 메모 · 링크',
                  child: InkWell(
                    onTap: () => _editTag(it),
                    borderRadius: BorderRadius.circular(12),
                    child: it.tag == null
                        ? const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.label_outline_rounded,
                              size: 16,
                              color: AppColors.textFaint,
                            ),
                          )
                        : Pill(it.tag!, color: c),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
