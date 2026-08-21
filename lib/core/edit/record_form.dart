import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../format/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/money_field.dart';
import 'field_spec.dart';

/// 정수를 천단위 콤마 문자열로.

/// 금액 필드 초기 텍스트(콤마 적용).
String _moneyInitText(dynamic v) {
  if (v == null) return '';
  final n = v is num ? v : num.tryParse(v.toString());
  return n == null ? v.toString() : moneyComma(n);
}


/// 필드 정의로부터 입력 폼(모달 시트)을 만들어 값을 편집한다.
/// 저장 시 { key: value } 맵을 반환, 취소 시 null.
Future<Map<String, dynamic>?> showRecordForm(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, dynamic> initial = const {},
  Color accent = AppColors.primary,
}) {
  // 넓은 화면은 가운데 큰 모달(수정하기 쉬움), 좁은 화면은 하단 시트.
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final form = _RecordForm(
    title: title,
    fields: fields,
    initial: initial,
    accent: accent,
    inDialog: wide,
  );
  if (wide) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: form,
        ),
      ),
    );
  }
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: form,
    ),
  );
}

class _RecordForm extends StatefulWidget {
  final String title;
  final List<FieldSpec> fields;
  final Map<String, dynamic> initial;
  final Color accent;
  final bool inDialog;

  const _RecordForm({
    required this.title,
    required this.fields,
    required this.initial,
    required this.accent,
    this.inDialog = false,
  });

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _values = {...widget.initial};
    for (final f in widget.fields) {
      if (f.type == FieldType.boolean || f.type == FieldType.date) continue;
      final v = _values[f.key];
      _controllers[f.key] = TextEditingController(
          text: f.type == FieldType.money
              ? _moneyInitText(v)
              : (v?.toString() ?? ''));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.boolean:
          out[f.key] = _values[f.key] ?? false;
          break;
        case FieldType.date:
        case FieldType.select:
          // 드롭다운/날짜 값은 컨트롤러가 아니라 _values 에 담긴다.
          out[f.key] = _values[f.key];
          break;
        case FieldType.money:
        case FieldType.number:
        case FieldType.percent:
          final raw = _controllers[f.key]!.text.replaceAll(',', '').trim();
          out[f.key] = raw.isEmpty ? null : num.tryParse(raw);
          break;
        default:
          final t = _controllers[f.key]!.text.trim();
          out[f.key] = t.isEmpty ? null : t;
      }
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.inDialog) ...[
              const Gap(12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: AppFont.title, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final f in widget.fields) ...[
                        _buildField(f),
                        const Gap(18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: widget.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _submit,
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(FieldSpec f) {
    switch (f.type) {
      case FieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          activeThumbColor: widget.accent,
          value: _values[f.key] == true,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );

      case FieldType.date:
        final cur = _values[f.key] == null
            ? null
            : DateTime.tryParse(_values[f.key].toString());
        return InkWell(
          onTap: () async {
            final picked = await pickDay(context, initial: cur);
            if (picked != null) {
              setState(() => _values[f.key] =
                  picked.toIso8601String().substring(0, 10));
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              prefixIcon: Icon(f.icon, size: 20),
            ),
            child: Text(
              cur == null ? '날짜 선택' : Dates.ymd(cur),
              style: TextStyle(
                color: cur == null
                    ? AppColors.textFaint
                    : AppColors.textPrimary,
              ),
            ),
          ),
        );

      case FieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: _values[f.key]?.toString(),
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(f.icon, size: 20),
          ),
          dropdownColor: AppColors.surfaceAlt,
          items: [
            for (final o in f.options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          validator: (v) =>
              f.required && (v == null || v.isEmpty) ? '필수 항목입니다' : null,
          onChanged: (v) => _values[f.key] = v,
        );

      case FieldType.longtext:
        return TextFormField(
          controller: _controllers[f.key],
          maxLines: 3,
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(f.icon, size: 20),
            alignLabelWithHint: true,
          ),
          validator: (v) =>
              f.required && (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null,
        );

      case FieldType.money:
        // 원화 금액: 콤마 자동 + 오른쪽에 실시간 '만원' 환산.
        final ctrl = _controllers[f.key]!;
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (context, value, _) {
            final digits = value.text.replaceAll(RegExp(r'[^0-9]'), '');
            final n = digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
            return TextFormField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: const [MoneyInputFormatter()],
              decoration: InputDecoration(
                labelText: f.label,
                prefixIcon: Icon(f.icon, size: 20),
                suffixText: n > 0 ? '${Won.compact(n)}원' : '원',
                suffixStyle: n > 0
                    ? const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: AppFont.body)
                    : const TextStyle(color: AppColors.textFaint),
              ),
              validator: (v) => f.required && (v == null || v.trim().isEmpty)
                  ? '필수 항목입니다'
                  : null,
            );
          },
        );

      case FieldType.number:
      case FieldType.percent:
        return TextFormField(
          controller: _controllers[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
          ],
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(f.icon, size: 20),
            suffixText: f.type == FieldType.percent ? '%' : null,
          ),
          validator: (v) {
            if (f.required && (v == null || v.trim().isEmpty)) {
              return '필수 항목입니다';
            }
            if (v != null && v.trim().isNotEmpty) {
              final n = num.tryParse(v.replaceAll(',', '').trim());
              if (n == null) return '숫자를 입력하세요';
            }
            return null;
          },
        );

      case FieldType.text:
        return TextFormField(
          controller: _controllers[f.key],
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: Icon(f.icon, size: 20),
          ),
          validator: (v) =>
              f.required && (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null,
        );
    }
  }
}

