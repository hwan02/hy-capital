// 기준 — 강의·책·자료실에서 배운 것을 «판단 기준»으로 바꿔 두는 곳.
//
// 자료실은 «읽는 곳»이다(122건이 검색만 된다). 이 화면은 그것을
// 구역·단지에 적용되는 기준으로 만들어, 무엇이 막혀 있는지 보여준다.
//
// 기준은 코드에 박지 않는다 — 출처(자료실 항목)와 함께 보여주고,
// 자동으로 판정할 수 있는 것과 사람이 확인해야 하는 것을 구분한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/data/data_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';

const _amber = Color(0xFFF59E0B);

/// 물건 고르는 기준 6개 — 출처: 자료실 「모아·신속 경매전략」.
/// auto = 앱이 데이터로 판정할 수 있는가.
const _filters = <(String, String, bool)>[
  ('선정지인가', '구역이 모아타운·신통기획 선정지 안인지', true),
  ('조합설립이 임박했는가', '동의율 · 예정 시기 — 자치구 확인이 필요하다', false),
  ('시세 대비 안전마진', '시세조사의 매매 평균 vs 최저가', true),
  ('전세 ≥ 낙찰가 (플피)', '시세조사의 전세/매매 비율에서 자동', true),
  ('준주거 상향 대상', '역 350m 또는 간선도로 50m — 지도 확인', false),
  ('입찰 경쟁 낮은 타이밍', '비수기 · 대출 이슈', false),
];

