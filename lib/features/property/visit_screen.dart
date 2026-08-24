// 임장 — 현장에서 폰으로 쓴다.
//
// 임장은 «단지»에 붙는다. 매물이 없어도 간다 (급매를 만날 수 있으니).
//
// 현장에서 편해야 하는 것:
//   · 한 손 · 큰 체크박스 · 사진은 «항목»에 붙는다
//   · 긴 글은 안 쓴다 — 한 줄 메모
//   · 부동산에서 들은 시세는 그 자리에서 넣으면 «시세조사의 현장 칸»으로 간다
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_field.dart';
import '../../models/models.dart';

const _bucket = 'knowledge';

/// 임장 체크 항목 — 자료실 조사표와 강의 기준에서 뽑았다.
/// (키, 라벨) — 키는 DB의 checks 맵에 그대로 쓰인다.
const visitChecks = <(String, String)>[
  ('exterior', '건물 외관 · 균열/누수'),
  ('around', '주변 환경 · 경사/접근'),
  ('entrance', '공동현관 · 주차'),
  ('occupancy', '점유 상태 · 우편물/계량기'),
  ('zone_mood', '구역 분위기 · 현수막/동의'),
  ('agents', '부동산 방문'),
];

/// 임장을 새로 시작한다. 성공하면 그 화면으로 이동.
Future<void> startVisit(
    BuildContext context, WidgetRef ref, Complex complex) async {
  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final row = await sb
        .from('visits')
        .insert({'user_id': uid, 'complex_id': complex.id})
        .select()
        .single();
    invalidateAll(ref);
    if (context.mounted) context.go('/visit/${row['id']}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('임장 시작 실패: $e'), backgroundColor: AppColors.rose));
    }
  }
}

class VisitScreen extends ConsumerStatefulWidget {
  final String visitId;
  const VisitScreen({super.key, required this.visitId});

