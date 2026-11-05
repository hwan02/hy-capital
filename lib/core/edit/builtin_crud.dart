import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';
import '../theme/app_theme.dart';
import 'builtin_specs.dart';
import 'crud.dart';
import 'form_draft.dart';
import 'record_form.dart';

/// 내장 모듈 레코드 추가/수정 폼 → 저장 → 새로고침.
Future<void> editBuiltinRecord(
  BuildContext context,
  WidgetRef ref,
  BuiltinSpec spec, {
  Map<String, dynamic>? initial,
  String? id,
  // 폼에 없는 칸 — 저장할 때 같이 보낸다(예: 계획의 숫자 목표는 갈래가 늘 «목표»).
  Map<String, dynamic> fixed = const {},
  // 저장 직전에 값을 더 채운다(예: 여행지 이름으로 지도 좌표 찾기).
  Future<Map<String, dynamic>> Function(Map<String, dynamic> values)? prepare,
}) async {
  // 새 글은 표마다 하나, 수정은 레코드마다 하나.
  final draftKey = spec.draft ? '${spec.table}:${id ?? 'new'}' : null;
  final values = await showRecordForm(
    context,
    title: id == null ? '${spec.title} 추가' : '${spec.title} 수정',
    fields: spec.fields,
    initial: initial ?? const {},
    accent: spec.accent,
    draftKey: draftKey,
  );
  if (values == null) return;
  // 빈 값(null)은 보내지 않는다 → NOT NULL 컬럼은 DB 기본값(0 등)이 적용된다.
  var clean = Map<String, dynamic>.from(values)
    ..addAll(fixed)
    ..removeWhere((k, v) => v == null);
  try {
    if (prepare != null) clean = await prepare(clean);
    await ref.saveRow(spec.table, clean, id: id);
    // 저장이 «성공한 뒤»에만 임시저장을 지운다.
    if (draftKey != null) await FormDraft.clear(draftKey);
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