class CriteriaView extends ConsumerWidget {
  const CriteriaView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider);
    final complexes = ref.watch(complexesProvider).asData?.value ?? const [];
    final surveys =
        ref.watch(latestSurveysProvider).asData?.value ?? const <String, PriceSurvey>{};
    final visits =
        ref.watch(visitsProvider).asData?.value ?? const <String, List<Visit>>{};
    final notes = ref.watch(knowledgeProvider).asData?.value ?? const [];

    return zones.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (zoneList) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                '강의·책·자료실에서 배운 것을 «판단 기준»으로 바꿔 둔 곳.\n'
                '구역과 단지가 이 기준으로 채점되고, 막힌 곳이 아래에 뜬다.',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.label,
                    height: 1.55)),
            const Gap(16),

            // 숫자 기준 — 실제 데이터에서 나온다
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('숫자 기준',
                      style: TextStyle(
                          fontSize: AppFont.section,
                          fontWeight: FontWeight.w800)),
                  const Gap(3),
                  const Text('예산으로 미리 걸러내지 않는다 — 살 물건을 찾으면 자금을 맞춘다',
                      style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: AppFont.caption)),
                  const Gap(12),
                  _num('경락잔금대출 (생애최초)', 'KB 70% / 낙찰 80%',
                      '자료실 · 규제지역 수도권 · 낮은 금액 기준', AppColors.sky),
                  _num('경락잔금대출 (일반 무주택)', 'KB 40% / 낙찰 80~90%',
                      '자료실 · 규제지역 — 생애최초와 차이가 크다', AppColors.gold),
                  _num('전세/매매 목표', '85% 이상',
                      '플피 성립선 · 시세조사에서 자동 판정', AppColors.primary),
                  _num('조합설립까지', '약 4.5년', '자료실 · 모아통합기획 (6년 → 4.5년)',
                      AppColors.violet),
                ],
              ),
            ),
            const Gap(14),

            // 6개 필터
            GlassCard(
              accent: _amber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Text('물건 고르는 기준',
                        style: TextStyle(
                            fontSize: AppFont.section,
                            fontWeight: FontWeight.w800)),
                    const Gap(8),
                    const Text('6개',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                  ]),
                  const Gap(3),
                  const Text('출처 — 자료실 「행크특강 · 모아·신속 경매전략」',
                      style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: AppFont.caption)),
                  const Gap(10),
                  for (var i = 0; i < _filters.length; i++)
                    _filterRow(i + 1, _filters[i]),
                ],
              ),
            ),
            const Gap(14),

            // 구역 채점
            Row(children: [
              const Text('구역',
                  style: TextStyle(
                      fontSize: AppFont.section, fontWeight: FontWeight.w800)),
              const Gap(8),
              Text('${zoneList.length}곳',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.caption)),
              const Gap(10),
              const Expanded(child: Divider(color: AppColors.border)),
            ]),
            const Gap(10),
            if (zoneList.isEmpty)
              const EmptyState(
                  icon: Icons.map_rounded,
                  message: '구역이 없어요.\n＋구역 으로 모아타운·신통기획 선정지를 넣으세요.')
            else
              for (final z in zoneList) ...[
                _ZoneRow(
                  zone: z,
                  complexes: complexes.where((c) => c.zoneId == z.id).toList(),
                  surveys: surveys,
                  visits: visits,
                ),
                const Gap(8),
              ],

            const Gap(16),
            // 막힌 곳
            _Blocked(
              zones: zoneList,
              complexes: complexes,
              surveys: surveys,
              visits: visits,
            ),

            const Gap(14),
            // 읽을 것
            _ReadQueue(notes: notes),
          ],
        );
      },
    );
  }

  Widget _num(String label, String value, String src, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w700)),
                  const Gap(2),
                  Text(src,
                      style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: AppFont.caption)),
                ]),
          ),
          const Gap(10),
          Text(value,
              style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w800,
                  color: c)),
        ]),
      );

  Widget _filterRow(int n, (String, String, bool) f) {
    final auto = f.$3;
    final c = auto ? AppColors.primary : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text('$n',
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.micro,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.$1,
                    style: const TextStyle(
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700,
                        height: 1.45)),
                const Gap(2),
                Text(f.$2,
                    style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: AppFont.caption,
                        height: 1.45)),
              ]),
        ),
        const Gap(8),
        Text(auto ? '자동' : '확인 필요',
            style: TextStyle(
                color: c,
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

Map<String, dynamic> zoneToMap(Zone z) => {
      'name': z.name,
      'kind': z.kind,
      'district': z.district,
      'consent_rate': z.consentRate,
      'union_expected':
          z.unionExpected?.toIso8601String().substring(0, 10),
      'memo': z.memo,
    };

/// 구역 한 줄 — 기준으로 채점한 결과. 누르면 수정.
class _ZoneRow extends ConsumerWidget {
  final Zone zone;
  final List<Complex> complexes;
  final Map<String, PriceSurvey> surveys;
  final Map<String, List<Visit>> visits;
  const _ZoneRow({
    required this.zone,
    required this.complexes,
    required this.surveys,
    required this.visits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyed =
        complexes.where((c) => surveys[c.id] != null).length;
    final visited =
        complexes.where((c) => (visits[c.id] ?? const []).isNotEmpty).length;
    // 속도: 동의율이 0이면 «확인 전»이다 — 판정하지 않는다.
    final unknownSpeed = zone.consentRate <= 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      accent: zone.imminent ? AppColors.primary : null,
      onTap: () => editBuiltinRecord(context, ref, zoneSpec,
          initial: zoneToMap(zone), id: zone.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            if ((zone.district ?? '').isNotEmpty) ...[
              Text(zone.district!,
                  style: const TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
              const Gap(6),
            ],
            Expanded(
              child: Text(zone.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w700,
                      color: zone.name.contains('확인 전')
                          ? AppColors.textFaint
                          : AppColors.textSecondary)),
            ),
            const Gap(8),
            Pill(zone.kind, color: AppColors.violet),
            const Gap(6),
            if (unknownSpeed)
              const Pill('속도 확인 전', color: AppColors.gold)
            else if (zone.imminent)
              Pill('임박 · ${zone.consentRate.toStringAsFixed(0)}%',
                  color: AppColors.primary)
            else
              Pill('${zone.consentRate.toStringAsFixed(0)}%',
                  color: AppColors.textFaint),
            RecordMenu(
              onEdit: () => editBuiltinRecord(context, ref, zoneSpec,
                  initial: zoneToMap(zone), id: zone.id),
              onDelete: () => deleteBuiltinRecord(
                  context, ref, zoneSpec, zone.id,
                  name: [zone.district, zone.name]
                      .where((e) => (e ?? '').isNotEmpty)
                      .join(' '))),
          ]),
          const Gap(11),
          Row(children: [
            _m('단지', '${complexes.length}개'),
            const Gap(18),
            _m('시세조사', '$surveyed개',
                color: surveyed > 0 ? AppColors.sky : AppColors.textFaint),
            const Gap(18),
            _m('임장', '$visited개',
                color: visited > 0 ? AppColors.primary : AppColors.textFaint),
          ]),
          if (unknownSpeed) ...[
            const Gap(9),
            Row(children: [
              const Icon(Icons.touch_app_rounded,
                  size: 13, color: AppColors.gold),
              const Gap(6),
              const Text('눌러서 동의율·조합설립 시기를 넣으세요',
                  style: TextStyle(
                      color: AppColors.gold, fontSize: AppFont.caption)),
            ]),
          ],
          if ((zone.memo ?? '').isNotEmpty) ...[
            const Gap(10),
            Text(zone.memo!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFont.caption,
                    height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _m(String k, String v, {Color? color}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: const TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Gap(3),
          Text(v,
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      );
}

/// 막힌 곳 — 기준을 적용했을 때 다음에 해야 하는 것.
class _Blocked extends StatelessWidget {
  final List<Zone> zones;
  final List<Complex> complexes;
  final Map<String, PriceSurvey> surveys;
  final Map<String, List<Visit>> visits;
  const _Blocked({
    required this.zones,
    required this.complexes,
    required this.surveys,
    required this.visits,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String, Color)>[];

    // 기준 ② 속도 — 동의율을 모르면 구역 순위가 안 정해진다.
    for (final z in zones.where((z) => z.consentRate <= 0)) {
      items.add((
        z.name.contains('확인 전')
            ? '동·번지 + 동의율 확인 — 자치구 문의'
            : '동의율 확인 — 자치구 문의',
        [z.district, z.name].where((e) => (e ?? '').isNotEmpty).join(' · '),
        '기준 ②',
        AppColors.gold,
      ));
    }
    // 조사 미착수 / 오래된 조사
    for (final c in complexes) {
      final s = surveys[c.id];
      if (s == null) {
        items.add(('시세조사 시작', c.name, '기준 ③④', AppColors.rose));
      } else if (s.stale) {
        items.add(('시세 갱신 — ${s.ageDays}일 전 기록', c.name, '기준 ③', AppColors.gold));
      } else if (s.fieldFilled == 0) {
        items.add(('임장 — 부동산 시세 확인', c.name, '기준 ③④', AppColors.sky));
      }
    }

    return GlassCard(
      accent: const Color(0xFF14B8A6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('막힌 곳',
              style: TextStyle(
                  fontSize: AppFont.section, fontWeight: FontWeight.w800)),
          const Gap(3),
          const Text('기준을 적용했을 때 다음에 해야 하는 것',
              style: TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Gap(10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('막힌 곳이 없어요.',
                  style: TextStyle(
                      color: AppColors.textFaint, fontSize: AppFont.label)),
            )
          else
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: it.$4, borderRadius: BorderRadius.circular(3)),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.$1,
                              style: const TextStyle(
                                  fontSize: AppFont.label,
                                  fontWeight: FontWeight.w700)),
                          const Gap(2),
                          Text(it.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: AppFont.caption)),
                        ]),
                  ),
                  const Gap(8),
                  Text(it.$3,
                      style: TextStyle(
                          color: it.$4,
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
        ],
      ),
    );
  }
}

/// 읽을 것 — 자료실에서 아직 기준으로 뽑지 않은 것.
class _ReadQueue extends StatelessWidget {
  final List<KnowledgeNote> notes;
  const _ReadQueue({required this.notes});

  @override
  Widget build(BuildContext context) {
    // 별을 단 것 = 기준으로 뽑을 후보로 본다.
    final starred = notes.where((n) => n.starred).take(5).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('기준으로 뽑을 것',
                style: TextStyle(
                    fontSize: AppFont.section, fontWeight: FontWeight.w800)),
            const Gap(8),
            Text('자료실 ${notes.length}건 중 ⭐ ${starred.length}',
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.caption)),
          ]),
          const Gap(3),
          const Text('자료실에서 별을 달아두면 여기 모인다',
              style: TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
          const Gap(10),
          if (starred.isEmpty)
            const Text('아직 없어요. 자료실에서 중요한 항목에 ⭐를 달아보세요.',
                style: TextStyle(
                    color: AppColors.textFaint, fontSize: AppFont.label))
          else
            for (final n in starred)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 14, color: AppColors.gold),
                  const Gap(8),
                  Expanded(
                    child: Text(n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: AppFont.label)),
                  ),
                  if (n.source != null)
                    Text(n.source!,
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: AppFont.caption)),
                ]),
              ),
        ],
      ),
    );
  }
}
