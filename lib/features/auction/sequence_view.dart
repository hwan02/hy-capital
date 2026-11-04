// 「경매 순서」 탭 — 물건 하나를 «내 순서대로» 끌고 간다.
//
// 「진행」 탭이 낙찰 이후까지 가는 9단계라면, 여기는 «입찰 전»에
// 손품→발품 순서로 거르는 11단계다. 순서가 곧 화면 순서다.
//
//   구역 → 기준 → 권리분석1(손품) → 권리산정일 → 매수 적기 →
//   진행사항1 → 실거래 → 실투자금 → 진행사항2(전화) → 권리분석2(임장) →
//   투자 포인트
//
// 체크·메모는 물건의 checks jsonb 에 «seq_» 접두어로 저장한다 —
// 새 테이블을 만들지 않는다. 물건 하나가 진실의 원천이다.
// 앱이 이미 알고 있는 것(구역·권리산정일·매수 구간·실투자금)은
// 체크 대신 «판정»으로 보여준다 — 같은 걸 두 번 묻지 않는다.
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/data_providers.dart';
import '../../core/edit/builtin_crud.dart';
import '../../core/edit/plain_controller.dart';
import '../../core/format/formatters.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/models.dart';
import '../property/inherit.dart';
import 'auction_detail_screen.dart' show matchZoneForAddress;
import 'auction_screen.dart' show quickAddAuction;
import 'buy_band.dart';

const _teal = Color(0xFF14B8A6);
const _amber = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);

/// 선택한 물건은 «이 브라우저»에만 둔다 — 화면 취향이라 기기마다 달라도 된다.
const _kPropKey = 'auction_seq_prop';

String? _loadProp() {
  try {
    return html.window.localStorage[_kPropKey];
  } catch (_) {
    return null;
  }
}

void _saveProp(String? id) {
  try {
    if (id == null) {
      html.window.localStorage.remove(_kPropKey);
    } else {
      html.window.localStorage[_kPropKey] = id;
    }
  } catch (_) {/* 사파리 프라이빗 등 */}
}

/// 체크 항목 하나. `key` 는 checks jsonb 의 키 (seq_ 접두어 포함).
class SeqItem {
  final String key;
  final String label;
  final String? hint;
  const SeqItem(this.key, this.label, {this.hint});
}

/// 단계 하나.
class SeqStep {
  final String key;
  final String label;
  final String goal; // 이 단계에서 «끝내야 하는 것» 한 줄
  final IconData icon;
  final Color color;
  final List<SeqItem> items;

  /// 관련 탭 id (kAuctionTabs). 누르면 그 탭으로 간다.
  final int? tab;
  final String? tabLabel;

  /// 메모 칸 힌트. null 이면 메모 칸 없음.
  final String? noteHint;

  const SeqStep({
    required this.key,
    required this.label,
    required this.goal,
    required this.icon,
    required this.color,
    required this.items,
    this.tab,
    this.tabLabel,
    this.noteHint,
  });

  String get noteKey => 'seq_${key}__note';
}

/// 투자 포인트 — «왜 해야 하는지»를 다섯 줄로. 다 못 채우면 입찰하지 않는다.
const kSeqPoints = <(String, String, String)>[
  ('seq_pt_loc', '① 입지', '이 구역은 ○○ 때문에 완공 후 ○억짜리가 된다'),
  ('seq_pt_biz', '② 사업', '세대수가 ○배 늘고 동의율 ○%라서 다음 단계가 ○개월 안에 온다'),
  ('seq_pt_item', '③ 물건', '대지지분·분양자격이 확실하고 시세보다 ○% 싸다'),
  ('seq_pt_auction', '④ 경매', '토허구역이어도 실거주 의무 없음 · 금융기관 경매라 조합원 승계 가능'),
  ('seq_pt_exit', '⑤ 출구·리스크', '○○ 단계에서 팔면 세후 ○천. 최악이면 ○천 손실 — 감당 가능'),
];