/// 일(day) 선택 달력 — 한 번 탭하면 선택(하이라이트), 더블클릭하면 선택+닫기.
Future<DateTime?> pickDay(BuildContext context, {DateTime? initial}) {
  final base = initial ?? DateTime.now();
  var month = DateTime(base.year, base.month);
  DateTime? selected = initial;
  bool same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final first = DateTime(month.year, month.month, 1);
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final leading = first.weekday % 7; // 일요일 시작
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1)),
              ),
              Text('${month.year}년 ${month.month}월',
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (final w in ['일', '월', '화', '수', '목', '금', '토'])
                      Expanded(
                        child: Center(
                          child: Text(w,
                              style: const TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: AppFont.label,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
                const Gap(6),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  children: [
                    for (var i = 0; i < leading; i++) const SizedBox(),
                    for (var d = 1; d <= daysInMonth; d++)
                      Builder(builder: (_) {
                        final date = DateTime(month.year, month.month, d);
                        final isSel = selected != null && same(selected!, date);
                        return GestureDetector(
                          onTap: () => setState(() => selected = date),
                          onDoubleTap: () => Navigator.pop(ctx, date),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text('$d',
                                style: TextStyle(
                                    color: isSel
                                        ? const Color(0xFF04130A)
                                        : AppColors.textPrimary,
                                    fontWeight: isSel
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    fontSize: AppFont.body)),
                          ),
                        );
                      }),
                  ],
                ),
                const Gap(6),
                const Text('날짜를 더블클릭하면 바로 선택돼요',
                    style:
                        TextStyle(color: AppColors.textFaint, fontSize: AppFont.caption)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            FilledButton(
                onPressed:
                    selected == null ? null : () => Navigator.pop(ctx, selected),
                child: const Text('선택')),
          ],
        );
      },
    ),
  );
}

/// 월 전용 선택기 (연도 이동 + 12개월 버튼). 일(day) 선택 없이 해당 월만.
Future<DateTime?> pickMonth(BuildContext context, {DateTime? initial}) {
  var year = (initial ?? DateTime.now()).year;
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => year--),
            ),
            Text('$year년',
                style: const TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() => year++),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              for (var mth = 1; mth <= 12; mth++)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceAlt,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(ctx, DateTime(year, mth)),
                  child: Text('$mth월'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 연도 선택기 (연도만 고른다).
Future<int?> pickYear(BuildContext context, {int? initial}) {
  var year = initial ?? DateTime.now().year;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('연도 선택'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => year--),
            ),
            Text('$year년',
                style: const TextStyle(fontSize: AppFont.display, fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() => year++),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, year),
              child: const Text('확인')),
        ],
      ),
    ),
  );
}

/// 삭제 확인 다이얼로그.
Future<bool> confirmDelete(BuildContext context, {String? name}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('삭제할까요?'),
      content: Text(name == null ? '이 항목을 삭제합니다.' : '“$name” 을(를) 삭제합니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
