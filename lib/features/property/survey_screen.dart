// 시세조사 — 단지 단위.
//
// 조사는 «매물»이 아니라 «단지»에 붙는다. 한 번 조사하면 계속 쓰이고,
// 매물이 나오면 시세를 여기서 상속받는다.
//
// 출처를 다 채우지 못하는 게 정상이다:
//   · 책상 조사 — 네이버 · 실거래가 · KB (앉아서 된다)
//   · 현장 조사 — 부동산 (임장 가야 채워진다)
// 평균은 «빈 칸을 제외»하고 내므로 하나만 채워도 결론이 나온다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/money_field.dart';
import '../../models/models.dart';
import 'visit_screen.dart';
import 'package:go_router/go_router.dart';

const _sky = AppColors.sky;

/// 책상에서 되는 출처 / 현장에서만 되는 출처.
const deskLabels = ['네이버', '실거래가', 'KB시세'];
const fieldLabels = ['부동산 1', '부동산 2', '부동산 3'];

/// 저장된 조사에서 라벨별 출처를 꺼낸다. 없으면 빈 값.
PriceSource _srcOf(PriceSurvey? s, String label, String at) =>
    s?.sources.firstWhere((e) => e.label == label,
        orElse: () => PriceSource(label: label, at: at)) ??
    PriceSource(label: label, at: at);

class SurveyView extends ConsumerStatefulWidget {
  const SurveyView({super.key});

  @override
  ConsumerState<SurveyView> createState() => _SurveyViewState();
}

class _SurveyViewState extends ConsumerState<SurveyView> {
  String? _openId; // 펼친 단지
  String _district = '전체'; // 자치구 필터

  /// 단지의 자치구 — 구역이 있으면 구역 것을 쓴다.
  String? _districtOf(Complex c, Zone? z) => z?.district ?? c.district;

