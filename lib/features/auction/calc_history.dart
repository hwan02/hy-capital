// 계산 이력 — 저장·목록·불러오기·삭제.
//
// 경매 계산기와 정비구역 계산기가 같은 테이블(calc_records)을 쓴다.
// 어느 쪽 이력인지는 inputs 안의 «_kind» 로 구분한다(컬럼을 늘리지 않으려고).
// 그래서 목록은 항상 kind 로 걸러서 보여준다 — 경매 탭에 정비구역 이력이
// 섞여 나오면 낙찰가/매매가가 뒤섞여 읽을 수 없다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';

/// 이력 저장/수정. 성공하면 저장된 행의 id를 돌려준다(새 저장일 때만 새 id).
Future<String?> saveCalcRecord(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  required String label,
  required Map<String, dynamic> inputs,
  String? editingId,
}) async {
  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return null;
  final body = {
    'label': label.trim().isEmpty
        ? '계산 ${DateTime.now().toString().substring(5, 16)}'
        : label.trim(),
    'inputs': {'_kind': kind, ...inputs},
  };
  try {
    String? id = editingId;
    if (editingId != null) {
      await sb.from('calc_records').update(body).eq('id', editingId);
    } else {
      final row = await sb
          .from('calc_records')
          .insert({'user_id': uid, ...body})
          .select()
          .single();
      id = row['id'] as String;
    }
    ref.invalidate(calcRecordsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('계산 이력 저장됨'), backgroundColor: AppColors.gold));
    }
    return id;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
    }
    return editingId;
  }
}

Future<void> deleteCalcRecord(WidgetRef ref, String id) async {
  await ref.read(supabaseProvider).from('calc_records').delete().eq('id', id);
  ref.invalidate(calcRecordsProvider);
}

/// 이력 목록. [summary] 는 카드 두 번째 줄, [trailing] 은 우측 배지(판정 등).
class CalcHistory extends ConsumerWidget {
  final String kind;
  final String? editingId;
  final String Function(CalcRecord) summary;
  final Widget? Function(CalcRecord)? badge;
  final void Function(CalcRecord) onLoad;
  final void Function(String id) onDelete;

  const CalcHistory({
    super.key,
    required this.kind,
    required this.editingId,
    required this.summary,
    required this.onLoad,
    required this.onDelete,
    this.badge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(calcRecordsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('계산 이력'),
      const Gap(10),
      history.when(
        loading: AsyncStatus.loading,
        error: (e, _) =>
            Text('불러오기 실패: $e', style: const TextStyle(color: AppColors.rose)),
        data: (all) {
          final list = all.where((r) => r.kind == kind).toList();
          if (list.isEmpty) {
            return const Text(
                '저장된 계산이 없어요. 위에서 계산하고 «이력 저장»을 눌러보세요.',
                style: TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.label));
          }
          return Column(children: [for (final r in list) _row(r)]);
        },
      ),
    ]);
  }

  Widget _row(CalcRecord r) {
    final editing = editingId == r.id;
    final mark = badge?.call(r);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        accent: editing ? AppColors.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(r.label.isEmpty ? '(무제)' : r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.w700)),
                ),
                if (mark != null) ...[const Gap(8), mark],
              ]),
              const Gap(3),
              Text(summary(r),
                  style: const TextStyle(
                      fontSize: AppFont.caption, color: AppColors.textSecondary)),
            ]),
          ),
          TextButton(
            onPressed: () => onLoad(r),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: const Text('불러오기/수정'),
          ),
          IconButton(
            onPressed: () => onDelete(r.id),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 19, color: AppColors.textFaint),
            tooltip: '삭제',
          ),
        ]),
      ),
    );
  }
}
