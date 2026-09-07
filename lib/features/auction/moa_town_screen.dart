import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/data_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_page.dart';
import '../../models/models.dart';
import 'auction_screen.dart' show quickAddAuction;
import 'auction_detail_screen.dart' show matchZoneForAddress;
import 'buy_band.dart';
import '../../core/edit/plain_controller.dart';

/// 모아타운/신통기획 신청지 — 서울 자치구 개요 → 자치구별 구역 리스트 →
/// 구역 안에서 경매물건 추가·상세(임장)·네이버 지도.
const _teal = Color(0xFF14B8A6);

Color _kindColor(String k) => k == '신통기획' ? AppColors.violet : _teal;

/// 다음 가격 상승 이벤트 — 이 «직전»이 매도 라인.
/// 표는 buy_band.dart 에 있다(종류마다 축이 다르다).
String? _nextJump(Zone z) =>
    z.isSin ? kSinNextRise[z.stage] : kNextRise[z.stage];

// 입지 우선 체크 — 매수 밴드(단계)보다 «입지»가 먼저다. (은천 사례 기준)
// (key, 라벨, 설명)
const _locItems = <(String, String, String)>[
  ('station', '역세권·교통', '지하철역 인접, 실거주 수요 충분'),
  ('scale', '대단지', '예상 세대수 충분 — 사업성 확보'),
  ('drive', '추진 동력', '활발한 추진 주체·단톡방, 주민 참여'),
  ('valley', '저점 진입', '관리계획 수립 중 등 저점 단계'),
  ('exit', '출구 전략', '다음 단계(상승) 직전 단기매도 가능'),
];

int _locDone(Zone z) => _locItems.where((it) => z.locChecks[it.$1] == true).length;

// 세부구역 상태 → (색·태그).
// «인가 전»(수립·공람·기획중·동의서징구·조합설립 진행중·«인가 추진중» 등)은 매수 가능(승계 가능).
// «인가 후·사업시행·시공사 선정» 등 더 진행된 것만 제외.
// 주의: "조합설립인가 «추진중»"은 아직 인가 전 → 매수 가능(글자에 '인가'가 있어도).
({Color color, String tag}) _subInfo(String status) {
  const doneWords = [
    '사업시행', '관리처분', '이주', '착공', '준공', '입주', '시공사', '시공자', '선정총회'
  ];
  if (doneWords.any(status.contains)) {
    return (color: AppColors.textFaint, tag: '너무 진행');
  }
  // 추진중·진행 중 = 아직 인가 전 = 매수 가능.
  if (status.contains('추진') || status.contains('진행')) {
    return (color: AppColors.primary, tag: '🟢 매수 가능');
  }
  // 인가 «완료»(추진/진행 아님) = 승계 제한.
  if (status.contains('인가')) {
    return (color: AppColors.rose, tag: '인가·승계제한');
  }
  return (color: AppColors.primary, tag: '🟢 매수 가능');
}

/// 조합설립 «진행 중»(매수 가능) 세부구역 수.
int _buySubs(Zone z) =>
    z.subs.where((s) => _subInfo(s['status'] ?? '').tag.contains('매수 가능')).length;