/// 경매 순서 11단계. 순서가 곧 화면 순서다.
const kSeqSteps = <SeqStep>[
  // ── 1 ────────────────────────────────────────────────────
  SeqStep(
    key: 'zone',
    label: '구역 포함 확인',
    goal: '이 물건이 모아·신통 구역 «안»에 있는지 지번으로 확인한다',
    icon: Icons.map_rounded,
    color: _teal,
    tab: 9,
    tabLabel: '모아타운',
    items: [
      SeqItem('seq_zone_border', '구역 경계 안에 있나 — 지번 단위로',
          hint: '경계에 걸친 물건은 «제외·존치»될 수 있다. 구역도·고시문에서 지번을 찾는다.'),
      SeqItem('seq_zone_project', '사업시행구역에 이미 들어갔나',
          hint: '들어갔으면 늦었다. 아래 판정의 «사업시행구역» 값을 채운다.'),
    ],
  ),

  // ── 2 ────────────────────────────────────────────────────
  SeqStep(
    key: 'criteria',
    label: '기준 체크',
    goal: '세 기준 중 하나라도 걸리면 «패스»한다',
    icon: Icons.rule_rounded,
    color: _amber,
    tab: 3,
    tabLabel: '기준',
    items: [
      SeqItem('seq_cr_price', '기준1 — 공시가 1억 이하',
          hint: '부동산공시가격알리미. 아래 판정에 공시가를 넣으면 자동으로 본다. '
              '구역 지정 단계에 따라 1억↓이라도 취득세 중과 예외에서 빠질 수 있다 — 세무과 확인.'),
      SeqItem('seq_cr_profit', '기준2 — 1억 초과면 «세후» 수익 3천 이상',
          hint: '세후·전비용 차감 기준. 보유기간도 같이 적는다 (예: 2년 내 세후 3천).'),
      SeqItem('seq_cr_area', '기준3 — 중상급지',
          hint: '완공 후 가치는 입지가 정한다. 역·업무지구·학군·인근 신축 대장 시세.'),
      SeqItem('seq_cr_bank', '3-1 — «금융기관» 임의경매인가 (조합원 승계 가능)',
          hint: '채권자가 국민은행 등 금융기관이면 조합설립 뒤에도 승계된다. '
              '개인 채권자 강제경매는 예외가 안 될 수 있다 — 등기부·사건내역에서 채권자 확인.'),
      SeqItem('seq_cr_defect', '3-2 — 위반건축물 · 유치권 확인',
          hint: '경쟁이 없는 이유다. «해결 가능한 하자»인지, 진짜 하자인지 가른다. '
              '위반건축물은 이행강제금 + 경락잔금대출 거절 위험.'),
    ],
  ),

  // ── 3 ────────────────────────────────────────────────────
  SeqStep(
    key: 'rights1',
    label: '권리분석 1 — 손품',
    goal: '책상에서 «인수할 금액»을 숫자로 적는다',
    icon: Icons.gavel_rounded,
    color: AppColors.violet,
    noteHint: '말소기준권리 · 임차인 전입일 · 인수 금액 (0원이면 0원이라 적는다)',
    items: [
      SeqItem('seq_r1_base', '말소기준권리를 찾았나',
          hint: '등기부 을구 최선순위 (근)저당·압류·가압류·경매개시결정. 이 뒤는 다 소멸.'),
      SeqItem('seq_r1_tenant', '임차인 전입일·확정일자·배당요구를 봤나',
          hint: '전입일이 말소기준보다 «앞»이면 대항력 — 보증금 인수. 세대합가도 본다.'),
      SeqItem('seq_r1_docs', '매각물건명세서 · 현황조사서 · 감정평가서를 읽었나',
          hint: 'HUG 임차권 인수조건변경·임차권등기가 있으면 인수금액을 반드시 확인.'),
      SeqItem('seq_r1_special', '특수권리 — 유치권·법정지상권·지분·선순위 가등기/가처분',
          hint: '하나라도 있으면 초보는 넘긴다. 대지권 미등기·토지별도등기도 여기서.'),
      SeqItem('seq_r1_amount', '인수 금액을 «숫자»로 적었나',
          hint: '모르면 들어가지 않는다 — 손실을 계량 못 하면 베팅이 아니다.'),
    ],
  ),

  // ── 4 ────────────────────────────────────────────────────
  SeqStep(
    key: 'rights_date',
    label: '권리산정일 체크',
    goal: '기준일을 넘긴 «현금청산 물건»을 여기서 거른다',
    icon: Icons.event_busy_rounded,
    color: AppColors.rose,
    items: [
      SeqItem('seq_rd_zone', '구역의 권리산정기준일을 확인했나',
          hint: '서울시 「모아타운 추진현황」 표 · 도시공간포털 고시문. 구역 카드에 넣으면 아래 판정이 돈다.'),
      SeqItem('seq_rd_moa', '모아 — «건축허가일 + 착공신고일» 둘 다 기준일 이내인가',
          hint: '건축물대장(없으면 구청 건축과). 사용승인일이 아니다. '
              '※ 2026.10 모아통합기획부터는 신통처럼 «보존등기 접수» 기준 — 어느 쪽이 적용되는지 구청 확인.'),
      SeqItem('seq_rd_sin', '신통 — «소유권 보존등기 접수일» ≤ 기준일 다음 날인가',
          hint: '등기부등본 갑구 접수일자. 소유권 «이전»등기·건축허가·계약일은 무관.'),
      SeqItem('seq_rd_split', '필지 분할 · 다세대 전환 · 토지/건물 분리 흔적이 없나',
          hint: '기준일 다음날부터 이 셋은 현금청산 사유다. 신축 빌라·지분 물건은 특히.'),
    ],
  ),

  // ── 5 ────────────────────────────────────────────────────
  SeqStep(
    key: 'timing',
    label: '매수 적기 판단',
    goal: '다음 «상승 이벤트» 직전 골짜기에서 산다',
    icon: Icons.trending_up_rounded,
    color: AppColors.gold,
    tab: 9,
    tabLabel: '모아타운',
    items: [
      SeqItem('seq_tm_moa', '모아 — 후·계·공·통·승 중 «후·계·공»에 있나',
          hint: '관리계획 수립 중이 첫 골짜기. 공람 공고가 뜨면 통합심의 임박 = 마지막 매수 기회.'),
      SeqItem('seq_tm_sin', '신통 — 후보지 선정 ~ 구역 확정 «사이»인가',
          hint: '기획 완료가 첫 골짜기(토허가 발효로 뛴 뒤 20% 빠진다). 확정 고시 전에 산다.'),
      SeqItem('seq_tm_event', '다음 이벤트(공람·심의·고시)가 3~6개월 안에 있나',
          hint: '이벤트 직전이 프리미엄이 붙는 시점. 추진위·구청에 일정을 물어본다.'),
      SeqItem('seq_tm_tohuh', '토지거래허가구역인가 — 경매는 허가 대상이 아니다',
          hint: '경매 취득은 토허 예외라 실거주 의무가 없다. 이게 경매의 핵심 메리트.'),
    ],
  ),

  // ── 6 ────────────────────────────────────────────────────
  SeqStep(
    key: 'progress1',
    label: '진행사항 확인 1 — 손품',
    goal: '사업이 «실제로 움직이는지» 책상에서 확인한다',
    icon: Icons.speed_rounded,
    color: AppColors.sky,
    tab: 10,
    tabLabel: '뉴스',
    noteHint: '동의율 ○% · 현재 단계 들어간 날 · 오픈채팅 분위기 · 반대 세력 유무',
    items: [
      SeqItem('seq_p1_rate', '주민 동의율 · 단계 진행 속도를 봤나',
          hint: '후계공통승 / 후보지→확정 사이가 빨리 가는지. 1년 넘게 같은 단계면 멈춘 것.'),
      SeqItem('seq_p1_sns', 'SNS · 오픈채팅방이 활성화돼 있나',
          hint: '조용하면 추진 동력이 없다. 비대위·상가 소유주 반대도 여기서 읽힌다.'),
      SeqItem('seq_p1_portal', '아카이브 · 누리집 · 토지이음을 확인했나',
          hint: '구청 고시·공고, 서울도시공간포털 열람공고(키워드 «모아»), 정비사업 정보몽땅.'),
    ],
  ),

  // ── 7 ────────────────────────────────────────────────────
  SeqStep(
    key: 'deals',
    label: '실거래 확인',
    goal: '매매 · 전월세 «성사가»를 잡는다',
    icon: Icons.show_chart_rounded,
    color: AppColors.primary,
    tab: 0,
    tabLabel: '단지 시세',
    items: [
      SeqItem('seq_dl_sale', '매매 실거래를 확인했나 — 유사 평형·연식',
          hint: '네이버·KB는 «호가», 국토부 실거래가 «성사가». 단지에 연결하면 시세를 상속받는다.'),
      SeqItem('seq_dl_rent', '전월세 실거래를 확인했나',
          hint: '전세가 ≥ 낙찰가면 플피. 전세보증보험 한도(공시가×126%)도 같이 본다.'),
      SeqItem('seq_dl_premium', '구역 안 유사 물건의 «프리미엄 시세»를 확인했나',
          hint: '매도호가와 실제 거래가를 구분. 인근 신축 대장 84㎡ 시세가 완공 후 가치 기준.'),
      SeqItem('seq_dl_dash', '임장 대시보드(단지 시세)를 썼나',
          hint: '「단지 시세」에 조사값을 넣어두면 물건 카드가 자동으로 상속받는다.'),
    ],
  ),

  // ── 8 ────────────────────────────────────────────────────
  SeqStep(
    key: 'cash',
    label: '실투자금 확인',
    goal: '«내 돈이 얼마 들어가나»를 명의별로 확정한다',
    icon: Icons.account_balance_wallet_rounded,
    color: AppColors.gold,
    tab: 6,
    tabLabel: '계산기',
    noteHint: '법인 ○○만 vs 개인 ○○만 · 세무과 답변 · 대출 상담 결과',
    items: [
      SeqItem('seq_cs_corp', '법인 vs 개인으로 했을 때 비용을 비교했나',
          hint: '취득세(법인 12.4% vs 개인 ~1.1%) · 양도세(단기중과 vs 법인 추가과세). 「세제」 탭.'),
      SeqItem('seq_cs_taxcall', '세무과에 전화했나',
          hint: '공시가 1억↓ 중과 배제가 이 구역·이 단계에서 되는지. 정비구역 지정되면 예외에서 빠질 수 있다.'),
      SeqItem('seq_cs_loan', '경락잔금대출 가능 여부를 «입찰 전»에 확인했나',
          hint: '위반건축물·규제지역 다주택이면 거절될 수 있다. 잔금 못 내면 보증금을 날린다.'),
      SeqItem('seq_cs_calc', '계산기에 숫자를 다 넣었나',
          hint: '낙찰가 + 취득세 + 인수보증금 + 등기·명도·수리·예비비 − 대출 − 전세 = 실투자금.'),
    ],
  ),

  // ── 9 ────────────────────────────────────────────────────
  SeqStep(
    key: 'progress2',
    label: '진행사항 확인 2 — 전화',
    goal: '추진위 · 구청에 «직접» 묻는다',
    icon: Icons.call_rounded,
    color: AppColors.violet,
    noteHint: '추진위: 동의율·다음 일정·예상 비례율 / 구청: 기준일·경계 변경·분양자격',
    items: [
      SeqItem('seq_p2_union', '추진위원회에 전화했나',
          hint: '현재 동의율 · 다음 일정 · 예상 비례율 · 조합원 수 대비 계획 세대수 · 시공사 접촉 여부.'),
      SeqItem('seq_p2_gu', '구청(주거정비과)에 전화했나',
          hint: '권리산정기준일 · 구역 경계 변경 가능성 · 이 물건의 분양자격 · 존치·제외 대상인지.'),
    ],
  ),

  // ── 10 ───────────────────────────────────────────────────
  SeqStep(
    key: 'rights2',
    label: '권리분석 2 — 임장',
    goal: '서류에 «안 나오는» 것을 현장에서 본다',
    icon: Icons.directions_walk_rounded,
    color: AppColors.sky,
    tab: 12,
    tabLabel: '임장예정',
    noteHint: '점유자 · 미납관리비 금액 · 부동산 3곳이 말한 프리미엄 · 수리 범위',
    items: [
      SeqItem('seq_r2_occupant', '점유자를 확인했나 — 소유자인가 임차인인가',
          hint: '우편물 · 계량기 · 관리사무소. 명도 난이도와 명도비가 여기서 갈린다.'),
      SeqItem('seq_r2_illegal', '위반건축물을 «눈으로» 봤나',
          hint: '옥탑 · 베란다 확장 · 근생을 주택으로 개조. 대장과 다르면 이행강제금.'),
      SeqItem('seq_r2_mgmt', '미납관리비를 확인했나',
          hint: '공용부만 승계된다. 금액을 받아 적어 비용에 넣는다.'),
      SeqItem('seq_r2_agents', '부동산 3곳에서 프리미엄 · 매수 대기자를 들었나',
          hint: '「전세 알아본다」로 열고 마지막에 그 물건을 묻는다. 세 곳이 갈리면 보수적인 값.'),
      SeqItem('seq_r2_repair', '수리 범위를 가늠했나 — 올수리 / 부분 / 청소만',
          hint: '여기서 매긴 금액이 그대로 입찰가를 깎는다.'),
    ],
  ),

  // ── 11 ───────────────────────────────────────────────────
  SeqStep(
    key: 'points',
    label: '투자 포인트 정리',
    goal: '«왜 해야 하는지»를 다섯 줄로 쓴다 — 다 못 채우면 입찰하지 않는다',
    icon: Icons.lightbulb_rounded,
    color: _indigo,
    items: [],
  ),
];