  @override
  Widget build(BuildContext context) {
    final complexes = ref.watch(complexesProvider);
    final surveys = ref.watch(latestSurveysProvider);
    final zones = ref.watch(zonesProvider).asData?.value ?? const <Zone>[];

    return complexes.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.domain_rounded,
            message: '조사할 단지가 없어요.\n＋단지 로 추가하면 여기에 시세가 쌓입니다.',
          );
        }
        final byId = {for (final z in zones) z.id: z};
        final sv = surveys.asData?.value ?? const <String, PriceSurvey>{};

        // 자치구 집계 — 있는 구만 칩으로 보여준다.
        final counts = <String, int>{};
        for (final c in list) {
          final d = _districtOf(c, c.zoneId == null ? null : byId[c.zoneId]);
          if (d != null && d.isNotEmpty) counts[d] = (counts[d] ?? 0) + 1;
        }
        final districts = counts.keys.toList()..sort();
        final shown = _district == '전체'
            ? list
            : list.where((c) {
                final d =
                    _districtOf(c, c.zoneId == null ? null : byId[c.zoneId]);
                return d == _district;
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                '한 단지를 한 번 조사하면 계속 쓴다. 매물이 나오면 시세를 여기서 가져간다.\n'
                '책상 조사(네이버·실거래·KB)만으로도 결론이 나고, 부동산 칸은 임장에서 채워진다.',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.label,
                    height: 1.55)),
            const Gap(14),
            if (districts.length > 1) ...[
              Wrap(spacing: 6, runSpacing: 6, children: [
                _dChip('전체', list.length),
                for (final d in districts) _dChip(d, counts[d]!),
              ]),
              const Gap(14),
            ],
            for (final c in shown) ...[
              _ComplexCard(
                complex: c,
                zone: c.zoneId == null ? null : byId[c.zoneId],
                survey: sv[c.id],
                open: _openId == c.id,
                onToggle: () =>
                    setState(() => _openId = _openId == c.id ? null : c.id),
              ),
              const Gap(10),
            ],
          ],
        );
      },
    );
  }

  Widget _dChip(String label, int n) {
    final on = _district == label;
    return InkWell(
      onTap: () => setState(() => _district = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? _sky.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: on ? _sky : AppColors.border, width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label $n',
            style: TextStyle(
                color: on ? _sky : AppColors.textSecondary,
                fontSize: AppFont.label,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ComplexCard extends ConsumerStatefulWidget {
  final Complex complex;
  final Zone? zone;
  final PriceSurvey? survey;
  final bool open;
  final VoidCallback onToggle;
  const _ComplexCard({
    required this.complex,
    required this.zone,
    required this.survey,
    required this.open,
    required this.onToggle,
  });

  @override
  ConsumerState<_ComplexCard> createState() => _ComplexCardState();
}

class _ComplexCardState extends ConsumerState<_ComplexCard> {
  /// 편집 중인 값 — 라벨 → (매매, 전세)
  final Map<String, (double, double)> _edit = {};
  bool _busy = false;

  (double, double) _valOf(String label, String at) {
    if (_edit.containsKey(label)) return _edit[label]!;
    final s = _srcOf(widget.survey, label, at);
    return (s.sale, s.jeonse);
  }

  /// 화면에 보이는 값으로 즉시 계산한다(저장 전에도 결론이 보인다).
  PriceSurvey get _live {
    final all = [
      for (final l in deskLabels)
        PriceSource(label: l, sale: _valOf(l, 'desk').$1, jeonse: _valOf(l, 'desk').$2),
      for (final l in fieldLabels)
        PriceSource(
            label: l, sale: _valOf(l, 'field').$1, jeonse: _valOf(l, 'field').$2, at: 'field'),
    ];
    return PriceSurvey(
      id: '',
      complexId: widget.complex.id,
      surveyedOn: widget.survey?.surveyedOn ?? DateTime.now(),
      sources: all,
    );
  }

  Future<void> _save() async {
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      // 새 행을 넣는다 — 추이를 남기기 위해 갱신이 아니라 추가.
      await sb.from('price_surveys').insert({
        'user_id': uid,
        'complex_id': widget.complex.id,
        'surveyed_on': DateTime.now().toIso8601String().substring(0, 10),
        'sources': _live.sources.where((s) => s.hasAny).map((e) => e.toMap()).toList(),
      });
      _edit.clear();
      invalidateAll(ref);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('시세를 저장했어요')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('저장 실패: $e'), backgroundColor: AppColors.rose));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complex;
    final s = widget.survey;
    final live = _live;
    final ratio = live.jeonseRatio;
    final ratioColor = ratio >= 85
        ? AppColors.primary
        : (ratio >= 75 ? AppColors.gold : AppColors.textFaint);

    return GlassCard(
      accent: widget.open ? _sky : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 요약 줄 — 누르면 펼친다
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Row(children: [
                      Flexible(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: AppFont.section,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Gap(8),
                      Pill(c.kind, color: _sky),
                      if (widget.zone != null) ...[
                        const Gap(6),
                        Pill(widget.zone!.kind, color: AppColors.violet),
                      ],
                    ]),
                  ),
                  const Gap(8),
                  if (s == null)
                    const Pill('미착수', color: AppColors.rose)
                  else if (s.stale)
                    Pill('갱신 필요 · ${s.ageDays}일', color: AppColors.gold)
                  else
                    Text('${s.ageDays}일 전',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                  const Gap(6),
                  Icon(
                      widget.open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textFaint),
                ]),
                if ((widget.zone?.name ??
                        c.district ??
                        c.address ??
                        '')
                    .isNotEmpty) ...[
                  const Gap(3),
                  Text(
                      [
                        widget.zone?.district ?? c.district,
                        widget.zone?.name ?? c.address,
                      ].where((e) => (e ?? '').isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: AppFont.label)),
                ],
                const Gap(12),
                Wrap(spacing: 20, runSpacing: 8, children: [
                  _m('매매 평균', live.saleAvg),
                  _m('전세', live.jeonseAvg),
                  _mText('전세/매매',
                      ratio <= 0 ? '—' : '${ratio.toStringAsFixed(0)}%',
                      color: ratioColor),
                  _mText('책상', '${live.deskFilled}/3', color: _sky),
                  _mText('현장', '${live.fieldFilled}/3',
                      color: live.fieldFilled > 0
                          ? AppColors.primary
                          : AppColors.textFaint),
                ]),
              ],
            ),
          ),

          if (widget.open) ...[
            const Gap(16),
            const Divider(height: 1, color: AppColors.border),
            const Gap(14),

            _sectionLabel('책상 조사', _sky, '앉아서 채운다'),
            const Gap(8),
            for (final l in deskLabels) _row(l, 'desk'),

            const Gap(16),
            _sectionLabel('현장 조사', AppColors.primary, '임장에서 들은 값'),
            const Gap(8),
            for (final l in fieldLabels) _row(l, 'field'),

            const Gap(16),
            // 자동 결론
            Wrap(spacing: 10, runSpacing: 10, children: [
              _conclusion(
                  '전세/매매',
                  ratio <= 0 ? '—' : '${ratio.toStringAsFixed(0)}%',
                  ratio >= 85
                      ? '전세가 높다 → 플피 가능성'
                      : (ratio >= 75 ? '보통' : '전세가 낮다 → 자기 돈이 든다'),
                  ratioColor),
              _conclusion(
                  '실투자금 0원 선',
                  live.jeonseAvg <= 0
                      ? '—'
                      : '${Won.compact(live.jeonseAvg)}원',
                  '전세만큼 낙찰받으면 투자금 0',
                  const Color(0xFF14B8A6)),
            ]),

            const Gap(16),
            // 임장 — 단지에 붙는다. 매물이 없어도 간다.
            _VisitSection(complex: widget.complex),

            const Gap(14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _sky,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                onPressed: _busy || _edit.isEmpty ? null : _save,
                icon: const Icon(Icons.save_rounded, size: 17),
                label: Text(_edit.isEmpty ? '변경 없음' : '오늘 시세로 저장'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String t, Color c, String hint) => Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const Gap(7),
        Text(t,
            style: TextStyle(
                color: c, fontSize: AppFont.label, fontWeight: FontWeight.w800)),
        const Gap(8),
        Text(hint,
            style: const TextStyle(
                color: AppColors.textFaint, fontSize: AppFont.caption)),
      ]);

  Widget _row(String label, String at) {
    final v = _valOf(label, at);
    final accent = at == 'field' ? AppColors.primary : _sky;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 460;
        final fieldW = narrow ? (c.maxWidth - 8) / 2 : 176.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: narrow ? 62 : 78,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w700)),
            ),
            const Gap(8),
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                SizedBox(
                  width: fieldW,
                  child: MoneyField(
                    key: ValueKey('$label-sale-${widget.survey?.id}'),
                    label: '매매',
                    initial: v.$1,
                    dense: true,
                    accent: accent,
                    onChanged: (x) =>
                        setState(() => _edit[label] = (x, _valOf(label, at).$2)),
                  ),
                ),
                SizedBox(
                  width: fieldW,
                  child: MoneyField(
                    key: ValueKey('$label-jeonse-${widget.survey?.id}'),
                    label: '전세',
                    initial: v.$2,
                    dense: true,
                    accent: accent,
                    onChanged: (x) =>
                        setState(() => _edit[label] = (_valOf(label, at).$1, x)),
                  ),
                ),
              ]),
            ),
          ],
        );
      }),
    );
  }

  Widget _m(String label, double v) => _mText(
      label, v <= 0 ? '—' : '${Won.compact(v)}원',
      color: v <= 0 ? AppColors.textFaint : null);

  Widget _mText(String label, String value, {Color? color}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Gap(3),
          Text(value,
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      );

  Widget _conclusion(String label, String value, String hint, Color c) =>
      Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          border: Border.all(color: c.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.caption)),
            const Gap(3),
            Text(value,
                style: TextStyle(
                    fontSize: AppFont.display,
                    fontWeight: FontWeight.w800,
                    color: c)),
            const Gap(4),
            Text(hint,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.caption)),
          ],
        ),
      );
}