Future<void> _openNaver(String query) async {
  final uri = Uri.parse(
      'https://map.naver.com/p/search/${Uri.encodeComponent(query)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class MoaTownView extends ConsumerStatefulWidget {
  /// '모아타운' | '신통기획'. 절차가 아예 달라서 상단 탭으로 갈라 받는다 —
  /// 화면 안에서 또 고르게 두면 탭이 두 층이 되어 어디 있는지 헷갈린다.
  final String kind;
  const MoaTownView({super.key, required this.kind});

  @override
  ConsumerState<MoaTownView> createState() => _MoaTownViewState();
}

class _MoaTownViewState extends ConsumerState<MoaTownView> {
  // zonesProvider 는 캐시된다(빠름). 서버·트리거가 바꾼 뒤엔 새로고침 버튼으로만 다시 불러온다.
  Future<void> _refresh() async {
    ref.invalidate(zonesProvider);
    ref.invalidate(auctionProvider);
    await ref.read(zonesProvider.future);
  }

  String? _district; // null = 서울 개요
  String? _openZoneId; // 펼친 구역

  /// 구역 카드의 «자리». 위 요약에서 칩을 누르면 여기로 스크롤한다 —
  /// 카드만 펼쳐두면 목록이 길어 어디가 열렸는지 못 찾는다.
  final _zoneKeys = <String, GlobalKey>{};
  GlobalKey _keyFor(String id) => _zoneKeys.putIfAbsent(id, GlobalKey.new);

  /// 그 구역 카드를 펼치고 화면에 보이게 올린다.
  void _jumpTo(String id) {
    setState(() => _openZoneId = id);
    // 펼친 «뒤»에 위치가 잡힌다 — 다음 프레임에 스크롤한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _zoneKeys[id]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.06, // 화면 위쪽에 붙인다
      );
    });
  }

  /// 아파트 재건축까지 볼지. 기본은 «끔» — 빌라를 낙찰받는 게 목적이라
  /// 재건축 단지는 살 물건 자체가 없다. 신통에서만 뜻이 있다(모아는 전부
  /// 소규모 재개발).
  bool _withRebuild = false;

  /// 보고 있는 사업 종류. 상단 탭이 정한다.
  String get _kind => widget.kind;
  bool get _sin => widget.kind == '신통기획';
  // 단계 필터: -1 전체 / 0 살 수 있는 것(A+B) / 1 매수A / 2 매수B / 3 진입불가
  int _stageF = -1;

  /// 필터는 «단계 번호»가 아니라 «밴드»로 건다.
  /// 모아 4 와 신통 5 가 둘 다 매수 A 이므로 번호로는 못 거른다.
  bool _stageMatch(Zone z) {
    if (_stageF < 0) return true;
    // 세부구역이 있으면 «세부구역 기준»으로 판정한다 —
    // 한 구역이라도 조합설립 «진행중» 세부구역이 있으면 매수 가능.
    if (z.subs.isNotEmpty) {
      final buy = _buySubs(z);
      return switch (_stageF) {
        0 => buy > 0, // 살 수 있는 것
        1 => false, // 매수적기(관리계획수립·신통 기획중)는 세부구역 이전 단계
        2 => buy > 0, // 매수 B(조합설립 진행중) = 세부 타깃
        3 => buy == 0, // 진입불가 — 매수가능 세부 없음(전부 인가·사업시행)
        _ => true,
      };
    }
    final b = bandOfZone(z);
    return switch (_stageF) {
      0 => b.canBuy, // 매수 A + B
      1 => b == BuyBand.early,
      2 => b == BuyBand.late_,
      3 => b == BuyBand.blocked,
      _ => true,
    };
  }

  Widget _stageChips() {
    Widget chip(int v, String label, Color c) {
      final on = _stageF == v;
      return InkWell(
        onTap: () => setState(() => _stageF = v),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? c.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
                color: on ? c : AppColors.border, width: on ? 1.4 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? c : AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700)),
        ),
      );
    }

    // 라벨은 «그 사업의 단계 이름»으로 쓴다. 모아 용어를 신통 탭에
    // 그대로 두면 무슨 구간인지 알 수가 없다.
    final aWhen = _sin ? '대상지선정 후~확정 전' : '관리계획수립·공람';
    return Wrap(spacing: 6, runSpacing: 6, children: [
      chip(-1, '전체', _kindColor(_kind)),
      chip(0, '🟢 살 수 있는 것', AppColors.primary),
      chip(1, '🟢 매수적기 · $aWhen', AppColors.primary),
      chip(2, '🟢 조합설립 진행중 · 세부구역', AppColors.gold),
      chip(3, '🚫 진입 불가(조합설립↑)', AppColors.rose),
    ]);
  }

  /// 동의율을 구역 카드에서 바로 입력한다.
  /// 편집 다이얼로그 깊숙이 있어서 119곳 중 «0곳»이 채워져 있었다.
  /// 매수 B 에서 「인가 임박」을 가리는 유일한 값이다.
  Future<void> _editConsent(Zone z) async {
    final c = PlainController(
        text: z.consentRate > 0 ? z.consentRate.toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      // builder 의 context 로 pop 해야 «다이얼로그»가 닫힌다.
      // 바깥 context 를 쓰면 화면이 닫혀 흰 화면이 된다.
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('조합설립 동의율',
            style: TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                '«70% 이상»이면 조합설립인가가 임박했다는 뜻이다. 그때부터는 '
                '탈출 창이 좁아진다 — 인가가 나면 양도가 막힌다.\n'
                '추진위·구청·현장 부동산에서 듣는 값이다.',
                style: TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.textSecondary,
                    height: 1.55)),
            const Gap(14),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '동의율 (%)', hintText: '예: 75'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: const Color(0xFF04211D)),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('저장')),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    final v = double.tryParse(c.text.trim()) ?? 0;
    try {
      await ref
          .read(supabaseProvider)
          .from('zones')
          .update({'consent_rate': v}).eq('id', z.id);
      ref.invalidate(zonesProvider);
    } catch (_) {}
  }

  /// 「여기 임장 간다」를 찍는다. 139곳을 훑는 것만으로는 어디 갈지가
  /// 안 남아서, 눈에 걸린 자리를 그 자리에서 찍어 임장예정 탭으로 보낸다.
  Future<void> _toggleVisit(Zone z) async {
    try {
      await ref.read(supabaseProvider).from('zones').update({
        'visit_plan': !z.visitPlan,
      }).eq('id', z.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패 — $e'), backgroundColor: AppColors.rose));
      return;
    }
    ref.invalidate(zonesProvider);
  }

  /// 입지 체크 항목 하나를 토글하고 DB에 저장한다.
  Future<void> _toggleLoc(Zone z, String key) async {
    final next = Map<String, bool>.from(z.locChecks);
    next[key] = !(next[key] ?? false);
    await ref
        .read(supabaseProvider)
        .from('zones')
        .update({'loc_checks': next}).eq('id', z.id);
    ref.invalidate(zonesProvider);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 자료 하나를 연다. PDF(비공개 버킷)는 서명URL을 만들어 미리보기, 링크는 바로 연다.
  Future<void> _openDoc(Map<String, String> d) async {
    final path = d['path'] ?? '';
    if (path.isNotEmpty) {
      try {
        final bucket = d['bucket']?.isNotEmpty == true ? d['bucket']! : 'knowledge';
        final signed = await ref
            .read(supabaseProvider)
            .storage
            .from(bucket)
            .createSignedUrl(path, 3600);
        await _openUrl(signed);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일을 여는 데 실패했어요.')));
        }
      }
      return;
    }
    await _openUrl(d['url'] ?? '');
  }

  /// 구역에 «자료 링크»(구청 공고·기사 등)를 붙인다. PDF는 스토리지 URL을 넣으면 된다.
  Future<void> _addZoneDoc(Zone z) async {
    final titleCtl = TextEditingController();
    final urlCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('자료 추가', style: TextStyle(fontSize: AppFont.section)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titleCtl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '제목', hintText: '예: 영등포소식 공고 / 구역계 PDF')),
            const Gap(10),
            TextField(
                controller: urlCtl,
                decoration: const InputDecoration(
                    labelText: '링크(URL)', hintText: 'https://...')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('추가')),
        ],
      ),
    );
    if (ok != true) return;
    final title = titleCtl.text.trim();
    final url = urlCtl.text.trim();
    if (title.isEmpty || url.isEmpty) return;
    final t = url.toLowerCase().contains('.pdf') ? 'pdf' : 'link';
    final next = [
      ...z.docs,
      {'title': title, 'url': url, 'type': t}
    ];
    await ref
        .read(supabaseProvider)
        .from('zones')
        .update({'docs': next}).eq('id', z.id);
    ref.invalidate(zonesProvider);
  }

  /// 구역 설명(메모) 렌더 — ⚠️/주의는 붉은 경고, 마크다운 표는 key·value 로,
  /// 그 외는 일반 텍스트. 붙여넣은 표가 raw `| |` 로 보이지 않게 한다.
  Widget _memoBody(String m) {
    final warn = m.startsWith('⚠️') || m.startsWith('주의');
    String clean(String s) => s.replaceAll('**', '').trim();
    final rows = <(String, String)>[];
    final plain = <String>[];
    for (final ln in m.split('\n')) {
      final t = ln.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('|')) {
        if (RegExp(r'^[|\s\-:]+$').hasMatch(t)) continue; // 구분선
        final cells =
            t.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (cells.length >= 2) {
          rows.add((clean(cells[0]), clean(cells.sublist(1).join(' '))));
        } else if (cells.length == 1) {
          rows.add(('', clean(cells[0])));
        }
      } else {
        plain.add(clean(t));
      }
    }
    // 표가 아니면 기존 방식(경고 박스 / 흐린 텍스트).
    if (rows.isEmpty) {
      if (!warn) {
        return Text(m,
            style: const TextStyle(
                fontSize: AppFont.caption,
                color: AppColors.textFaint,
                height: 1.4));
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.rose.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.rose),
          const Gap(8),
          Expanded(
            child: Text(m,
                style: const TextStyle(
                    fontSize: AppFont.label,
                    color: AppColors.rose,
                    fontWeight: FontWeight.w700,
                    height: 1.5)),
          ),
        ]),
      );
    }
    // 첫 행이 헤더(항목/내용)면 버린다.
    if (rows.isNotEmpty &&
        (rows.first.$1 == '항목' || rows.first.$1.isEmpty && rows.first.$2 == '내용')) {
      rows.removeAt(0);
    }
    final c = warn ? AppColors.rose : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
          color: (warn ? AppColors.rose : AppColors.sky).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final p in plain) ...[
          Text(p,
              style: TextStyle(
                  fontSize: AppFont.label, color: c, height: 1.4)),
          const Gap(4),
        ],
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.$1.isNotEmpty)
                SizedBox(
                  width: 78,
                  child: Text(r.$1,
                      style: const TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textFaint)),
                ),
              Expanded(
                child: Text(r.$2,
                    style: TextStyle(
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w600,
                        color: c,
                        height: 1.4)),
              ),
            ]),
          ),
      ]),
    );
  }

  /// 구역의 네이버 검색어 / 물건 추가 시 주소 seed (동+번지 포함).
  String _zoneSeed(Zone z) {
    var n = z.name
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll('일대', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final d = z.district ?? '';
    if (n.contains('확인 전') || n.isEmpty) return '서울 $d $_kind';
    final base = (d.isNotEmpty && n.contains(d)) ? n : '$d $n';
    return '서울 $base'.replaceAll(RegExp(r'\s+'), ' ').trim();
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
        final props =
            ref.watch(auctionProvider).asData?.value ?? const <AuctionProperty>[];
        // 먼저 «탭(종류)»으로 나누고, 그 안에서 단계 필터를 건다.
        final mine = zones.where((z) => z.kind == _kind).toList();
        // 신통 목록엔 «아파트 재건축»이 섞여 온다 — 포털이 한 코드로 준다.
        final rebuilt = _sin ? mine.where((z) => isRebuild(z.name)).length : 0;
        final shown = mine
            .where((z) => _withRebuild || !_sin || !isRebuild(z.name))
            .where(_stageMatch)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rebuilt > 0) ...[
              _RebuildBar(
                count: rebuilt,
                on: _withRebuild,
                onTap: () => setState(() => _withRebuild = !_withRebuild),
              ),
              const Gap(12),
            ],
            _district == null
                ? _overview(shown)
                : _districtList(shown, props, _district!),
          ],
        );
      },
    );
  }

  // ── 서울 자치구 개요 ────────────────────────────────────────
  Widget _overview(List<Zone> zones) {
    final byDist = <String, List<Zone>>{};
    for (final z in zones) {
      final d = (z.district == null || z.district!.isEmpty) ? '기타' : z.district!;
      byDist.putIfAbsent(d, () => []).add(z);
    }
    final dists = byDist.keys.toList()
      ..sort((a, b) => byDist[b]!.length.compareTo(byDist[a]!.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 곳 수는 제목 옆에 붙인다 — 한 줄 아래 설명은 매번 읽을 게 아니다.
        Row(children: [
          Text('$_kind 신청지',
              style: TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w800,
                  color: _kindColor(_kind))),
          const Gap(8),
          Text('${zones.length}곳',
              style: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary)),
          const Spacer(),
          _RefreshBtn(onTap: _refresh),
        ]),
        const Gap(12),
        _stageChips(),
        // 왜 이 구간인지 — 「가격이 뛰는 구간」(자료실 2026-08-31) 기준.
        if (_stageF >= 0) ...[
          const Gap(8),
          Builder(builder: (_) {
            final b = switch (_stageF) {
              0 => null,
              1 => BuyBand.early,
              2 => BuyBand.late_,
              _ => BuyBand.blocked,
            };
            if (b == null) {
              return const Text(
                  '★ 조합설립인가 «전»만 산다. 인가가 나면 조합원 지위 양도가 막혀 낙찰받아도 승계가 안 된다.',
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      color: AppColors.primary,
                      height: 1.55,
                      fontWeight: FontWeight.w600));
            }
            if (b == BuyBand.blocked) {
              return Text('★ ${b.why}',
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      color: b.color,
                      height: 1.55,
                      fontWeight: FontWeight.w600));
            }
            Widget row(String tag, String plan) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        margin: const EdgeInsets.only(top: 1),
                        child: Text(tag,
                            style: TextStyle(
                                fontSize: AppFont.caption,
                                color: b.color,
                                fontWeight: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Text(plan,
                            style: const TextStyle(
                                fontSize: AppFont.caption,
                                color: AppColors.textSecondary,
                                height: 1.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('★ ${b.label} — ${b.short}',
                    style: TextStyle(
                        fontSize: AppFont.caption,
                        color: b.color,
                        fontWeight: FontWeight.w800)),
                // 보고 있는 종류만. 둘 다 그리면 신통 탭에서 모아 설명이
                // 같이 떠서 「왜 모아가 나오나」가 된다.
                row(_sin ? '신통' : '모아', _sin ? sinPlan(b) : moaPlan(b)),
              ],
            );
          }),
        ],
        const Gap(16),
        if (dists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('이 단계에 해당하는 구역이 없어요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint)),
          )
        else
          ResponsiveGrid(
            minTileWidth: 150,
            ratio: 1.35,
            children: [for (final d in dists) _distTile(d, byDist[d]!)],
          ),
        const Gap(14),
        const Text('※ 등록된 신청지입니다. 새 지정은 «세제→정비» 타임라인·슬랙으로 매일 갱신돼요.',
            style: TextStyle(
                fontSize: AppFont.caption,
                color: AppColors.textFaint,
                height: 1.5)),
      ],
    );
  }

  Widget _distTile(String d, List<Zone> zs) {
    return GlassCard(
      accent: _kindColor(_kind),
      onTap: () => setState(() {
        _district = d;
        _openZoneId = null;
      }),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.location_on_rounded,
                size: 18, color: _kindColor(_kind)),
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
              style: TextStyle(
                  fontSize: AppFont.hero,
                  fontWeight: FontWeight.w800,
                  color: _kindColor(_kind))),
          const Gap(6),
          // 매수 자리가 몇 곳인지 — 자치구를 고르는 기준이다.
          Builder(builder: (context) {
            final a = zs.where((z) => bandOfZone(z) == BuyBand.early).length;
            final b = zs.where((z) => bandOfZone(z) == BuyBand.late_).length;
            return Wrap(spacing: 4, runSpacing: 4, children: [
              if (a > 0) Pill('매수A $a', color: AppColors.primary),
              if (b > 0) Pill('매수B $b', color: AppColors.gold),
              if (a == 0 && b == 0)
                const Pill('살 자리 없음', color: AppColors.textFaint),
            ]);
          }),
        ],
      ),
    );
  }

  // ── 자치구 → 구역 리스트 ───────────────────────────────────
  Widget _districtList(List<Zone> zones, List<AuctionProperty> props, String d) {
    final zs = [
      for (final z in zones)
        if ((z.district ?? '기타') == d || (z.district == null && d == '기타')) z
    ]..sort((a, b) => b.stage.compareTo(a.stage));
    // 상단 탭에서 이미 종류로 갈라 들어왔다.
    final list = zs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const Gap(8),
        Row(children: [
          Text(d,
              style: const TextStyle(
                  fontSize: AppFont.title, fontWeight: FontWeight.w800)),
          const Spacer(),
          _RefreshBtn(onTap: _refresh),
        ]),
        const Gap(12),
        // 단계 사다리 — 고른 종류의 절차만 그린다.
        _StageLadder(zones: zs, sin: _sin),
        const Gap(14),
        _stageChips(),
        const Gap(14),
        // 「틈」 요약 — 이 자치구에서 지금 살 수 있는 세부구역만 평평하게 모아 앞에 띄운다.
        Builder(builder: (_) {
          final buyable = <(Zone, Map<String, String>)>[];
          for (final z in list) {
            for (final s in z.subs) {
              if (_subInfo(s['status'] ?? '').tag.contains('매수 가능')) {
                buyable.add((z, s));
              }
            }
          }
          if (buyable.isEmpty) return const SizedBox.shrink();
          buyable.sort((a, b) => (int.tryParse(b.$2['rating'] ?? '') ?? 0)
              .compareTo(int.tryParse(a.$2['rating'] ?? '') ?? 0));
          String short(Zone z) => z.name
              .replaceAll('번지 일대', '')
              .replaceAll(' 일대', '')
              .replaceAll('화곡1동 ', '')
              .replaceAll('화곡6동 ', '')
              .trim();
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🟢 지금 살 수 있는 세부구역 ${buyable.length}개 · 조합설립 진행중(승계 가능)',
                      style: const TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const Gap(9),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (z, s) in buyable)
                      InkWell(
                        onTap: () => _jumpTo(z.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('${short(z)} ${s['code']}',
                                style: const TextStyle(
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w800)),
                            if ((s['rating'] ?? '').isNotEmpty) ...[
                              const Gap(5),
                              Text('★${s['rating']}',
                                  style: const TextStyle(
                                      fontSize: AppFont.caption,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.gold)),
                            ],
                          ]),
                        ),
                      ),
                  ]),
                ]),
          );
        }),
        for (final z in list) ...[
          KeyedSubtree(
              key: _keyFor(z.id), child: _zoneCard(z, props, zones)),
          const Gap(10),
        ],
      ],
    );
  }

  Widget _zoneCard(Zone z, List<AuctionProperty> props, List<Zone> zones) {
    final c = _kindColor(z.kind);
    final unknown = z.name.contains('확인 전') || z.name.isEmpty;
    final open = _openZoneId == z.id;
    // 이 구역에 매칭되는 물건(주소 기반).
    final mine = [
      for (final p in props)
        if (matchZoneForAddress(p.address, zones)?.id == z.id) p
    ];
    return GlassCard(
      accent: z.visitPlan ? AppColors.gold : c,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 임장 갈 곳 — 카드를 펼치지 않고 바로 찍는다.
          Align(
            alignment: Alignment.centerRight,
            child: _VisitBtn(on: z.visitPlan, onTap: () => _toggleVisit(z)),
          ),
          InkWell(
            onTap: () => setState(() => _openZoneId = open ? null : z.id),
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
                        // 세부구역이 있으면 뭉뚱그린 단계 대신 세부 판정을 앞세운다.
                        if (z.subs.isEmpty)
                          Pill('단계 ${z.stage} · ${z.stageLabel}',
                              color: z.stage >= 3
                                  ? AppColors.gold
                                  : AppColors.sky),
                        if (mine.isNotEmpty) ...[
                          const Gap(6),
                          Pill('물건 ${mine.length}', color: AppColors.primary),
                        ],
                        const Gap(6),
                        Pill('입지 ${_locDone(z)}/${_locItems.length}',
                            color: _locDone(z) == _locItems.length
                                ? AppColors.primary
                                : _locDone(z) == 0
                                    ? AppColors.textFaint
                                    : AppColors.gold),
                        if (z.subs.isNotEmpty) ...[
                          const Gap(6),
                          Pill('매수가능 ${_buySubs(z)}/${z.subs.length}',
                              color: _buySubs(z) > 0
                                  ? AppColors.primary
                                  : AppColors.textFaint),
                        ],
                      ]),
                      const Gap(8),
                      Text(unknown ? '동·번지 확인 전' : z.name,
                          style: const TextStyle(
                              fontSize: AppFont.section,
                              fontWeight: FontWeight.w800)),
                      // 되는 세부구역(조합설립 진행중)을 이름 밑에 바로 — 펼치지 않아도 보이게.
                      if (z.subs.isNotEmpty && _buySubs(z) > 0) ...[
                        const Gap(4),
                        Wrap(spacing: 5, runSpacing: 4, children: [
                          for (final s in z.subs.where((s) =>
                              _subInfo(s['status'] ?? '').tag.contains('매수 가능')))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                  '${s['code']}${(s['rating'] ?? '').isNotEmpty ? ' ★${s['rating']}' : ''}',
                                  style: const TextStyle(
                                      fontSize: AppFont.caption,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF04211D))),
                            ),
                        ]),
                      ],
                      if (_nextJump(z) != null) ...[
                        const Gap(4),
                        Row(children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 14, color: AppColors.rose),
                          const Gap(4),
                          Flexible(
                            child: Text('다음 상승: ${_nextJump(z)} 직전 매도',
                                style: const TextStyle(
                                    fontSize: AppFont.caption,
                                    color: AppColors.rose,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ],
                      // 이 단계에 «얼마나» 머물렀나. 단계만 보면 멈춘 구역과
                      // 굴러가는 구역이 똑같아 보인다 — 성수전략정비지구는
                      // 기획완료가 2021년이다(66개월).
                      if (z.stalledMonths != null) ...[
                        const Gap(7),
                        Row(children: [
                          Icon(
                              z.isStalled
                                  ? Icons.hourglass_disabled_rounded
                                  : Icons.schedule_rounded,
                              size: 13,
                              color: z.isStalled
                                  ? AppColors.rose
                                  : AppColors.textFaint),
                          const Gap(6),
                          Text(
                              '이 단계 ${z.stalledMonths}개월째'
                              '${z.propelDt == null ? '' : ' (${Dates.ymd(z.propelDt!)}~)'}',
                              style: TextStyle(
                                  fontSize: AppFont.label,
                                  fontWeight: FontWeight.w700,
                                  color: z.isStalled
                                      ? AppColors.rose
                                      : AppColors.textSecondary)),
                          const Gap(8),
                          if (z.isStalled)
                            const Expanded(
                              child: Text('⚠️ 1년 넘게 안 움직인다 — 정체 확인',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: AppFont.label,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.rose)),
                            ),
                        ]),
                      ],
                      // 권리산정기준일 — 이 날 다음날부터 분할·신축은 현금청산.
                      if (z.rightsDate != null) ...[
                        const Gap(7),
                        Row(children: [
                          const Icon(Icons.event_available_rounded,
                              size: 13, color: AppColors.textFaint),
                          const Gap(6),
                          Text('권리산정기준일 ${Dates.ymd(z.rightsDate!)}',
                              style: const TextStyle(
                                  fontSize: AppFont.label,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                          const Gap(8),
                          const Expanded(
                            child: Text('이 날 다음날부터 분할·신축 → 현금청산',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppFont.label,
                                    color: AppColors.textFaint)),
                          ),
                        ]),
                      ],
                      // 동의율 — 매수 B 에서 「인가 임박」을 가리는 값.
                      const Gap(7),
                      InkWell(
                        onTap: () => _editConsent(z),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Icon(Icons.how_to_vote_rounded,
                                size: 13,
                                color: z.imminent
                                    ? AppColors.rose
                                    : AppColors.textFaint),
                            const Gap(6),
                            Text(
                                z.consentRate > 0
                                    ? '동의율 ${z.consentRate.toStringAsFixed(0)}%'
                                    : '동의율 입력',
                                style: TextStyle(
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w700,
                                    color: z.consentRate > 0
                                        ? (z.imminent
                                            ? AppColors.rose
                                            : AppColors.textSecondary)
                                        : _teal)),
                            const Gap(8),
                            if (z.imminent && z.stage == 2)
                              const Expanded(
                                child: Text('⚠️ 인가 임박 — 탈출 창이 좁다',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppFont.caption,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.rose)),
                              )
                            else
                              const Expanded(
                                child: Text('70%↑ 면 조합설립 임박',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppFont.caption,
                                        color: AppColors.textFaint)),
                              ),
                          ]),
                        ),
                      ),
                      // 초기 단계 해제 위험 — 자양2동 681은 4개월 만에 빠졌다.
                      if (hasDropRisk(z)) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.gold),
                                const Gap(8),
                                const Expanded(
                                  child: Text(kDropRiskNote,
                                      style: TextStyle(
                                          fontSize: AppFont.label,
                                          color: AppColors.gold,
                                          height: 1.6)),
                                ),
                              ]),
                        ),
                      ],
                      if (z.aliases.isNotEmpty) ...[
                        const Gap(4),
                        Text('포함 번지: ${z.aliases.join(', ')}',
                            style: const TextStyle(
                                fontSize: AppFont.body,
                                color: AppColors.textSecondary)),
                      ],
                      if ((z.memo ?? '').isNotEmpty) ...[
                        const Gap(6),
                        // ⚠️/주의 경고 · 마크다운 표 · 일반 텍스트를 알아서 렌더.
                        _memoBody(z.memo!),
                      ],
                    ],
                  ),
                ),
                const Gap(8),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textFaint),
              ],
            ),
          ),
          if (open) ...[
            const Gap(12),
            const Divider(height: 1, color: AppColors.border),
            const Gap(12),
            // 구역 지도
            _actionRow(Icons.map_rounded, '구역 지도 (네이버)',
                () => _openNaver(_zoneSeed(z)), _teal),
            // 세부구역 — A2-1·A3-1… 각각 단계가 다르다. 타깃은 «조합설립 진행 중».
            if (z.subs.isNotEmpty) ...[
              const Gap(12),
              Row(children: [
                const Icon(Icons.grid_view_rounded,
                    size: 15, color: AppColors.gold),
                const Gap(6),
                Text('세부구역 · 매수가능 ${_buySubs(z)}/${z.subs.length}',
                    style: const TextStyle(
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold)),
              ]),
              const Gap(6),
              // 매수가능(조합설립 진행중)을 위로, 그 다음 인가·사업시행.
              for (final s in [
                ...z.subs.where((s) => _subInfo(s['status'] ?? '').tag.contains('매수 가능')),
                ...z.subs.where((s) => !_subInfo(s['status'] ?? '').tag.contains('매수 가능')),
              ])
                Builder(builder: (_) {
                  final info = _subInfo(s['status'] ?? '');
                  final rating = s['rating'] ?? '';
                  final buy = info.tag.contains('매수 가능');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: buy ? 0.13 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: buy
                          ? Border.all(
                              color: info.color.withValues(alpha: 0.5), width: 1)
                          : null,
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            margin: const EdgeInsets.only(right: 9),
                            decoration: BoxDecoration(
                                color: info.color
                                    .withValues(alpha: buy ? 0.9 : 0.18),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(s['code'] ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: AppFont.label,
                                    fontWeight: FontWeight.w800,
                                    color: buy
                                        ? const Color(0xFF04211D)
                                        : info.color)),
                          ),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['status'] ?? '',
                                      style: TextStyle(
                                          fontSize: AppFont.label,
                                          fontWeight: FontWeight.w800,
                                          color: info.color,
                                          height: 1.25)),
                                  if (info.tag.isNotEmpty || rating.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text(
                                          [
                                            if (info.tag.isNotEmpty) info.tag,
                                            if (rating.isNotEmpty)
                                              '★' * (int.tryParse(rating) ?? 0)
                                          ].join('  '),
                                          style: TextStyle(
                                              fontSize: AppFont.caption,
                                              fontWeight: FontWeight.w700,
                                              color: info.color)),
                                    ),
                                ]),
                          ),
                        ]),
                  );
                }),
            ],
            const Gap(12),
            // 자료 — 구청 공고·구역계 PDF·기사 링크. 눌러서 열람·미리보기.
            Row(children: [
              const Icon(Icons.folder_open_rounded, size: 15, color: AppColors.sky),
              const Gap(6),
              const Text('자료',
                  style: TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sky)),
              const Spacer(),
              InkWell(
                onTap: () => _addZoneDoc(z),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('＋ 링크',
                      style: TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sky)),
                ),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                  '💡 임장 사전조사 보고서·현장 사진·조합 자료 등을 구글 드라이브에 올린 뒤 '
                  '공유 링크(URL)를 ＋링크로 첨부하세요. 협업자도 클릭 한 번으로 열어봅니다.',
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      color: AppColors.textFaint,
                      height: 1.45)),
            ),
            if (z.docs.isEmpty)
              const SizedBox.shrink()
            else
              for (final d in z.docs)
                InkWell(
                  onTap: () => _openDoc(d),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(
                          d['type'] == 'pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.link_rounded,
                          size: 16,
                          color: d['type'] == 'pdf'
                              ? AppColors.rose
                              : AppColors.sky),
                      const Gap(8),
                      Expanded(
                        child: Text(d['title'] ?? d['url'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                      ),
                      const Icon(Icons.open_in_new_rounded,
                          size: 14, color: AppColors.textFaint),
                    ]),
                  ),
                ),
            const Gap(12),
            // 입지 우선 체크 — 매수 단계(밴드)보다 입지가 먼저다.
            Row(children: [
              const Icon(Icons.place_rounded, size: 15, color: _teal),
              const Gap(6),
              Text('입지 체크 (매수보다 우선) · ${_locDone(z)}/${_locItems.length}',
                  style: const TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w800,
                      color: _teal)),
            ]),
            const Gap(6),
            for (final it in _locItems)
              InkWell(
                onTap: () => _toggleLoc(z, it.$1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            z.locChecks[it.$1] == true
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: z.locChecks[it.$1] == true
                                ? AppColors.primary
                                : AppColors.textFaint),
                        const Gap(8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.$2,
                                    style: TextStyle(
                                        fontSize: AppFont.body,
                                        fontWeight: FontWeight.w700,
                                        color: z.locChecks[it.$1] == true
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary)),
                                Text(it.$3,
                                    style: const TextStyle(
                                        fontSize: AppFont.caption,
                                        color: AppColors.textFaint,
                                        height: 1.3)),
                              ]),
                        ),
                      ]),
                ),
              ),
            const Gap(6),
            const Divider(height: 1, color: AppColors.border),
            const Gap(10),
            // 물건 리스트
            if (mine.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('아직 등록된 경매물건이 없어요. 아래 ＋로 추가하세요.',
                    style: TextStyle(
                        fontSize: AppFont.body, color: AppColors.textFaint)),
              )
            else
              for (final p in mine) ...[
                _propRow(p),
                const Gap(8),
              ],
            const Gap(4),
            // 물건 추가
            InkWell(
              onTap: () =>
                  quickAddAuction(context, ref, prefillAddress: _zoneSeed(z)),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: c, width: 1.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('＋ 이 구역에 경매물건 추가',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: c,
                        fontSize: AppFont.label,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionRow(IconData icon, String label, VoidCallback onTap, Color c) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: c),
            const Gap(6),
            Text(label,
                style: TextStyle(
                    color: c,
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _propRow(AuctionProperty p) {
    return InkWell(
      onTap: () => context.go('/auction/${p.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Pill(p.isSim ? '모의' : '실제',
                        color: p.isSim ? AppColors.violet : AppColors.primary),
                    if (p.corpStatus == 'ok') ...[
                      const Gap(5),
                      const Pill('법인 가능', color: AppColors.primary),
                    ],
                    const Gap(6),
                    Flexible(
                      child: Text(p.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  if ((p.address ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(p.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textFaint)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '네이버 지도',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.map_rounded, size: 20, color: _teal),
              onPressed: () => _openNaver(
                  (p.address == null || p.address!.isEmpty) ? p.title : p.address!),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 단계 사다리 — 순서와 «내 자리»를 같이 본다
// ══════════════════════════════════════════════════════════

/// 그 사업의 진행 단계를 순서대로 늘어놓고, 이 자치구 구역이 몇 곳씩
/// 어느 칸에 있는지 표시한다. 매수 A/B/금지 구간도 색으로 가른다.
class _StageLadder extends StatelessWidget {
  final List<Zone> zones;
  /// 어느 절차로 그릴지. 추측하지 않는다 — 위에서 골라 내려준다.
  final bool sin;
  const _StageLadder({required this.zones, required this.sin});

  bool get _sin => sin;

  @override
  Widget build(BuildContext context) {
    final count = <int, int>{};
    for (final z in zones) {
      count[z.stage] = (count[z.stage] ?? 0) + 1;
    }
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.stairs_rounded,
                size: 15, color: AppColors.textSecondary),
            const Gap(8),
            Text(_sin ? '사업 진행 순서 (신통)' : '사업 진행 순서 (모아)',
                style: const TextStyle(
                    fontSize: AppFont.section,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)),
            const Spacer(),
            const Text('숫자 = 구역 수',
                style: TextStyle(
                    fontSize: AppFont.label, color: AppColors.textFaint)),
          ]),
          const Gap(12),
          // 축이 모아 12칸 · 신통 11칸이라 한 줄에 안 들어간다.
          // 가로 스크롤은 브라우저 뒤로가기와 충돌하므로 «줄바꿈»으로 간다.
          LayoutBuilder(builder: (context, c) {
            final last = sin ? 11 : 12;
            const gap = 6.0;
            // 한 줄에 6칸씩 — 라벨이 두 줄까지 들어가는 너비.
            // 칸이 넓어야 글씨를 키울 수 있다. 넓은 화면도 4칸까지만.
            final per = c.maxWidth < 480 ? 2 : (c.maxWidth < 720 ? 3 : 4);
            final w = (c.maxWidth - gap * (per - 1)) / per;
            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (var i = 1; i <= last; i++)
                  SizedBox(width: w, child: _rung(i, count[i] ?? 0, i == last)),
              ],
            );
          }),
          const Gap(12),
          // 구간 뜻
          Wrap(spacing: 12, runSpacing: 6, children: [
            for (final b in [BuyBand.early, BuyBand.late_, BuyBand.blocked])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: b.color, borderRadius: BorderRadius.circular(2)),
                ),
                const Gap(6),
                Text('${b.label} · ${b.short}',
                    style: TextStyle(
                        fontSize: AppFont.label,
                        color: b.color,
                        fontWeight: FontWeight.w700)),
              ]),
          ]),
          const Gap(8),
          Text(
              _sin
                  ? '가격은 «선정 → 토허가», «지정고시», «조합설립» 에서 뛴다. '
                      '골짜기는 «기획 완료»와 «동의서 징구» — 그 칸에서 산다.'
                  : '가격은 «수립 → 고시», «징구 → 인가» 두 번 뛴다. 그 직전 칸에서 산다.',
              style: const TextStyle(
                  fontSize: AppFont.label,
                  color: AppColors.textSecondary,
                  height: 1.6)),
          const Gap(5),
          const Text(
              '조합설립인가부터는 조합원 지위 양도가 막힌다 — 낙찰받아도 승계가 안 된다.',
              style: TextStyle(
                  fontSize: AppFont.label,
                  color: AppColors.rose,
                  height: 1.55)),
        ],
      ),
    );
  }

  Widget _rung(int stage, int n, bool isLast) {
    final band = _sin ? bandOfSinStage(stage) : bandOfStage(stage);
    final has = n > 0;
    final c = band.color;
    // 조합설립인가로 넘어가는 칸에서 «문이 닫힌다» — 그 경계를 붉게 표시.
    final gate = band == BuyBand.blocked &&
        (_sin ? bandOfSinStage(stage - 1) : bandOfStage(stage - 1)) !=
            BuyBand.blocked;
    return Column(children: [
      if (gate)
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Text('↓ 여기서 닫힌다',
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rose)),
        ),
      Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.withValues(alpha: has ? 0.22 : 0.07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: has ? c : c.withValues(alpha: 0.25),
              width: has ? 1.3 : 1),
        ),
        child: Text(has ? '$stage · $n곳' : '$stage',
            style: TextStyle(
                fontSize: AppFont.body,
                fontWeight: FontWeight.w900,
                color: has ? c : c.withValues(alpha: 0.45))),
      ),
      const Gap(5),
      SizedBox(
        height: 40,
        child: Text(
          (_sin ? Zone.sinStageLabels[stage] : Zone.stageLabels[stage]) ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppFont.body,
              height: 1.35,
              fontWeight: has ? FontWeight.w700 : FontWeight.w500,
              color: has ? AppColors.textSecondary : AppColors.textFaint),
        ),
      ),
      // 단계 이름은 «끝난 일»이다. 지금 뭐가 돌아가는지를 한 줄 더 준다 —
      // 매수 자리가 여기서 갈린다.
      const Gap(3),
      SizedBox(
        height: 38,
        child: Text(
          '↳ ${(_sin ? kSinStageDoing[stage] : kStageDoing[stage]) ?? ''}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: AppFont.label,
              height: 1.35,
              fontWeight: band.canBuy ? FontWeight.w800 : FontWeight.w500,
              color: band.canBuy
                  ? c
                  : AppColors.textFaint.withValues(alpha: 0.7)),
        ),
      ),
    ]);
  }
}

