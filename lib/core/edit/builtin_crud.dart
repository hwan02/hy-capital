import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';
import '../theme/app_theme.dart';
import 'builtin_specs.dart';
import 'crud.dart';
import 'record_form.dart';

/// 내장 모듈 레코드 추가/수정 폼 → 저장 → 새로고침.
Future<void> editBuiltinRecord(
  BuildContext context,
  WidgetRef ref,
  BuiltinSpec spec, {
  Map<String, dynamic>? initial,
  String? id,
}) async {
  final values = await showRecordForm(
    context,
    title: id == null ? '${spec.title} 추가' : '${spec.title} 수정',
    fields: spec.fields,
    initial: initial ?? const {},
    accent: spec.accent,
  );
  if (values == null) return;
  // 빈 값(null)은 보내지 않는다 → NOT NULL 컬럼은 DB 기본값(0 등)이 적용된다.
  final clean = Map<String, dynamic>.from(values)
    ..removeWhere((k, v) => v == null);
  try {
    await ref.saveRow(spec.table, clean, id: id);
    invalidateAll(ref);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), backgroundColor: AppColors.rose),
      );
    }
  }
}

/// 내장 모듈 레코드 삭제.
Future<void> deleteBuiltinRecord(
  BuildContext context,
  WidgetRef ref,
  BuiltinSpec spec,
  String id, {
  String? name,
}) async {
  if (!await confirmDelete(context, name: name)) return;
  await ref.deleteRow(spec.table, id);
  invalidateAll(ref);
}

/// 목록 헤더의 "추가" 버튼.
class AddButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final String label;
  const AddButton({
    super.key,
    required this.color,
    required this.onTap,
    this.label = '추가',
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label),
    );
  }
}

/// 카드 우측의 수정/삭제 메뉴.
class RecordMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const RecordMenu({super.key, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded,
          color: AppColors.textFaint, size: 20),
      color: AppColors.surfaceAlt,
      padding: EdgeInsets.zero,
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('수정')),
        PopupMenuItem(value: 'delete', child: Text('삭제')),
      ],
    );
  }
}