/// 단계 안에서 체크한 비율 0~1.
double _stepProgress(SeqStep s, Map<String, dynamic> checks) {
  if (s.key == 'points') {
    final filled = kSeqPoints
        .where((p) => (checks[p.$1] ?? '').toString().trim().isNotEmpty)
        .length;
    return filled / kSeqPoints.length;
  }
  if (s.items.isEmpty) return 1;
  final done = s.items.where((i) => checks[i.key] == true).length;
  return done / s.items.length;
}

bool _stepDone(SeqStep s, Map<String, dynamic> checks) =>
    _stepProgress(s, checks) >= 1;

/// 첫 번째 «안 끝난» 단계 번호. 다 끝났으면 마지막.
int _currentIndex(Map<String, dynamic> checks) {
  for (var i = 0; i < kSeqSteps.length; i++) {
    if (!_stepDone(kSeqSteps[i], checks)) return i;
  }
  return kSeqSteps.length - 1;
}

class AuctionSequenceView extends ConsumerStatefulWidget {
  /// 관련 탭으로 건너뛸 때 부른다 (부모가 _tab 을 바꾼다).
  final void Function(int tabId) onGoTab;
  const AuctionSequenceView({super.key, required this.onGoTab});

  @override
  ConsumerState<AuctionSequenceView> createState() =>
      _AuctionSequenceViewState();
}