  @override
  ConsumerState<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends ConsumerState<VisitScreen> {
  bool _busy = false;

  Visit? _find(Map<String, List<Visit>> all) {
    for (final list in all.values) {
      for (final v in list) {
        if (v.id == widget.visitId) return v;
      }
    }
    return null;
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('visits')
          .update(patch)
          .eq('id', widget.visitId);
      invalidateAll(ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
    }
  }

  // ── 사진 ────────────────────────────────────────────────
  Future<void> _addPhotos(Visit v, String tag) async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    input.click();
    await input.onChange.first;
    final picked = input.files;
    if (picked == null || picked.isEmpty) return;

    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser!.id;
    setState(() => _busy = true);
    final added = <VisitPhoto>[];
    for (final f in picked) {
      final reader = html.FileReader()..readAsArrayBuffer(f);
      await reader.onLoad.first;
      final r = reader.result;
      final bytes = r is Uint8List
          ? r
          : (r is ByteBuffer ? r.asUint8List() : null);
      if (bytes == null) continue;
      final safe = f.name.replaceAll(RegExp(r'[^\w.\-가-힣]'), '_');
      final path =
          '$uid/visits/${widget.visitId}/${DateTime.now().microsecondsSinceEpoch}_$safe';
      try {
        await sb.storage.from(_bucket).uploadBinary(path, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'));
        added.add(VisitPhoto(path: path, name: f.name, tag: tag));
      } catch (_) {}
    }
    if (added.isNotEmpty) {
      await _patch({
        'photos': [...v.photos, ...added].map((e) => e.toMap()).toList()
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── 한 줄 메모 ──────────────────────────────────────────
  Future<void> _addMemo(Visit v) async {
    final c = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontSize: AppFont.body),
            decoration: const InputDecoration(
                hintText: '한 줄만. 예: 주차 완전 불가 — 매도 시 감액 요인'),
            onSubmitted: (t) => Navigator.pop(ctx, t.trim()),
          ),
          const Gap(12),
          Row(children: [
            const Spacer(),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            const Gap(8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('추가'),
            ),
          ]),
        ]),
      ),
    );
    if (text == null || text.isEmpty) return;
    final now = TimeOfDay.now();
    final at =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _patch({
      'memos': [...v.memos, VisitMemo(at: at, text: text)]
          .map((e) => e.toMap())
          .toList()
    });
  }

  // ── 들은 시세 ───────────────────────────────────────────
  Future<void> _addHeard(Visit v) async {
    final who = TextEditingController();
    double sale = 0, jeonse = 0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('부동산에서 들은 시세',
                  style: TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              const Gap(4),
              const Text('시세조사의 «현장 조사» 칸으로 들어갑니다',
                  style: TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.caption)),
              const Gap(14),
              TextField(
                controller: who,
                autofocus: true,
                style: const TextStyle(fontSize: AppFont.body),
                decoration:
                    const InputDecoration(labelText: '어느 부동산', hintText: '화곡부동산'),
              ),
              const Gap(10),
              MoneyField(
                  label: '매매',
                  initial: 0,
                  accent: AppColors.primary,
                  onChanged: (x) => sale = x),
              const Gap(8),
              MoneyField(
                  label: '전세',
                  initial: 0,
                  accent: AppColors.primary,
                  onChanged: (x) => jeonse = x),
              const Gap(14),
              Row(children: [
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('취소')),
                const Gap(8),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('추가'),
                ),
              ]),
            ]),
      ),
    );
    if (ok != true || (sale <= 0 && jeonse <= 0)) return;
    await _patch({
      'heard': [
        ...v.heard,
        HeardPrice(
            who: who.text.trim().isEmpty ? '부동산' : who.text.trim(),
            sale: sale,
            jeonse: jeonse)
      ].map((e) => e.toMap()).toList()
    });
  }

  /// 임장을 마친다 — 들은 시세를 시세조사의 «현장 조사»로 넘긴다.
  Future<void> _finish(Visit v, Complex c) async {
    setState(() => _busy = true);
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser!.id;
    try {
      if (v.heard.isNotEmpty) {
        // 오늘 조사에 현장 출처를 추가한다. 기존 책상 조사 값은 살린다.
        final latest = (await ref.read(latestSurveysProvider.future))[c.id];
        final keep = (latest?.sources ?? const <PriceSource>[])
            .where((s) => !s.isField)
            .toList();
        final field = [
          for (var i = 0; i < v.heard.length && i < 3; i++)
            PriceSource(
                label: '부동산 ${i + 1}',
                sale: v.heard[i].sale,
                jeonse: v.heard[i].jeonse,
                at: 'field'),
        ];
        await sb.from('price_surveys').insert({
          'user_id': uid,
          'complex_id': c.id,
          'surveyed_on': DateTime.now().toIso8601String().substring(0, 10),
          'sources': [...keep, ...field].map((e) => e.toMap()).toList(),
          'memo': '임장에서 들은 시세 포함',
        });
      }
      await _patch({'done': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(v.heard.isEmpty
                ? '임장을 마쳤어요'
                : '임장을 마쳤어요 · 들은 시세 ${v.heard.length}건을 시세조사에 넣었어요')));
        context.go('/auction');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('마무리 실패: $e'), backgroundColor: AppColors.rose));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = ref.watch(visitsProvider);
    final complexes = ref.watch(complexesProvider).asData?.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: visits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final v = _find(all);
          if (v == null) {
            return const EmptyState(
                icon: Icons.error_outline_rounded, message: '임장 기록을 찾을 수 없어요');
          }
          final c = complexes.firstWhere((x) => x.id == v.complexId,
              orElse: () => Complex(id: '', name: '(단지 없음)'));
          final checked = v.checkedCount;

          return SafeArea(
            child: Column(children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 6),
                child: Row(children: [
                  IconButton(
                      onPressed: () => context.go('/auction'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 22)),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: AppFont.section,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const Gap(7),
                            const Pill('단지', color: AppColors.sky),
                          ]),
                          const Gap(2),
                          Text(
                              '${Dates.ymd(v.visitedAt)} '
                              '${v.visitedAt.hour.toString().padLeft(2, '0')}:'
                              '${v.visitedAt.minute.toString().padLeft(2, '0')} 도착'
                              ' · 매물 없어도 임장 가능',
                              style: const TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: AppFont.caption)),
                        ]),
                  ),
                  if (v.done)
                    const Pill('완료', color: AppColors.textFaint)
                  else
                    const Pill('현장 중', color: AppColors.primary),
                ]),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                  children: [
                    // 체크 — 크게, 한 손으로
                    GlassCard(
                      accent: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        for (final (key, label) in visitChecks)
                          _CheckRow(
                            label: label,
                            done: v.checks[key] == true,
                            shots:
                                v.photos.where((p) => p.tag == key).length,
                            onTap: () => _patch({
                              'checks': {...v.checks, key: v.checks[key] != true}
                            }),
                            onCamera: _busy ? null : () => _addPhotos(v, key),
                          ),
                      ]),
                    ),
                    const Gap(6),
                    Text('$checked/${visitChecks.length} 확인',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                    const Gap(16),

                    // 사진
                    _header('사진 ${v.photos.length}장', '+ 촬영',
                        AppColors.sky, _busy ? null : () => _addPhotos(v, '')),
                    const Gap(9),
                    if (v.photos.isEmpty)
                      const Text('항목 옆 카메라를 누르면 그 항목의 사진으로 붙습니다',
                          style: TextStyle(
                              color: AppColors.textFaint,
                              fontSize: AppFont.caption))
                    else
                      _PhotoGrid(photos: v.photos),
                    const Gap(18),

                    // 한 줄 메모
                    GlassCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('한 줄 메모',
                                style: TextStyle(
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w800)),
                            const Gap(8),
                            for (final m in v.memos)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: Text(m.at,
                                            style: const TextStyle(
                                                color: AppColors.textFaint,
                                                fontSize: AppFont.caption,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      Expanded(
                                        child: Text(m.text,
                                            style: const TextStyle(
                                                fontSize: AppFont.label,
                                                height: 1.5)),
                                      ),
                                    ]),
                              ),
                            const Gap(8),
                            InkWell(
                              onTap: () => _addMemo(v),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.add_rounded,
                                      size: 16, color: AppColors.textFaint),
                                  Gap(8),
                                  Text('메모 추가 — 한 줄만',
                                      style: TextStyle(
                                          color: AppColors.textFaint,
                                          fontSize: AppFont.label)),
                                ]),
                              ),
                            ),
                          ]),
                    ),
                    const Gap(14),

                    // 들은 시세
                    GlassCard(
                      accent: AppColors.primary,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Text('들은 시세',
                                  style: TextStyle(
                                      fontSize: AppFont.label,
                                      fontWeight: FontWeight.w800)),
                              const Gap(8),
                              const Expanded(
                                child: Text('→ 마치면 시세조사 현장 칸으로',
                                    style: TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: AppFont.caption)),
                              ),
                            ]),
                            const Gap(10),
                            for (final h in v.heard)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(h.who,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: AppFont.label,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  Text('매매 ${Won.compact(h.sale)}',
                                      style: const TextStyle(
                                          fontSize: AppFont.caption,
                                          color: AppColors.textSecondary)),
                                  const Gap(10),
                                  Text('전세 ${Won.compact(h.jeonse)}',
                                      style: const TextStyle(
                                          fontSize: AppFont.caption,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary)),
                                ]),
                              ),
                            InkWell(
                              onTap: () => _addHeard(v),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.add_rounded,
                                      size: 16, color: AppColors.primary),
                                  Gap(8),
                                  Text('부동산에서 들은 값 넣기',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: AppFont.label,
                                          fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ]),
                    ),
                    const Gap(18),

                    if (!v.done)
                      Row(children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: _busy ? null : () => _finish(v, c),
                            child: const Text('임장 마치기',
                                style: TextStyle(
                                    fontSize: AppFont.body,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const Gap(8),
                        SizedBox(
                          width: 108,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: () => context.go('/auction'),
                            child: const Text('나중에'),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _header(String title, String action, Color c, VoidCallback? onTap) =>
      Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: AppFont.label,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary)),
        const Gap(8),
        const Expanded(child: Divider(color: AppColors.border)),
        const Gap(8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(action,
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ]);
}

/// 큰 체크 한 줄 — 현장에서 한 손으로 누른다.
class _CheckRow extends StatelessWidget {
  final String label;
  final bool done;
  final int shots;
  final VoidCallback onTap;
  final VoidCallback? onCamera;
  const _CheckRow({
    required this.label,
    required this.done,
    required this.shots,
    required this.onTap,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: Border.all(
                  color: done ? AppColors.primary : AppColors.border,
                  width: 1.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.primary)
                : null,
          ),
          const Gap(12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color:
                        done ? AppColors.textPrimary : AppColors.textSecondary)),
          ),
          if (shots > 0) ...[
            const Icon(Icons.photo_camera_rounded,
                size: 14, color: AppColors.sky),
            const Gap(4),
            Text('$shots',
                style: const TextStyle(
                    color: AppColors.sky,
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w800)),
            const Gap(8),
          ],
          IconButton(
            tooltip: '이 항목 사진',
            onPressed: onCamera,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_a_photo_rounded,
                size: 18, color: AppColors.textFaint),
          ),
        ]),
      ),
    );
  }
}

/// 임장 사진 격자 — 서명 URL 을 한 번에 받는다.
class _PhotoGrid extends ConsumerWidget {
  final List<VisitPhoto> photos;
  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb = ref.read(supabaseProvider);
    return FutureBuilder<Map<String, String>>(
      future: _sign(sb, photos.map((p) => p.path).toList()),
      builder: (context, snap) {
        final urls = snap.data ?? const <String, String>{};
        return LayoutBuilder(builder: (context, c) {
          const gap = 6.0;
          const cols = 4;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final p in photos)
                SizedBox(
                  width: w,
                  height: w,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: urls[p.path] == null
                        ? const ColoredBox(color: AppColors.surfaceAlt)
                        : Image.network(urls[p.path]!, fit: BoxFit.cover),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  static Future<Map<String, String>> _sign(
      dynamic sb, List<String> paths) async {
    if (paths.isEmpty) return {};
    try {
      final res =
          await sb.storage.from(_bucket).createSignedUrls(paths, 3600);
      return {for (final r in res) r.path as String: r.signedUrl as String};
    } catch (_) {
      return {};
    }
  }
}
