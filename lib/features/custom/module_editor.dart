import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/field_spec.dart';
import '../../core/edit/icon_catalog.dart';
import '../../core/edit/record_form.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/custom.dart';

/// 모듈 생성/편집 시트를 띄운다.
Future<void> showModuleEditor(
  BuildContext context,
  WidgetRef ref, {
  CustomModule? existing,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ModuleEditor(existing: existing),
    ),
  );
}

class _ModuleEditor extends ConsumerStatefulWidget {
  final CustomModule? existing;
  const _ModuleEditor({this.existing});

  @override
  ConsumerState<_ModuleEditor> createState() => _ModuleEditorState();
}

class _ModuleEditorState extends ConsumerState<_ModuleEditor> {
  late TextEditingController _name;
  late String _icon;
  late String _color;
  late List<FieldSpec> _fields;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _icon = e?.icon ?? 'widgets';
    _color = e?.colorHex ?? kColorPalette.first;
    _fields = e == null
        ? [const FieldSpec(key: 'title', label: '이름', type: FieldType.text, required: true)]
        : List.of(e.fields);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addOrEditField([int? index]) async {
    final spec = await showFieldEditor(
      context,
      existing: index != null ? _fields[index] : null,
    );
    if (spec == null) return;
    setState(() {
      if (index != null) {
        _fields[index] = spec;
      } else {
        _fields.add(spec);
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모듈 이름을 입력하세요')),
      );
      return;
    }
    setState(() => _saving = true);
    final sb = ref.read(supabaseProvider);
    final payload = {
      'name': name,
      'icon': _icon,
      'color': _color,
      'fields': _fields.map((f) => f.toMap()).toList(),
    };
    try {
      String? newId;
      if (widget.existing == null) {
        final modules = ref.read(customModulesProvider).asData?.value ?? [];
        payload['user_id'] = sb.auth.currentUser!.id;
        payload['sort_order'] = modules.length;
        final inserted =
            await sb.from('custom_modules').insert(payload).select('id').single();
        newId = inserted['id'] as String;
      } else {
        await sb.from('custom_modules').update(payload).eq('id', widget.existing!.id);
      }
      ref.invalidate(customModulesProvider);
      if (mounted) {
        Navigator.pop(context);
        if (newId != null) context.go('/m/$newId');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteModule() async {
    if (!await confirmDelete(context, name: widget.existing!.name)) return;
    await ref.read(supabaseProvider).from('custom_modules').delete().eq('id', widget.existing!.id);
    ref.invalidate(customModulesProvider);
    if (mounted) {
      Navigator.pop(context);
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHex(_color);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(widget.existing == null ? '새 모듈 만들기' : '모듈 설정',
                      style: const TextStyle(
                          fontSize: AppFont.title, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      tooltip: '모듈 삭제',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.rose),
                      onPressed: _deleteModule,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  // 미리보기 + 이름
                  Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(iconFor(_icon), color: accent),
                      ),
                      const Gap(12),
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: '모듈 이름',
                            hintText: '예: 유튜브, 강의, 자동차 …',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(20),
                  const _Label('아이콘'),
                  const Gap(8),
                  _IconPicker(
                    selected: _icon,
                    accent: accent,
                    onSelect: (k) => setState(() => _icon = k),
                  ),
                  const Gap(20),
                  const _Label('색상'),
                  const Gap(8),
                  _ColorPicker(
                    selected: _color,
                    onSelect: (c) => setState(() => _color = c),
                  ),
                  const Gap(24),
                  Row(
                    children: [
                      const _Label('필드'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _addOrEditField(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('필드 추가'),
                      ),
                    ],
                  ),
                  const Gap(4),
                  for (var i = 0; i < _fields.length; i++)
                    _FieldRow(
                      spec: _fields[i],
                      onEdit: () => _addOrEditField(i),
                      onDelete: () => setState(() => _fields.removeAt(i)),
                    ),
                  if (_fields.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('필드를 추가하세요',
                          style: TextStyle(color: AppColors.textFaint)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.existing == null ? '모듈 만들기' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppFont.body));
}

class _IconPicker extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelect;
  const _IconPicker(
      {required this.selected, required this.accent, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in kIconCatalog.entries)
          InkWell(
            onTap: () => onSelect(entry.key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: selected == entry.key
                    ? accent.withValues(alpha: 0.2)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == entry.key ? accent : AppColors.border,
                ),
              ),
              child: Icon(entry.value,
                  size: 20,
                  color: selected == entry.key ? accent : AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _ColorPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in kColorPalette)
          InkWell(
            onTap: () => onSelect(hex),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == hex ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selected == hex
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  final FieldSpec spec;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _FieldRow(
      {required this.spec, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(spec.icon, size: 18, color: AppColors.textSecondary),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(spec.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (spec.required)
                      const Text(' *', style: TextStyle(color: AppColors.rose)),
                  ],
                ),
                Text(kFieldTypeLabels[spec.type] ?? '',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.caption)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 17),
            color: AppColors.textFaint,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 17),
            color: AppColors.textFaint,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 단일 필드 정의 편집 다이얼로그.
Future<FieldSpec?> showFieldEditor(BuildContext context,
    {FieldSpec? existing}) {
  return showDialog<FieldSpec>(
    context: context,
    builder: (_) => _FieldEditorDialog(existing: existing),
  );
}

class _FieldEditorDialog extends StatefulWidget {
  final FieldSpec? existing;
  const _FieldEditorDialog({this.existing});
  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late TextEditingController _label;
  late TextEditingController _options;
  late FieldType _type;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _options =
        TextEditingController(text: widget.existing?.options.join(', ') ?? '');
    _type = widget.existing?.type ?? FieldType.text;
    _required = widget.existing?.required ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) return;
    // key: 기존 유지, 신규는 label 기반 안전 키 + 시간 구분 없이 label 슬러그.
    final key = widget.existing?.key ??
        'f_${label.hashCode.toUnsigned(32).toRadixString(16)}';
    final opts = _type == FieldType.select
        ? _options.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    Navigator.pop(
      context,
      FieldSpec(
          key: key,
          label: label,
          type: _type,
          required: _required,
          options: opts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.existing == null ? '필드 추가' : '필드 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: '필드 이름'),
            ),
            const Gap(14),
            DropdownButtonFormField<FieldType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '타입'),
              dropdownColor: AppColors.surfaceAlt,
              items: [
                for (final t in FieldType.values)
                  DropdownMenuItem(value: t, child: Text(kFieldTypeLabels[t]!)),
              ],
              onChanged: (t) => setState(() => _type = t ?? FieldType.text),
            ),
            if (_type == FieldType.select) ...[
              const Gap(14),
              TextField(
                controller: _options,
                decoration: const InputDecoration(
                  labelText: '선택지 (쉼표로 구분)',
                  hintText: '예: 낮음, 보통, 높음',
                ),
              ),
            ],
            const Gap(6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('필수 입력'),
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}
