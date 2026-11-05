import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/builtin_specs.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';

/// 비전 «버킷리스트 100곳» — 적은 곳 수를 여기에 대 본다.
const _bucketGoal = 100;

/// 이름(+나라)으로 좌표 찾기 — OpenStreetMap Nominatim. 못 찾으면 null.
/// 나라 이름은 한글로 받는다(accept-language=ko).
/// 첫 결과만 쓰면 «파타고니아»가 서울의 매장으로 찍혔다 — 5개를 받아
/// 넓은 곳(나라·지역·도시, place_rank 가 작은 것)을 먼저 고른다.
Future<({double lat, double lng, String name, String? country})?> _geocode(
    String q) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': q,
    'format': 'jsonv2',
    'limit': '5',
    'addressdetails': '1',
    'accept-language': 'ko',
  });
  try {
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body) as List;
    if (list.isEmpty) return null;
    num rank(Map m) => (m['place_rank'] as num?) ?? 30;
    num imp(Map m) => (m['importance'] as num?) ?? 0;
    final m = (list.cast<Map<String, dynamic>>()
          ..sort((a, b) => rank(a) != rank(b)
              ? rank(a).compareTo(rank(b))
              : imp(b).compareTo(imp(a))))
        .first;
    return (
      lat: double.parse(m['lat'] as String),
      lng: double.parse(m['lon'] as String),
      name: m['display_name'] as String,
      country: (m['address'] as Map?)?['country'] as String?,
    );
  } catch (_) {
    return null;
  }
}

/// 저장 직전 — 이름·나라가 바뀌었거나 아직 지도에 없으면 좌표를 다시 찾는다.
/// 못 찾으면 좌표를 비운다(예전 핀이 엉뚱한 곳에 남지 않게).
Future<Map<String, dynamic>> _locate(
    Map<String, dynamic> v, TravelPlace? old) async {
  final name = v['name'] as String;
  final country = v['country'] as String?;
  if (old != null && old.onMap && old.name == name && old.country == country) {
    return v;
  }
  final hit = await _geocode([name, ?country].join(', '));
  return {
    ...v,
    'lat': hit?.lat,
    'lng': hit?.lng,
    'geo_name': hit?.name,
    if (country == null && hit?.country != null) 'country': hit!.country,
  };
}

