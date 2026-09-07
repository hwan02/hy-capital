// 임장예정 — 모아타운·신통에서 「임장 담기」로 찍어둔 구역만 모아 본다.
//
// 구역이 139곳이라 화면에서 훑는 것만으로는 「어디 갈지」가 안 남는다.
// 눈에 걸린 자리를 그 자리에서 찍고, 여기서 자치구별로 묶어 «동선»을 잡는다.
// 같은 구 안의 구역은 하루에 묶어서 돈다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import 'buy_band.dart';

const _visitColor = AppColors.gold;

class VisitPlanView extends ConsumerStatefulWidget {
  const VisitPlanView({super.key});

  @override
  ConsumerState<VisitPlanView> createState() => _VisitPlanViewState();
}

class _VisitPlanViewState extends ConsumerState<VisitPlanView> {
  Future<void> _save(Zone z, Map<String, dynamic> patch) async {
    try {
      await ref.read(supabaseProvider).from('zones').update(patch).eq('id', z.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패 — $e'), backgroundColor: AppColors.rose));
      return;
    }
    ref.invalidate(zonesProvider);
  }

  Future<void> _pickDate(Zone z) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: z.visitOn ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null) return;
    _save(z, {'visit_on': d.toIso8601String().substring(0, 10)});
  }

  Future<void> _editMemo(Zone z) async {
    final c = TextEditingController(text: z.visitMemo ?? '');
    final ok = await showDialog<bool>(
      context: context,
      // builder 의 context 로 pop 해야 «다이얼로그»가 닫힌다.
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${z.name} — 임장 메모',
            style: const TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: c,
            autofocus: true,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(
                hintText: '무엇을 보러 가나 — 부동산 3곳 시세, 노후도, 골목 폭, 주차'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _visitColor,
                  foregroundColor: const Color(0xFF1B1400)),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('저장')),
        ],
      ),
    );
    final v = c.text.trim();
    c.dispose();
    if (ok != true) return;
    _save(z, {'visit_memo': v.isEmpty ? null : v});
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(zonesProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (all) {
        final list = all.where((z) => z.visitPlan).toList();
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.directions_walk_rounded,
            message: '임장 갈 곳이 없어요.\n'
                '모아타운·신통기획에서 구역 카드의 「임장 담기」를 누르면 여기 모입니다.',
          );
        }
        // 자치구로 묶는다 — 같은 구는 하루에 돈다.
        final byDist = <String, List<Zone>>{};
        for (final z in list) {
          byDist.putIfAbsent(z.district ?? '기타', () => []).add(z);
        }
        final dists = byDist.keys.toList()
          ..sort((a, b) => byDist[b]!.length.compareTo(byDist[a]!.length));
        final dated = list.where((z) => z.visitOn != null).toList()
          ..sort((a, b) => a.visitOn!.compareTo(b.visitOn!));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 요약 — 몇 곳, 몇 개 구, 날짜 잡은 게 몇 곳
            GlassCard(
              accent: _visitColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                const Icon(Icons.directions_walk_rounded,
                    size: 20, color: _visitColor),
                const Gap(11),
                Expanded(
                  child: Text(
                      '${list.length}곳 · ${dists.length}개 구'
                      '${dated.isEmpty ? '' : ' · 날짜 잡은 것 ${dated.length}곳'}',
                      style: const TextStyle(
                          fontSize: AppFont.section,
                          fontWeight: FontWeight.w900)),
                ),
                if (dated.isNotEmpty)
                  Text('가장 빠른 날 ${Dates.ymd(dated.first.visitOn!)}',
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700,
                          color: _visitColor)),
              ]),
            ),
            const Gap(16),
            for (final d in dists) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded,
                      size: 17, color: _visitColor),
                  const Gap(6),
                  Text(d,
                      style: const TextStyle(
                          fontSize: AppFont.section,
                          fontWeight: FontWeight.w900)),
                  const Gap(8),
                  Text('${byDist[d]!.length}곳',
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          color: AppColors.textSecondary)),
                ]),
              ),
              for (final z in byDist[d]!) ...[
                _VisitCard(
                  zone: z,
                  onDate: () => _pickDate(z),
                  onMemo: () => _editMemo(z),
                  onDrop: () => _save(z, {'visit_plan': false}),
                ),
                const Gap(10),
              ],
              const Gap(8),
            ],
          ],
        );
      },
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Zone zone;
  final VoidCallback onDate;
  final VoidCallback onMemo;
  final VoidCallback onDrop;

  const _VisitCard({
    required this.zone,
    required this.onDate,
    required this.onMemo,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final z = zone;
    final b = bandOfZone(z);
    return GlassCard(
      accent: _visitColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(z.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w900)),
            ),
            IconButton(
              tooltip: '임장 목록에서 빼기',
              onPressed: onDrop,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textFaint),
            ),
          ]),
          const Gap(8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill(z.kind, color: z.isSin ? AppColors.violet : const Color(0xFF14B8A6)),
            Pill(b.label, color: b.color),
            Pill('단계 ${z.stage} · ${z.stageLabel}', color: AppColors.sky),
            if (z.rightsDate != null)
              Pill('권리산정 ${Dates.ymd(z.rightsDate!)}', color: AppColors.rose),
          ]),
          const Gap(12),
          Row(children: [
            _Act(
              icon: Icons.event_rounded,
              label: z.visitOn == null ? '날짜 잡기' : Dates.ymd(z.visitOn!),
              on: z.visitOn != null,
              onTap: onDate,
            ),
            const Gap(8),
            _Act(
              icon: Icons.edit_note_rounded,
              label: (z.visitMemo?.isNotEmpty ?? false) ? '메모 있음' : '메모',
              on: z.visitMemo?.isNotEmpty ?? false,
              onTap: onMemo,
            ),
            const Gap(8),
            _Act(
              icon: Icons.map_rounded,
              label: '지도',
              on: false,
              onTap: () => launchUrl(
                Uri.parse(
                    'https://map.naver.com/p/search/${Uri.encodeComponent('서울 ${z.district ?? ''} ${z.name}')}'),
                webOnlyWindowName: '_blank',
              ),
            ),
          ]),
          if (z.visitMemo?.isNotEmpty ?? false) ...[
            const Gap(10),
            Text(z.visitMemo!,
                style: const TextStyle(
                    fontSize: AppFont.body,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _Act extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Act(
      {required this.icon,
      required this.label,
      required this.on,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _visitColor.withValues(alpha: 0.16) : AppColors.surfaceAlt,
          border: Border.all(color: on ? _visitColor : AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 15, color: on ? _visitColor : AppColors.textSecondary),
          const Gap(6),
          Text(label,
              style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w700,
                  color: on ? _visitColor : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
