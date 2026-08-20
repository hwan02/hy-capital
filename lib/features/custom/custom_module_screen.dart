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
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/custom.dart';
import 'module_editor.dart';

class CustomModuleScreen extends ConsumerWidget {
  final String moduleId;
  const CustomModuleScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(customModulesProvider);
    final module = modulesAsync.asData?.value
        .where((m) => m.id == moduleId)
        .cast<CustomModule?>()
        .firstWhere((m) => true, orElse: () => null);

    if (module == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final accent = colorFromHex(module.colorHex);
    final recordsAsync = ref.watch(customRecordsProvider(moduleId));

    return ModulePage(
      title: module.name,
      icon: iconFor(module.icon),
      color: accent,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '모듈 설정',
            icon: const Icon(Icons.settings_rounded, size: 20),
            onPressed: () => showModuleEditor(context, ref, existing: module),
          ),
          const Gap(4),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => _editRecord(context, ref, module, null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('추가'),
          ),
        ],
      ),
      children: [
        recordsAsync.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (records) {
            if (module.fields.isEmpty) {
              return _EmptyFields(
                onConfig: () => showModuleEditor(context, ref, existing: module),
              );
            }
            if (records.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: EmptyState(
                  icon: iconFor(module.icon),
                  message: '“추가” 를 눌러 첫 항목을 등록하세요',
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in records) ...[
                  _RecordCard(
                    module: module,
                    record: r,
                    accent: accent,
                    onEdit: () => _editRecord(context, ref, module, r),
                    onDelete: () => _deleteRecord(context, ref, r),
                  ),
                  const Gap(12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _editRecord(BuildContext context, WidgetRef ref,
      CustomModule module, CustomRecord? record) async {
    final values = await showRecordForm(
      context,
      title: record == null ? '${module.name} 추가' : '${module.name} 수정',
      fields: module.fields,
      initial: record?.data ?? {},
      accent: colorFromHex(module.colorHex),
    );
    if (values == null) return;
    final sb = ref.read(supabaseProvider);
    if (record == null) {
      await sb.from('custom_records').insert({
        'module_id': module.id,
        'user_id': sb.auth.currentUser!.id,
        'data': values,
      });
    } else {
      await sb.from('custom_records').update({'data': values}).eq('id', record.id);
    }
    ref.invalidate(customRecordsProvider(module.id));
  }

  Future<void> _deleteRecord(
      BuildContext context, WidgetRef ref, CustomRecord record) async {
    if (!await confirmDelete(context)) return;
    await ref.read(supabaseProvider).from('custom_records').delete().eq('id', record.id);
    ref.invalidate(customRecordsProvider(record.moduleId));
  }
}

class _RecordCard extends StatelessWidget {
  final CustomModule module;
  final CustomRecord record;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.module,
    required this.record,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final first = module.fields.isNotEmpty ? module.fields.first : null;
    final titleVal = first != null ? record.data[first.key] : null;
    final rest = module.fields.skip(1).toList();

    return GlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (titleVal == null || titleVal.toString().isEmpty)
                      ? '(제목 없음)'
                      : titleVal.toString(),
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w700),
                ),
              ),
              _MenuButton(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          if (rest.isNotEmpty) ...[
            const Gap(12),
            Wrap(
              spacing: 22,
              runSpacing: 12,
              children: [
                for (final f in rest)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: AppFont.caption)),
                      const Gap(3),
                      Text(f.display(record.data[f.key]),
                          style: const TextStyle(
                              fontSize: AppFont.body, fontWeight: FontWeight.w700)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MenuButton({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textFaint),
      color: AppColors.surfaceAlt,
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('수정')),
        PopupMenuItem(value: 'delete', child: Text('삭제')),
      ],
    );
  }
}

class _EmptyFields extends StatelessWidget {
  final VoidCallback onConfig;
  const _EmptyFields({required this.onConfig});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          const EmptyState(
              icon: Icons.tune_rounded, message: '아직 필드가 없습니다.\n모듈 설정에서 필드를 추가하세요'),
          const Gap(8),
          FilledButton.icon(
            onPressed: onConfig,
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('필드 설정'),
          ),
        ],
      ),
    );
  }
}