/// 여행 — 가고 싶은 곳을 적으면 지도에 핀, 아래에 나라별 목록.
/// 다녀오면 동그라미를 눌러 «다녀온 곳»으로 옮긴다(핀이 금색이 된다).
class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  final _map = MapController();
  final _mapKey = GlobalKey();
  String? _selected;

  void _add() => editBuiltinRecord(context, ref, travelPlaceSpec,
      prepare: (v) => _locate(v, null));

  void _edit(TravelPlace p) => editBuiltinRecord(
        context,
        ref,
        travelPlaceSpec,
        id: p.id,
        initial: {
          'name': p.name,
          'country': p.country,
          'memo': p.memo,
          'visited_on': p.visitedOn?.toIso8601String().substring(0, 10),
        },
        prepare: (v) => _locate(v, p),
      );

  void _delete(TravelPlace p) =>
      deleteBuiltinRecord(context, ref, travelPlaceSpec, p.id, name: p.name);

  Future<void> _toggle(TravelPlace p) async {
    // 날짜는 여기서 — DB current_date 는 UTC 라 한국 아침엔 하루 전이 된다.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await ref.read(supabaseProvider).from('travel_places').update(
        {'visited_on': p.visited ? null : today}).eq('id', p.id);
    ref.invalidate(travelPlacesProvider);
  }

  // 목록에서 고르면 지도를 그곳으로 — 지도가 화면 밖이면 올려 준다.
  void _focus(TravelPlace p) {
    setState(() => _selected = p.id);
    if (!p.onMap) return;
    _map.move(LatLng(p.lat!, p.lng!),
        _map.camera.zoom < 5 ? 5 : _map.camera.zoom);
    final c = _mapKey.currentContext;
    if (c != null) {
      Scrollable.ensureVisible(c,
          duration: const Duration(milliseconds: 300), alignment: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(travelPlacesProvider);
    return ModulePage(
      title: '여행',
      icon: Icons.flight_takeoff_rounded,
      color: AppColors.violet,
      action: AddButton(color: AppColors.violet, onTap: _add, label: '가고 싶은 곳'),
      fab: FloatingActionButton(
        onPressed: _add,
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        tooltip: '가고 싶은 곳 추가',
        child: const Icon(Icons.add_location_alt_rounded),
      ),
      children: [
        async.when(
          loading: AsyncStatus.loading,
          error: AsyncStatus.error,
          data: (places) {
            final wish = places.where((p) => !p.visited).toList();
            final been = places.where((p) => p.visited).toList();
            final countries = {
              for (final p in places)
                if ((p.country ?? '').isNotEmpty) p.country!
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stats(
                    total: places.length,
                    visited: been.length,
                    countries: countries.length),
                const Gap(14),
                KeyedSubtree(
                  key: _mapKey,
                  child: _PlacesMap(
                    places: places,
                    controller: _map,
                    selected: _selected,
                    onSelect: (id) => setState(() => _selected = id),
                  ),
                ),
                const Gap(24),
                if (places.isEmpty)
                  const EmptyState(
                      icon: Icons.add_location_alt_rounded,
                      message: '가고 싶은 곳을 적으면 지도에 핀이 꽂힙니다'),
                if (wish.isNotEmpty) ...[
                  SectionHeader('가고 싶은 곳',
                      subtitle: '${wish.length}곳 · 다녀오면 동그라미를 누른다'),
                  const Gap(10),
                  _PlaceList(
                    places: wish,
                    selected: _selected,
                    onTap: _focus,
                    onToggle: _toggle,
                    onEdit: _edit,
                    onDelete: _delete,
                  ),
                ],
                if (been.isNotEmpty) ...[
                  const Gap(24),
                  SectionHeader('다녀온 곳', subtitle: '${been.length}곳'),
                  const Gap(10),
                  _PlaceList(
                    places: been,
                    selected: _selected,
                    onTap: _focus,
                    onToggle: _toggle,
                    onEdit: _edit,
                    onDelete: _delete,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final int total;
  final int visited;
  final int countries;
  const _Stats(
      {required this.total, required this.visited, required this.countries});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
            const Gap(2),
            Text(value,
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.display,
                    fontWeight: FontWeight.w900)),
          ]),
        );
    return GlassCard(
      accent: AppColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            stat('적은 곳', '$total / $_bucketGoal', AppColors.textPrimary),
            stat('다녀온 곳', '$visited', AppColors.gold),
            stat('나라', '$countries', AppColors.violet),
          ]),
          const Gap(12),
          ProgressBar(
              value: total / _bucketGoal, color: AppColors.violet, height: 6),
          const Gap(6),
          const Text('버킷리스트 100곳을 적고 전부 지운다',
              style: TextStyle(
                  color: AppColors.textFaint, fontSize: AppFont.caption)),
        ],
      ),
    );
  }
}

/// 지도 — OpenStreetMap 을 어둡게 뒤집어 쓴다(CARTO 어두운 지도는 이제 키가 필요했다).
/// 가고 싶은 곳은 보라 핀, 다녀온 곳은 금색 핀.
/// 마우스 휠은 지도 대신 화면을 내리게 두고, 확대는 버튼·두 손가락·더블탭으로.
class _PlacesMap extends StatelessWidget {
  final List<TravelPlace> places;
  final MapController controller;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _PlacesMap({
    required this.places,
    required this.controller,
    required this.selected,
    required this.onSelect,
  });

  List<LatLng> get _points =>
      [for (final p in places.where((p) => p.onMap)) LatLng(p.lat!, p.lng!)];

  void _fitAll() {
    final pts = _points;
    if (pts.length >= 2) {
      controller.fitCamera(CameraFit.coordinates(
          coordinates: pts, padding: const EdgeInsets.all(48), maxZoom: 6));
    } else if (pts.length == 1) {
      controller.move(pts.first, 5);
    } else {
      controller.move(const LatLng(25, 20), 1.5);
    }
  }

  void _zoom(double d) =>
      controller.move(controller.camera.center, controller.camera.zoom + d);