/// 새로고침 버튼 — 누르면 도는 스피너. 캐시된 구역을 필요할 때만 다시 불러온다.
class _RefreshBtn extends StatefulWidget {
  final Future<void> Function() onTap;
  const _RefreshBtn({required this.onTap});
  @override
  State<_RefreshBtn> createState() => _RefreshBtnState();
}

class _RefreshBtnState extends State<_RefreshBtn> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.onTap();
              } catch (_) {}
              if (mounted) setState(() => _busy = false);
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _busy
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _teal))
              : const Icon(Icons.refresh_rounded, size: 15, color: _teal),
          const Gap(5),
          Text(_busy ? '새로고침…' : '새로고침',
              style: const TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700,
                  color: _teal)),
        ]),
      ),
    );
  }
}

/// 「아파트 재건축 N곳 숨김」 줄. 칩을 한 줄 더 깔지 않고 한 줄로 끝낸다.
class _RebuildBar extends StatelessWidget {
  final int count;
  final bool on;
  final VoidCallback onTap;
  const _RebuildBar(
      {required this.count, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: on ? AppColors.textFaint : AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(on ? Icons.apartment_rounded : Icons.holiday_village_rounded,
            size: 18, color: on ? AppColors.textFaint : AppColors.primary),
        const Gap(10),
        Expanded(
          child: Text(
              on
                  ? '아파트 재건축 $count곳도 같이 보는 중 — 낙찰받을 빌라가 없다'
                  : '아파트 재건축 $count곳 숨김 — 빌라 낙찰 대상만 본다',
              style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.textSecondary : AppColors.primary)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: on ? AppColors.primary : AppColors.textSecondary),
          child: Text(on ? '재개발만' : '재건축도 보기',
              style: const TextStyle(
                  fontSize: AppFont.body, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// 「임장 간다」 토글. 구역 카드 오른쪽 위.
class _VisitBtn extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _VisitBtn({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppColors.gold.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: on ? AppColors.gold : AppColors.border,
              width: on ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(on ? Icons.directions_walk_rounded : Icons.add_rounded,
              size: 15, color: on ? AppColors.gold : AppColors.textFaint),
          const Gap(5),
          Text(on ? '임장 예정' : '임장 담기',
              style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w800,
                  color: on ? AppColors.gold : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