class _AuctionSequenceViewState extends ConsumerState<AuctionSequenceView> {
  String? _propId = _loadProp();

  /// 사용자가 직접 펼친/접은 단계. 없으면 «현재 단계»만 펼친다.
  final Set<String> _opened = {};
  final Set<String> _closed = {};

  Future<void> _patchChecks(
      AuctionProperty p, Map<String, dynamic> patch) async {
    final next = Map<String, dynamic>.from(p.checks)..addAll(patch);
    try {
      await ref
          .read(supabaseProvider)
          .from('auction_properties')
          .update({'checks': next}).eq('id', p.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패 — $e'), backgroundColor: AppColors.rose));
      return;
    }
    ref.invalidate(auctionProvider);
  }

  Future<void> _setVerdict(AuctionProperty p, String v) async {
    await ref
        .read(supabaseProvider)
        .from('auction_properties')
        .update({'verdict': v}).eq('id', p.id);
    invalidateAll(ref);
  }

  Future<void> _setProjectZone(AuctionProperty p, String v) async {
    await ref
        .read(supabaseProvider)
        .from('auction_properties')
        .update({'project_zone': v}).eq('id', p.id);
    invalidateAll(ref);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auctionProvider);
    final zones = ref.watch(zonesProvider).asData?.value ?? const <Zone>[];
    final complexes =
        ref.watch(complexesProvider).asData?.value ?? const <Complex>[];
    final surveys = ref.watch(latestSurveysProvider).asData?.value ??
        const <String, PriceSurvey>{};
    final complexById = {for (final c in complexes) c.id: c};

    Zone? zoneOf(AuctionProperty p) {
      final c = p.complexId == null ? null : complexById[p.complexId];
      if (c?.zoneId != null) {
        for (final z in zones) {
          if (z.id == c!.zoneId) return z;
        }
      }
      return matchZoneForAddress(p.address, zones);
    }

    return async.when(
      loading: AsyncStatus.loading,
      error: AsyncStatus.error,
      data: (all) {
        // 제외·종료된 물건은 순서를 밟을 대상이 아니다.
        final live = all
            .where((p) =>
                !p.excluded && p.status != 'sold' && p.status != 'pass')
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));

        AuctionProperty? sel;
        for (final p in live) {
          if (p.id == _propId) sel = p;
        }
        // 저장된 물건이 사라졌으면 첫 물건으로.
        if (sel == null && live.isNotEmpty) {
          sel = live.first;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Intro(),
            const Gap(14),

            // ── 물건 고르기 ────────────────────────────────
            Row(children: [
              const Expanded(
                child: Text('어떤 물건을 밟을까',
                    style: TextStyle(
                        fontSize: AppFont.section,
                        fontWeight: FontWeight.w800)),
              ),
              AddButton(
                  color: _teal,
                  label: '매물',
                  onTap: () => quickAddAuction(context, ref)),
            ]),
            const Gap(10),
            if (live.isEmpty)
              const EmptyState(
                icon: Icons.format_list_numbered_rounded,
                message: '밟을 물건이 없어요.\n「＋ 매물」로 물건을 넣으면 여기서 순서대로 체크합니다.',
              )
            else
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in live)
                  _PropChip(
                    p: p,
                    selected: p.id == sel?.id,
                    progress: _currentIndex(p.checks),
                    onTap: () {
                      setState(() {
                        _propId = p.id;
                        _opened.clear();
                        _closed.clear();
                      });
                      _saveProp(p.id);
                    },
                  ),
              ]),

            if (sel != null) ...[
              const Gap(18),
              _Overview(
                p: sel,
                onOpen: () => context.go('/auction/${sel!.id}'),
              ),
              const Gap(14),
              for (var i = 0; i < kSeqSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StepCard(
                    index: i,
                    step: kSeqSteps[i],
                    p: sel,
                    zone: zoneOf(sel),
                    price: effectivePrice(sel, surveys),
                    open: _opened.contains(kSeqSteps[i].key) ||
                        (!_closed.contains(kSeqSteps[i].key) &&
                            i == _currentIndex(sel.checks)),
                    onToggleOpen: () => setState(() {
                      final k = kSeqSteps[i].key;
                      final isOpen = _opened.contains(k) ||
                          (!_closed.contains(k) &&
                              i == _currentIndex(sel!.checks));
                      if (isOpen) {
                        _opened.remove(k);
                        _closed.add(k);
                      } else {
                        _closed.remove(k);
                        _opened.add(k);
                      }
                    }),
                    onCheck: (key, v) => _patchChecks(sel!, {key: v}),
                    onNote: (key, text) => _patchChecks(sel!, {key: text}),
                    onVerdict: (v) => _setVerdict(sel!, v),
                    onProjectZone: (v) => _setProjectZone(sel!, v),
                    onGoTab: widget.onGoTab,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// 머리말 — 이 탭이 뭔지 한 줄
// ══════════════════════════════════════════════════════════

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withValues(alpha: 0.3)),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.format_list_numbered_rounded, size: 18, color: _teal),
        Gap(10),
        Expanded(
          child: Text(
            '입찰 «전»에 밟는 11단계. 손품으로 거르고 → 전화로 확인하고 → 임장으로 굳힌다.\n'
            '앱이 이미 아는 것(구역·권리산정일·매수 구간·실투자금)은 판정으로 보여주고, 나머지만 체크한다.',
            style: TextStyle(
                fontSize: AppFont.label,
                color: AppColors.textSecondary,
                height: 1.55),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 물건 칩
// ══════════════════════════════════════════════════════════

class _PropChip extends StatelessWidget {
  final AuctionProperty p;
  final bool selected;
  final int progress; // 현재 단계 번호(0부터)
  final VoidCallback onTap;
  const _PropChip(
      {required this.p,
      required this.selected,
      required this.progress,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final allDone = _currentIndex(p.checks) == kSeqSteps.length - 1 &&
        _stepDone(kSeqSteps.last, p.checks);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _teal.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: selected ? _teal : AppColors.border,
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(p.title,
              style: TextStyle(
                  color: selected ? _teal : AppColors.textSecondary,
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w700)),
          const Gap(7),
          Text(allDone ? '완료' : '${progress + 1}/${kSeqSteps.length}',
              style: TextStyle(
                  color: allDone ? AppColors.primary : AppColors.textFaint,
                  fontSize: AppFont.micro,
                  fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 전체 진행 — 11칸 막대
// ══════════════════════════════════════════════════════════

class _Overview extends StatelessWidget {
  final AuctionProperty p;
  final VoidCallback onOpen;
  const _Overview({required this.p, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cur = _currentIndex(p.checks);
    final done = kSeqSteps.where((s) => _stepDone(s, p.checks)).length;
    return GlassCard(
      accent: _teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.w800)),
                  if ((p.address ?? '').isNotEmpty) ...[
                    const Gap(3),
                    Text(p.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppFont.label,
                            color: AppColors.textFaint)),
                  ],
                ],
              ),
            ),
            const Gap(8),
            Text('$done/${kSeqSteps.length} 단계',
                style: const TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w900,
                    color: _teal)),
            IconButton(
              tooltip: '물건 상세',
              onPressed: onOpen,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.open_in_new_rounded,
                  size: 17, color: AppColors.textFaint),
            ),
          ]),
          const Gap(12),
          // 칸 하나가 단계 하나. 끝낸 건 색, 지금 건 테두리, 남은 건 흐리게.
          Row(children: [
            for (var i = 0; i < kSeqSteps.length; i++) ...[
              Expanded(
                child: Tooltip(
                  message: '${i + 1}. ${kSeqSteps[i].label}',
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _stepDone(kSeqSteps[i], p.checks)
                          ? kSeqSteps[i].color
                          : (i == cur
                              ? kSeqSteps[i].color.withValues(alpha: 0.35)
                              : AppColors.surfaceAlt),
                      borderRadius: BorderRadius.circular(4),
                      border: i == cur
                          ? Border.all(color: kSeqSteps[i].color, width: 1.2)
                          : null,
                    ),
                  ),
                ),
              ),
              if (i < kSeqSteps.length - 1) const Gap(3),
            ],
          ]),
          const Gap(10),
          Row(children: [
            Icon(kSeqSteps[cur].icon, size: 15, color: kSeqSteps[cur].color),
            const Gap(7),
            Expanded(
              child: Text(
                  done == kSeqSteps.length
                      ? '11단계 다 밟았다 — 투자 포인트가 다 채워졌으면 입찰한다'
                      : '지금 — ${cur + 1}. ${kSeqSteps[cur].label}',
                  style: TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w800,
                      color: kSeqSteps[cur].color)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 단계 카드
// ══════════════════════════════════════════════════════════

class _StepCard extends StatefulWidget {
  final int index;
  final SeqStep step;
  final AuctionProperty p;
  final Zone? zone;
  final EffectivePrice price;
  final bool open;
  final VoidCallback onToggleOpen;
  final void Function(String key, bool v) onCheck;
  final void Function(String key, String text) onNote;
  final void Function(String v) onVerdict;
  final void Function(String v) onProjectZone;
  final void Function(int tabId) onGoTab;

  const _StepCard({
    required this.index,
    required this.step,
    required this.p,
    required this.zone,
    required this.price,
    required this.open,
    required this.onToggleOpen,
    required this.onCheck,
    required this.onNote,
    required this.onVerdict,
    required this.onProjectZone,
    required this.onGoTab,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    final checks = widget.p.checks;
    final done = _stepDone(s, checks);
    final ratio = _stepProgress(s, checks);
    final c = s.color;

    return GlassCard(
      accent: widget.open ? c : (done ? c.withValues(alpha: 0.5) : null),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 머리 ─────────────────────────────────────────
          InkWell(
            onTap: widget.onToggleOpen,
            borderRadius: BorderRadius.circular(Insets.radius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? c : c.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          size: 17, color: Color(0xFF0B0F1A))
                      : Text('${widget.index + 1}',
                          style: TextStyle(
                              color: c,
                              fontSize: AppFont.label,
                              fontWeight: FontWeight.w900)),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label,
                          style: TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w800,
                              color: done && !widget.open
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary)),
                      const Gap(2),
                      Text(s.goal,
                          maxLines: widget.open ? null : 1,
                          overflow: widget.open ? null : TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppFont.caption,
                              color: AppColors.textSecondary,
                              height: 1.45)),
                    ],
                  ),
                ),
                const Gap(8),
                if (!done && ratio > 0)
                  Text('${(ratio * 100).round()}%',
                      style: TextStyle(
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.w900,
                          color: c)),
                const Gap(4),
                Icon(
                    widget.open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textFaint),
              ]),
            ),
          ),

          // ── 몸통 ─────────────────────────────────────────
          if (widget.open) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._judgement(context),
                  if (s.key == 'points')
                    _PointsBody(
                        p: widget.p,
                        onNote: widget.onNote,
                        onVerdict: widget.onVerdict)
                  else ...[
                    for (final it in s.items)
                      _CheckRow(
                        item: it,
                        on: checks[it.key] == true,
                        color: c,
                        onTap: () =>
                            widget.onCheck(it.key, checks[it.key] != true),
                      ),
                    if (s.noteHint != null) ...[
                      const Gap(10),
                      _NoteField(
                        key: ValueKey('${widget.p.id}:${s.noteKey}'),
                        initial: (checks[s.noteKey] ?? '').toString(),
                        hint: s.noteHint!,
                        color: c,
                        onSave: (t) => widget.onNote(s.noteKey, t),
                      ),
                    ],
                  ],
                  if (s.tab != null) ...[
                    const Gap(12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onGoTab(s.tab!),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c,
                          side: BorderSide(color: c.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.arrow_outward_rounded, size: 14),
                        label: Text('${s.tabLabel} 탭으로',
                            style: const TextStyle(
                                fontSize: AppFont.label,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 앱이 이미 아는 것으로 내리는 «판정». 단계마다 다르다.
  List<Widget> _judgement(BuildContext context) {
    final p = widget.p;
    final z = widget.zone;
    switch (widget.step.key) {
      case 'zone':
        if (z == null) {
          return [
            const _Judge(
                icon: Icons.help_outline_rounded,
                color: AppColors.textFaint,
                label: '구역 못 찾음',
                body: '주소로 구역을 못 찾았다. 물건 상세에서 단지를 연결하거나 주소를 구역 대표지번으로 맞춘다.'),
            const Gap(10),
          ];
        }
        return [
          _Judge(
              icon: Icons.map_rounded,
              color: z.isSin ? AppColors.violet : _teal,
              label: '${z.kind} · ${z.name}',
              body: '단계 ${z.stage} ${z.stageLabel}'
                  '${z.consentRate > 0 ? ' · 동의율 ${z.consentRate.toStringAsFixed(0)}%' : ''}'
                  '${z.stalledMonths != null ? ' · 이 단계 ${z.stalledMonths}개월째' : ''}'
                  '${z.portalMissing ? ' · 포털 미등재(보류)' : ''}'),
          const Gap(8),
          Row(children: [
            const Text('사업시행구역',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textSecondary)),
            const Gap(10),
            _MiniChip('미해당 (OK)', p.projectZone == 'out', AppColors.primary,
                () => widget.onProjectZone('out')),
            const Gap(6),
            _MiniChip('해당 (늦었다)', p.projectZone == 'in', AppColors.rose,
                () => widget.onProjectZone('in')),
          ]),
          const Gap(12),
        ];

      case 'criteria':
        final price = p.officialPrice;
        final profit = p.netProfit;
        final under = price > 0 && price <= 100000000;
        return [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Judge(
                dense: true,
                icon: price <= 0
                    ? Icons.help_outline_rounded
                    : (under ? Icons.check_circle_rounded : Icons.info_rounded),
                color: price <= 0
                    ? AppColors.textFaint
                    : (under ? AppColors.primary : AppColors.gold),
                label: price <= 0
                    ? '공시가 미입력'
                    : '공시가 ${Won.compact(price)}원 · ${under ? '1억 이하' : '1억 초과'}'),
            if (!under && price > 0)
              _Judge(
                  dense: true,
                  icon: profit >= 30000000
                      ? Icons.check_circle_rounded
                      : Icons.dangerous_rounded,
                  color: profit >= 30000000 ? AppColors.primary : AppColors.rose,
                  label: '예상순수익 ${Won.compact(profit)}원 · '
                      '${profit >= 30000000 ? '3천 이상' : '3천 미달'}'),
            if (p.corpStatus != null)
              _Judge(
                  dense: true,
                  icon: Icons.business_rounded,
                  color: switch (p.corpStatus) {
                    'ok' => AppColors.primary,
                    'heavy' => AppColors.rose,
                    _ => AppColors.gold,
                  },
                  label: switch (p.corpStatus) {
                    'ok' => '법인 가능',
                    'heavy' => '법인 중과',
                    _ => '법인 확인 필요',
                  }),
          ]),
          if (price <= 0) ...[
            const Gap(6),
            const Text('공시가는 물건 카드의 「다음에 채울 것」이나 상세에서 넣는다.',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
          ],
          const Gap(12),
        ];

      case 'rights_date':
        final r = rightsCheck(p, z);
        final base = z?.rightsDate;
        return [
          _Judge(
              icon: r.icon,
              color: r.color,
              label: r.label,
              body: '${base == null ? '' : '기준일 ${Dates.ymd(base)} · '}'
                  '${z == null ? '' : (z.isSin ? '신통 = 보존등기 접수일' : '모아 = 허가·착공신고일')}'
                  '\n${r.why}'),
          if (r == RightsCheck.needBuildDate) ...[
            const Gap(6),
            Text('다음에 뗄 것 — ${rightsNeedLabel(p, z)}',
                style: const TextStyle(
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold)),
            Text(rightsNeedWhy(p, z),
                style: const TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ],
          const Gap(12),
        ];

      case 'timing':
        final b = bandOfZone(z);
        return [
          _Judge(
              icon: b.icon,
              color: b.color,
              label: b.label,
              body: '${b.short}\n${b.why}'),
          if (hasDropRisk(z)) ...[
            const Gap(6),
            const Text(kDropRiskNote,
                style: TextStyle(
                    fontSize: AppFont.caption,
                    color: AppColors.rose,
                    height: 1.5)),
          ],
          const Gap(12),
        ];

      case 'deals':
        final pr = widget.price;
        return [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Judge(
                dense: true,
                icon: Icons.sell_rounded,
                color: pr.sale > 0 ? AppColors.primary : AppColors.textFaint,
                label: pr.sale > 0
                    ? '매매 ${Won.compact(pr.sale)}원 · ${pr.label}'
                    : '매매 시세 없음'),
            _Judge(
                dense: true,
                icon: Icons.key_rounded,
                color: pr.jeonse > 0 ? AppColors.sky : AppColors.textFaint,
                label: pr.jeonse > 0
                    ? '전세 ${Won.compact(pr.jeonse)}원'
                        '${p.bidPrice > 0 && pr.jeonse >= p.bidPrice ? ' · 플피 가능' : ''}'
                    : '전세 시세 없음'),
            if (pr.stale)
              _Judge(
                  dense: true,
                  icon: Icons.schedule_rounded,
                  color: AppColors.gold,
                  label: '단지 조사 ${pr.ageDays}일 전 · 갱신'),
          ]),
          const Gap(12),
        ];

      case 'cash':
        final plus = p.isPlus;
        return [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Judge(
                dense: true,
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.gold,
                label: plus
                    ? (p.ownCash <= 0
                        ? '플피 ${Won.compact(p.plusPi)}원'
                        : '실투자금 ${Won.compact(p.ownCash)}원')
                    : '필요현금 ${Won.compact(p.cashNeeded)}원'),
            _Judge(
                dense: true,
                icon: p.netProfit >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: p.netProfit >= 0 ? AppColors.primary : AppColors.rose,
                label: '예상순수익 ${Won.compact(p.netProfit)}원'),
            _Judge(
                dense: true,
                icon: Icons.flag_rounded,
                color: AppColors.sky,
                label: '최대입찰가 ${Won.compact(p.maxBid)}원'),
          ]),
          if (p.bidPrice <= 0) ...[
            const Gap(6),
            const Text('예상입찰가가 0이다 — 「계산기」 탭이나 물건 상세에서 숫자를 먼저 넣는다.',
                style: TextStyle(
                    fontSize: AppFont.caption, color: AppColors.textFaint)),
          ],
          const Gap(12),
        ];

      default:
        return const [];
    }
  }
}