/// 단지 카드 안의 임장 요약 + 시작 버튼.
class _VisitSection extends ConsumerWidget {
  final Complex complex;
  const _VisitSection({required this.complex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(visitsProvider).asData?.value ?? const {};
    final list = all[complex.id] ?? const <Visit>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3))),
          const Gap(7),
          const Text('임장',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800)),
          const Gap(8),
          Text(list.isEmpty ? '아직 안 감' : '${list.length}회',
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                  fontSize: AppFont.label, fontWeight: FontWeight.w800),
            ),
            onPressed: () => startVisit(context, ref, complex),
            icon: const Icon(Icons.directions_walk_rounded, size: 16),
            label: const Text('임장 시작'),
          ),
        ]),
        for (final v in list) ...[
          const Gap(7),
          InkWell(
            onTap: () => context.go('/visit/${v.id}'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                    v.done
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded,
                    size: 15,
                    color: v.done ? AppColors.primary : AppColors.gold),
                const Gap(9),
                Expanded(
                  child: Text(
                      '${Dates.ymd(v.visitedAt)} · 확인 ${v.checkedCount}/6'
                      '${v.photos.isEmpty ? '' : ' · 사진 ${v.photos.length}'}'
                      '${v.heard.isEmpty ? '' : ' · 들은시세 ${v.heard.length}'}',
                      style: const TextStyle(fontSize: AppFont.label)),
                ),
                Text(v.done ? '완료' : '진행 중',
                    style: TextStyle(
                        fontSize: AppFont.caption,
                        fontWeight: FontWeight.w800,
                        color:
                            v.done ? AppColors.textFaint : AppColors.gold)),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}
