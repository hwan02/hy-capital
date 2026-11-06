// 경공매 달력 — 정비구역(모아·신통) 안에 뜬 경매·공매 물건을 «매각기일»에 꽂아 본다.
//
// 종이 달력에 「2025-51160 신통 OO마을 2.44/1.95」로 적던 것을 그대로 옮겼다.
// 칸(물건)을 누르면 행크옥션으로 가고, 오른쪽 작은 태그를 누르면
// 관심·임장·입찰예정·패스를 단다. 위 칩으로 태그별로 추린다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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

/// 행크옥션(hauction.co.kr — hankauction.com 이 아니다) 사건번호 검색 주소.
/// 사이트 검색창에 넣었을 때 실제로 가는 주소를 그대로 쓴다(2026-11-05 확인).
///   경매 2025타경9749     → /search/auction?unique_year=2025&unique_number=9749
///   공매 2026-10740-004   → /search/public-auction?unique_id=2026-10740-004
/// 경매는 법원을 안 가려서 같은 번호가 다른 법원에 있으면 두어 건이 같이 뜬다.
String hankSearchUrl(String caseNo, {String source = '경매'}) {
  const status = '&status=%EC%A0%84%EC%B2%B4%EB%B3%B4%EA%B8%B0'; // 전체보기
  final c = caseNo.trim();
  final m = RegExp(r'^(\d{4})\s*타경\s*(\d+)').firstMatch(c);
  if (m != null) {
    return 'https://www.hauction.co.kr/search/auction'
        '?unique_year=${m.group(1)}&unique_number=${m.group(2)}$status';
  }
  if (source == '공매' || RegExp(r'^\d{4}-\d+-\d+$').hasMatch(c)) {
    return 'https://www.hauction.co.kr/search/public-auction'
        '?unique_id=${Uri.encodeComponent(c)}$status';
  }
  return 'https://www.hauction.co.kr/search/auction'
      '?unique_year=&unique_number=${Uri.encodeComponent(c)}$status';
}

/// 물건의 행크옥션 주소 — 적어 둔 링크가 있으면 그것, 없으면 사건번호 검색.
String hankUrlOf(SaleItem it) {
  final u = it.url?.trim();
  return (u == null || u.isEmpty)
      ? hankSearchUrl(it.caseNo, source: it.source)
      : u;
}

/// 상세 창 버튼 — 모두 같은 높이(44)·같은 모서리.
final _sheetBtn = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(44),
  foregroundColor: AppColors.textPrimary,
  side: const BorderSide(color: AppColors.border),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  textStyle: const TextStyle(fontSize: AppFont.label, fontWeight: FontWeight.w700),
);

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

  /// 행크옥션 열기 — 적어 둔 링크 또는 사건번호 검색 결과(웹).
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

  /// 사건번호 복사 — 행크옥션 앱은 바깥 링크를 안 받는다(com.hank.hankauction 에
  /// intent:// 로 지정해도 웹으로 떨어졌다, 2026-11-06 폴드에서 확인). 앱에서 붙여넣기.
  Future<void> _copyCase(SaleItem it) async {
    await Clipboard.setData(ClipboardData(text: it.caseNo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('«${it.caseNo}» 복사됨 — 행크옥션 앱 검색창에 붙여넣기')));
  }

  /// 물건 상세 — 정보·태그·메모·링크 한 창에서. 행크옥션 열기와 삭제도 여기서.
  Future<void> _editTag(SaleItem it) async {
    var tag = it.tag;
    final memo = PlainController(text: it.memo ?? '');
    final url = PlainController(text: it.url ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          // 폰에서 좌우 여백이 커서 창이 좁았다 — 16 만 남긴다.
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                const Gap(6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${Dates.ymd(it.saleDate)} ${Dates.dday(it.saleDate)} · '
                    '감정 ${Won.compact(it.appraisal)} / 최저 ${Won.compact(it.minPrice)}'
                    '${it.fails > 0 ? ' · 유찰 ${it.fails}' : ''}'
                    '${(it.kind ?? '').isNotEmpty ? ' · ${it.kind}' : ''} · ${it.source}',
                    style: const TextStyle(
                      fontSize: AppFont.label,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Gap(10),
                // 버튼·태그는 한 줄씩, 칸마다 같은 높이·같은 폭(크기가 제각각이었다).
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: _sheetBtn,
                      onPressed: () => _copyCase(it),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('사건번호 복사'),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: _sheetBtn,
                      onPressed: () => _open(it),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('웹으로 열기'),
                    ),
                  ),
                ]),
                const Gap(14),
                Row(children: [
                  for (final e in kSaleTags.entries) ...[
                    if (e.key != kSaleTags.keys.first) const Gap(6),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setS(() => tag = tag == e.key ? null : e.key),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tag == e.key
                                ? e.value.withValues(alpha: 0.22)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: tag == e.key ? e.value : AppColors.border),
                          ),
                          child: Text(e.key,
                              style: TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w800,
                                color: tag == e.key
                                    ? e.value
                                    : AppColors.textSecondary,
                              )),
                        ),
                      ),
                    ),
                  ],
                ]),
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
                    labelText: '행크옥션 링크',
                    hintText: '비우면 사건번호로 검색',
                    prefixIcon: Icon(Icons.link_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          // Spacer(Expanded)는 actions(OverflowBar) 안에서 못 쓴다 — 회색 깨진 창.
          // 아래 세 버튼도 같은 높이 한 줄로 — 삭제 · 취소 · 저장.
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: _sheetBtn.copyWith(
                    foregroundColor:
                        const WidgetStatePropertyAll(AppColors.rose),
                  ),
                  onPressed: () => Navigator.pop(dctx, 'delete'),
                  child: const Text('삭제'),
                ),
              ),
              const Gap(8),
              Expanded(
                child: OutlinedButton(
                  style: _sheetBtn,
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text('취소'),
                ),
              ),
              const Gap(8),
              Expanded(
                child: SaveKey(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF2A1D00),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(dctx, 'save'),
                    child: const Text('저장'),
                  ),
                ),
              ),
            ]),
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

  /// 물건 한 칸. 누르면 상세·태그·메모 창(거기서 행크옥션·삭제).
  Widget _itemChip(SaleItem it, {bool dim = false}) {
    final tagColor = kSaleTags[it.tag];
    final c = tagColor ?? AppColors.border;
    final isPass = it.tag == '패스';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _editTag(it),
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
                // 태그 표시 — 바꾸는 건 칸을 눌러 뜨는 창에서.
                if (it.tag != null) Pill(it.tag!, color: c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