/// 판정 한 줄 — 아이콘 + 라벨 (+ 설명).
class _Judge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? body;
  final bool dense;
  const _Judge(
      {required this.icon,
      required this.color,
      required this.label,
      this.body,
      this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 12, vertical: dense ? 7 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const Gap(8),
          if (dense)
            Text(label,
                style: TextStyle(
                    fontSize: AppFont.label,
                    fontWeight: FontWeight.w900,
                    color: color))
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  if (body != null && body!.trim().isNotEmpty) ...[
                    const Gap(3),
                    Text(body!.trim(),
                        style: const TextStyle(
                            fontSize: AppFont.caption,
                            color: AppColors.textSecondary,
                            height: 1.5)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final bool on;
  final Color color;
  final VoidCallback onTap;
  const _MiniChip(this.label, this.on, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: on ? color : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w800,
                color: on ? color : AppColors.textSecondary)),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final SeqItem item;
  final bool on;
  final Color color;
  final VoidCallback onTap;
  const _CheckRow(
      {required this.item,
      required this.on,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
                on
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 22,
                color: on ? color : AppColors.textFaint),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: on
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1.35)),
                if (item.hint != null) ...[
                  const Gap(3),
                  Text(item.hint!,
                      style: const TextStyle(
                          fontSize: AppFont.caption,
                          color: AppColors.textFaint,
                          height: 1.5)),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// 메모 한 칸 — 고치면 저장 버튼이 뜬다. 포커스를 잃어도 저장한다.
class _NoteField extends StatefulWidget {
  final String initial;
  final String hint;
  final Color color;
  final void Function(String) onSave;
  final String? label;
  final int minLines;
  const _NoteField(
      {super.key,
      required this.initial,
      required this.hint,
      required this.color,
      required this.onSave,
      this.label,
      this.minLines = 2});

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _c = PlainController(text: widget.initial);
  late String _saved = widget.initial;

  bool get _dirty => _c.text.trim() != _saved.trim();

  void _save() {
    if (!_dirty) return;
    _saved = _c.text;
    widget.onSave(_c.text.trim());
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!,
              style: TextStyle(
                  fontSize: AppFont.label,
                  fontWeight: FontWeight.w800,
                  color: widget.color)),
          const Gap(5),
        ],
        Focus(
          onFocusChange: (has) {
            if (!has) _save();
          },
          child: TextField(
            controller: _c,
            minLines: widget.minLines,
            maxLines: null,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: AppFont.label, height: 1.5),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                  fontSize: AppFont.caption, color: AppColors.textFaint),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _dirty
                  ? IconButton(
                      tooltip: '저장',
                      onPressed: _save,
                      icon: Icon(Icons.save_rounded,
                          size: 18, color: widget.color),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// 11. 투자 포인트 — 다섯 줄 + 할까?
// ══════════════════════════════════════════════════════════

class _PointsBody extends StatelessWidget {
  final AuctionProperty p;
  final void Function(String key, String text) onNote;
  final void Function(String v) onVerdict;
  const _PointsBody(
      {required this.p, required this.onNote, required this.onVerdict});

  Color _vColor(String v) => switch (v) {
        'GO' => AppColors.primary,
        'PASS' => AppColors.rose,
        _ => AppColors.gold,
      };

  @override
  Widget build(BuildContext context) {
    final filled = kSeqPoints
        .where((e) => (p.checks[e.$1] ?? '').toString().trim().isNotEmpty)
        .length;
    final all = filled == kSeqPoints.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (key, label, hint) in kSeqPoints) ...[
          _NoteField(
            key: ValueKey('${p.id}:$key'),
            label: label,
            initial: (p.checks[key] ?? '').toString(),
            hint: hint,
            color: _indigo,
            minLines: 1,
            onSave: (t) => onNote(key, t),
          ),
          const Gap(10),
        ],
        const Gap(4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (all ? AppColors.primary : AppColors.rose)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(all ? Icons.verified_rounded : Icons.block_rounded,
                size: 16, color: all ? AppColors.primary : AppColors.rose),
            const Gap(8),
            Expanded(
              child: Text(
                  all
                      ? '다섯 줄 다 채웠다 — 입찰할 수 있다'
                      : '$filled/${kSeqPoints.length} — 다섯 줄을 다 채우지 못하면 입찰하지 않는다',
                  style: TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w800,
                      color: all ? AppColors.primary : AppColors.rose)),
            ),
          ]),
        ),
        const Gap(12),
        Row(children: [
          const Text('할까?',
              style: TextStyle(
                  fontSize: AppFont.label,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700)),
          const Gap(10),
          for (final (v, label) in const [
            ('GO', '할래'),
            ('HOLD', '보류'),
            ('PASS', '패스')
          ]) ...[
            _MiniChip(label, p.verdict == v, _vColor(v), () => onVerdict(v)),
            const Gap(6),
          ],
        ]),
      ],
    );
  }
}
