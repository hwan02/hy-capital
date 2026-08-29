import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

/// 모아타운/신통기획 신청지 — 서울 자치구 개요 → 자치구별 리스트 → 네이버 지도.
const _teal = Color(0xFF14B8A6);

Color _kindColor(String k) => k == '신통기획' ? AppColors.violet : _teal;

class MoaTownView extends ConsumerStatefulWidget {
  const MoaTownView({super.key});

  @override
  ConsumerState<MoaTownView> createState() => _MoaTownViewState();
}

class _MoaTownViewState extends ConsumerState<MoaTownView> {
  String? _district; // null = 서울 개요, 값 = 그 자치구 리스트

  /// 네이버 지도 검색어 — 자치구 + 동·번지(괄호·"일대" 제거).
  String _mapQuery(Zone z) {
    var n = z.name
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll('일대', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final d = z.district ?? '';
    final unknown = n.contains('확인 전') || n.isEmpty;
    if (unknown) return '서울 $d 모아타운';
    final base = (d.isNotEmpty && n.contains(d)) ? n : '$d $n';
    return '서울 $base'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _openNaver(Zone z) async {
    final q = Uri.encodeComponent(_mapQuery(z));
    final uri = Uri.parse('https://map.naver.com/p/search/$q');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(zonesProvider);
    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (zones) {
        if (zones.isEmpty) {
          return const EmptyState(
              icon: Icons.map_rounded,
              message: '등록된 구역이 없어요.\n＋구역 으로 모아타운·신통 신청지를 추가하세요.');
        }
        return _district == null
            ? _overview(zones)
            : _districtList(zones, _district!);
      },
    );
  }

  // ── 서울 자치구 개요 ────────────────────────────────────────
  Widget _overview(List<Zone> zones) {
    final byDist = <String, List<Zone>>{};
    for (final z in zones) {
      final d = (z.district == null || z.district!.isEmpty)
          ? '기타'
          : z.district!;
      byDist.putIfAbsent(d, () => []).add(z);
    }
    final dists = byDist.keys.toList()
      ..sort((a, b) => byDist[b]!.length.compareTo(byDist[a]!.length));
    final moaTotal = zones.where((z) => z.kind == '모아타운').length;
    final sinTotal = zones.where((z) => z.kind == '신통기획').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('모아타운 · 신통기획 신청지',
            style:
                TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        Text('서울 $moaTotal개 모아타운 · $sinTotal개 신통기획 · 자치구를 눌러 리스트를 보고, 항목을 누르면 네이버 지도로 열립니다.',
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(16),
        ResponsiveGrid(
          minTileWidth: 150,
          ratio: 1.35,
          children: [
            for (final d in dists) _distTile(d, byDist[d]!),
          ],
        ),
        const Gap(14),
        const Text('※ 여기 나오는 건 앱에 등록된 신청지입니다. 새 지정은 «세제→정비» 타임라인·슬랙으로 매일 갱신돼요.',
            style: TextStyle(
                fontSize: AppFont.caption,
                color: AppColors.textFaint,
                height: 1.5)),
      ],
    );
  }

  Widget _distTile(String d, List<Zone> zs) {
    final moa = zs.where((z) => z.kind == '모아타운').length;
    final sin = zs.where((z) => z.kind == '신통기획').length;
    return GlassCard(
      accent: _teal,
      onTap: () => setState(() => _district = d),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 18, color: _teal),
            const Gap(4),
            Flexible(
              child: Text(d,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            ),
          ]),
          const Gap(8),
          Text('${zs.length}곳',
              style: const TextStyle(
                  fontSize: AppFont.hero,
                  fontWeight: FontWeight.w800,
                  color: _teal)),
          const Gap(6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            if (moa > 0) Pill('모아 $moa', color: _teal),
            if (sin > 0) Pill('신통 $sin', color: AppColors.violet),
          ]),
        ],
      ),
    );
  }

  // ── 자치구 리스트 ──────────────────────────────────────────
  Widget _districtList(List<Zone> zones, String d) {
    final zs = [
      for (final z in zones)
        if ((z.district ?? '기타') == d || (z.district == null && d == '기타')) z
    ]..sort((a, b) => b.stage.compareTo(a.stage));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          InkWell(
            onTap: () => setState(() => _district = null),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: _teal),
                Gap(4),
                Text('서울 전체',
                    style: TextStyle(
                        color: _teal,
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const Gap(8),
        Text(d,
            style:
                const TextStyle(fontSize: AppFont.title, fontWeight: FontWeight.w800)),
        const Gap(2),
        Text('${zs.length}곳 · 항목을 누르면 네이버 지도가 열립니다',
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textFaint)),
        const Gap(14),
        for (final z in zs) ...[
          _zoneCard(z),
          const Gap(10),
        ],
      ],
    );
  }

  Widget _zoneCard(Zone z) {
    final c = _kindColor(z.kind);
    final unknown = z.name.contains('확인 전') || z.name.isEmpty;
    return GlassCard(
      accent: c,
      onTap: () => _openNaver(z),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Pill(z.kind, color: c),
                  const Gap(6),
                  Pill('단계 ${z.stage} · ${z.stageLabel}',
                      color: z.stage >= 3 ? AppColors.gold : AppColors.sky),
                ]),
                const Gap(8),
                Text(unknown ? '동·번지 확인 전' : z.name,
                    style: const TextStyle(
                        fontSize: AppFont.section, fontWeight: FontWeight.w800)),
                if (z.aliases.isNotEmpty) ...[
                  const Gap(4),
                  Text('포함 번지: ${z.aliases.join(', ')}',
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          color: AppColors.textSecondary)),
                ],
                if ((z.memo ?? '').isNotEmpty) ...[
                  const Gap(4),
                  Text(z.memo!,
                      style: const TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textFaint)),
                ],
              ],
            ),
          ),
          const Gap(8),
          const Icon(Icons.map_rounded, size: 20, color: _teal),
        ],
      ),
    );
  }
}