  @override
  Widget build(BuildContext context) {
    final pts = _points;
    final h = MediaQuery.sizeOf(context).width >= 900 ? 440.0 : 320.0;
    Widget btn(IconData i, String tip, VoidCallback onTap) => Material(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          child: IconButton(
            onPressed: onTap,
            tooltip: tip,
            visualDensity: VisualDensity.compact,
            icon: Icon(i, size: 20, color: AppColors.textPrimary),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Insets.radius),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(Insets.radius),
        ),
        child: Stack(children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: pts.length == 1 ? pts.first : const LatLng(25, 20),
              initialZoom: pts.length == 1 ? 5 : 1.5,
              initialCameraFit: pts.length >= 2
                  ? CameraFit.coordinates(
                      coordinates: pts,
                      padding: const EdgeInsets.all(48),
                      maxZoom: 6)
                  : null,
              minZoom: 1,
              maxZoom: 16,
              backgroundColor: AppColors.surface,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all &
                      ~InteractiveFlag.rotate &
                      ~InteractiveFlag.scrollWheelZoom),
              onTap: (_, _) => onSelect(null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.hycapital',
                tileBuilder: darkModeTileBuilder,
              ),
              MarkerLayer(markers: [
                for (final p in places.where((p) => p.onMap))
                  Marker(
                    point: LatLng(p.lat!, p.lng!),
                    width: 150,
                    height: 66,
                    alignment: Alignment.topCenter,
                    child: _Pin(
                      place: p,
                      selected: p.id == selected,
                      onTap: () => onSelect(p.id),
                    ),
                  ),
              ]),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
                backgroundColor: Color(0x99000000),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Column(children: [
              btn(Icons.add_rounded, '확대', () => _zoom(1)),
              const Gap(6),
              btn(Icons.remove_rounded, '축소', () => _zoom(-1)),
              const Gap(6),
              btn(Icons.public_rounded, '전체 보기', _fitAll),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final TravelPlace place;
  final bool selected;
  final VoidCallback onTap;
  const _Pin(
      {required this.place, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = place.visited ? AppColors.gold : AppColors.violet;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (selected)
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c),
            ),
            child: Text(place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: AppFont.caption, fontWeight: FontWeight.w800)),
          ),
        GestureDetector(
          onTap: onTap,
          child: Tooltip(
            message: place.name,
            child: Icon(Icons.location_on_rounded,
                color: c, size: selected ? 36 : 30),
          ),
        ),
      ],
    );
  }
}

/// 나라별로 묶은 목록. 나라를 안 적었고 지도에서도 못 찾았으면 «나라 미정».
class _PlaceList extends StatelessWidget {
  final List<TravelPlace> places;
  final String? selected;
  final ValueChanged<TravelPlace> onTap;
  final ValueChanged<TravelPlace> onToggle;
  final ValueChanged<TravelPlace> onEdit;
  final ValueChanged<TravelPlace> onDelete;
  const _PlaceList({
    required this.places,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final byCountry = <String, List<TravelPlace>>{};
    for (final p in places) {
      final k = (p.country ?? '').isEmpty ? '나라 미정' : p.country!;
      byCountry.putIfAbsent(k, () => []).add(p);
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in byCountry.entries) ...[
            if (e.key != byCountry.keys.first) const Gap(14),
            Text('${e.key} · ${e.value.length}',
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w800)),
            const Gap(4),
            for (final p in e.value)
              _PlaceRow(
                place: p,
                selected: p.id == selected,
                onTap: () => onTap(p),
                onToggle: () => onToggle(p),
                onEdit: () => onEdit(p),
                onDelete: () => onDelete(p),
              ),
          ],
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final TravelPlace place;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PlaceRow({
    required this.place,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = place;
    final c = p.visited ? AppColors.gold : AppColors.violet;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconButton(
            onPressed: onToggle,
            tooltip: p.visited ? '다녀온 것 취소' : '다녀왔다',
            visualDensity: VisualDensity.compact,
            icon: Icon(
                p.visited
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: p.visited ? c : AppColors.textFaint,
                size: 22),
          ),
          const Gap(4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.w700)),
                  if ((p.memo ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(p.memo!,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFont.label,
                            height: 1.5)),
                  ],
                  const Gap(3),
                  if (!p.onMap)
                    const Text('지도에서 못 찾았다 — 이름을 영어나 더 자세히 고쳐 보기',
                        style: TextStyle(
                            color: AppColors.rose, fontSize: AppFont.caption))
                  else
                    Text(
                        [
                          if (p.visitedOn != null)
                            '${Dates.ymd(p.visitedOn!)} 다녀옴',
                          ?p.geoName,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.visited ? c : AppColors.textFaint,
                            fontSize: AppFont.caption)),
                ],
              ),
            ),
          ),
          RecordMenu(onEdit: onEdit, onDelete: onDelete),
        ]),
      ),
    );
  }
}
