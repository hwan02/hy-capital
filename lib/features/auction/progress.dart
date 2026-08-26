// 경매를 «순서대로» 끌고 가기 위한 단계 정의.
//
// 물건 하나는 반드시 이 9단계를 지난다.
//   찾기 → 권리분석 → 임장 → 입찰 → 낙찰·잔금 → 명도 → 수리 → 출구 → 정산
//
// 낙찰이 끝이 아니다. 명도도 끝이 아니다.
// 돈은 «출구»(전세·월세·매도)에서 나오고, 배움은 «정산»에서 나온다.
// 그리고 낙찰 다음날부터 대출이자가 나가므로 «비어 있는 날이 곧 비용»이다.
//
// 각 단계는 «할 일»을 갖는다. 체크는 물건의 checklist jsonb 에 저장한다 —
// 새 테이블을 만들지 않는다. 물건 하나가 진실의 원천이다.
//
// 여기 적힌 할 일은 자료실에서 나온 것이다.
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 단계 하나. `status` 는 auction_properties.status 값과 1:1로 맞춘다.
class Stage {
  final String status;
  final String label;
  final String goal; // 이 단계에서 «끝내야 하는 것» 한 줄
  final IconData icon;
  final Color color;
  final List<StageTask> tasks;

  const Stage({
    required this.status,
    required this.label,
    required this.goal,
    required this.icon,
    required this.color,
    required this.tasks,
  });
}

/// 할 일 하나. `key` 는 checklist jsonb 의 키.
class StageTask {
  final String key;
  final String label;
  final String? hint; // 왜 / 어떻게 — 모르면 여기서 배운다

  /// 이 전략에서만 보여준다. null 이면 항상.
  /// flip=아파트 차익형 · plus=모아·신속 빌라 플피
  final String? only;

  const StageTask(this.key, this.label, {this.hint, this.only});
}

const _teal = Color(0xFF14B8A6);
const _amber = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);

/// 경매 진행 9단계. 순서가 곧 화면 순서다.
const kStages = <Stage>[
  // ── 1 ────────────────────────────────────────────────────
  Stage(
    status: 'interest',
    label: '찾기',
    goal: '내 기준을 통과하는 물건을 «등록»한다',
    icon: Icons.search_rounded,
    color: AppColors.textSecondary,
    tasks: [
      StageTask('f_criteria', '내 기준부터 정했나',
          hint: '「기준」 탭의 필터를 먼저 확정한다. 기준 없이 보면 매번 흔들린다.'),
      StageTask('f_search', '경매·공매 사이트에서 검색했나',
          hint: '법원경매·행크옥션(경매) + 온비드(공매). 공매는 전자입찰이라 원거리도 된다.'),
      StageTask('f_paste', '물건을 앱에 등록했나',
          hint: '「＋」로 사이트 텍스트를 통째로 붙여넣으면 사건번호·감정가·기일이 자동으로 들어간다.'),
      StageTask('f_ledger', '건축물대장을 봤나',
          hint: '«위반건축물»이면 이행강제금이 매년 나온다. «대지권 미등기»면 대출도 매도도 막힌다 — 빌라의 대표 함정.'),
      StageTask('f_price1', '시세를 1차로 확인했나',
          hint: '네이버·실거래·KB 세 곳. 단지에 연결하면 시세를 상속받는다.'),
      StageTask('f_kind', '전략을 정했나 — 차익형(flip) / 플피(plus)',
          hint: '모아·신속 선정지 빌라면 플피, 아파트면 차익형. 전략이 다르면 보는 숫자가 다르다.'),
      StageTask('f_pass', '기준 6개를 통과하나',
          hint: '플피 전략은 선정지·속도·저가·전세·사업성·타이밍 6개를 다 만족해야 전제가 선다.'),
    ],
  ),

  // ── 2 ────────────────────────────────────────────────────
  Stage(
    status: 'researching',
    label: '권리분석',
    goal: '«인수할 금액»을 숫자로 확정한다',
    icon: Icons.gavel_rounded,
    color: AppColors.violet,
    tasks: [
      StageTask('r_base', '말소기준권리를 찾았나',
          hint: '등기부에서 가장 앞선 (근)저당·압류·가압류·경매개시결정. 이 뒤는 원칙적으로 다 소멸한다.'),
      StageTask('r_movein', '임차인 전입일을 확인했나',
          hint: '전입세대열람. 전입일이 말소기준보다 «늦으면» 대항력 없음 — 제일 흔한 안전 케이스.'),
      StageTask('r_merge', '«세대합가»를 확인했나',
          hint: '세대주가 바뀌면 전입일이 늦어 보인다. 세대원 «전체»의 최초 전입일을 봐야 한다 — 늦은 줄 알았는데 대항력이 살아있는 함정.'),
      StageTask('r_names', '소유자 / 채무자 / 점유자 «이름 셋»을 겹쳐봤나',
          hint: '갑구 소유자 ≠ 근저당 채무자인데 그 채무자가 점유자면 물상보증 구조 → 가족·위장임차 의심.'),
      StageTask('r_bank', '근저당이 있는데 선순위 전입자가 있나',
          hint: '은행은 무상거주확인서를 받아두고 대출한다. 근저당 존재 자체가 임차를 실질로 안 봤다는 정황.'),
      StageTask('r_claim', '배당요구를 했나 · 종기일은 언제인가',
          hint: '배당요구했고 보증금이 전액 배당되면 인수액 0. 종기일 이후 배당요구는 효력이 없다.'),
      StageTask('r_docs', '서류 4종을 다 읽었나',
          hint: '매각물건명세서 · 현황조사서 · 감정평가서 · 등기부. 공매는 압류재산명세서.'),
      StageTask('r_special', '특수권리를 확인했나',
          hint: '유치권 · 법정지상권 · 지분 · 선순위 가등기/가처분. 하나라도 있으면 초보는 넘긴다.'),
      StageTask('r_amount', '인수 금액을 «숫자»로 적었나',
          hint: '0원이면 0원이라고 적는다. 모르면 들어가지 않는다 — 손실 규모를 계량할 수 없으면 베팅이 아니다.'),
    ],
  ),

  // ── 3 ────────────────────────────────────────────────────
  Stage(
    status: 'visited',
    label: '임장',
    goal: '서류에 «안 나오는» 감가 요인을 찾는다',
    icon: Icons.directions_walk_rounded,
    color: AppColors.sky,
    tasks: [
      StageTask('v_out', '외부 — 외벽·옥상·경사·주차',
          hint: '노후 빌라 탑층은 누수 위험이 크다. 옥상 확인은 필수.'),
      StageTask('v_window', '샷시(창호)를 밖에서 봤나',
          hint: '하이샷시로 교체돼 있으면 전 소유주가 수리한 것 — 수백만원 절감 신호.'),
      StageTask('v_mail', '우편함을 봤나',
          hint: '체납 고지서·법원 송달물이 쌓여 있으면 공실이거나 거주자 사정이 어렵다 → 명도 난이도 단서.'),
      StageTask('v_mgmt', '관리사무소에서 «미납관리비»를 확인했나',
          hint: '공용부 3년치는 낙찰자 부담이 될 수 있다. 금액을 받아 적어 비용에 넣는다.'),
      StageTask('v_occupant', '점유자를 확인했나',
          hint: '누가 실제로 사는지. 명도 계획과 명도비가 여기서 갈린다.'),
      StageTask('v_agent', '부동산 3곳에서 시세를 들었나',
          hint: '급매가 · 평균가 · 전세 · 월세. 책상 시세(네이버·KB)와 어긋나면 «현장이 맞다».'),
      StageTask('v_repair', '수리 범위를 «눈으로» 가늠했나',
          hint: '올수리 / 부분 / 청소만. 여기서 매긴 금액이 그대로 입찰가를 깎는다.'),
      StageTask('v_photo', '사진을 남겼나',
          hint: '항목별로 찍어둔다. 며칠 지나면 기억이 안 난다.'),
      StageTask('v_exit', '출구를 확정했나 — 매도 / 전세 / 월세',
          hint: '플피면 전세가 ≥ 낙찰가인지 «입찰 전»에 확인한다. 나중엔 늦다.'),
    ],
  ),

  // ── 4 ────────────────────────────────────────────────────
  Stage(
    status: 'bidding',
    label: '입찰',
    goal: '«최대 입찰가»를 정하고 기일에 실수 없이 낸다',
    icon: Icons.how_to_vote_rounded,
    color: AppColors.gold,
    tasks: [
      StageTask('b_max', '최대 입찰가를 «미리» 적었나',
          hint: '낙찰가 + 수리비 + 명도비 + 인수금액 < 급매가. 현장에서 즉흥으로 올리지 않는다.'),
      StageTask('b_name', '«명의»를 정했나',
          hint: '주택수에 따라 취득세가 중과되고 대출 한도도 달라진다. 공동입찰이면 지분도 미리 정한다.'),
      StageTask('b_cash', '필요 현금이 준비됐나',
          hint: '보증금 + 잔금 중 대출 안 되는 부분 + 취득세 + 수리비 + 명도비 + 미납관리비.'),
      StageTask('b_loan', '경락잔금대출 한도를 확인했나',
          hint: '규제지역·주택수·생애최초 여부로 LTV가 갈린다. 자료실 「경락잔금대출 한도」 참고.'),
      StageTask('b_deposit', '보증금을 «수표 1장»으로 준비했나',
          hint: '최저가의 10%. «재매각 물건은 20~30%»니 사건 내역을 꼭 본다.'),
      StageTask('b_form', '기일입찰표를 미리 써놨나',
          hint: '현장에서 쓰면 «0»을 하나 더 붙이는 사고가 난다. 집에서 쓰고 검산한다.'),
      StageTask('b_id', '신분증·도장을 챙겼나',
          hint: '대리입찰이면 위임장 + 인감증명서까지.'),
      StageTask('b_recheck', '당일 아침에 등기부를 «다시» 발급했나',
          hint: '조사 후 권리가 바뀌었을 수 있다. 법원 발급기에서 최종본을 뽑는다.'),
      StageTask('b_cancel', '취하·변경·연기를 확인했나',
          hint: '헛걸음을 막는다. 사건 진행내역을 당일 아침에 본다.'),
      StageTask('b_second', '(패찰 시) 차순위매수신고를 할지 정했나',
          hint: '최고가와 차이가 보증금 이내일 때만 가능. 신고하면 보증금이 묶이므로 득실을 따진다.'),
    ],
  ),

  // ── 5 ────────────────────────────────────────────────────
  Stage(
    status: 'won',
    label: '낙찰·잔금',
    goal: '기한 안에 «잔금»을 내고 소유권을 넘겨받는다',
    icon: Icons.emoji_events_rounded,
    color: AppColors.primary,
    tasks: [
      StageTask('w_permit', '매각허가결정을 확인했나',
          hint: '보통 1주 뒤 허가, 다시 1주 뒤 확정. 이때부터 잔금 기한이 돈다.'),
      StageTask('w_appeal', '매각불허가 사유·즉시항고가 없나',
          hint: '허가결정 후 «7일»이 항고 기간. 이 안에 뒤집힐 수 있으니 큰돈을 미리 움직이지 않는다.'),
      StageTask('w_due', '잔금 기한을 «달력에 박았나»',
          hint: '넘기면 보증금을 몰수당한다. 아래 「잔금 기한」에 날짜를 넣으면 슬랙으로 알려준다.'),
      StageTask('w_loanexec', '경락잔금대출을 신청했나',
          hint: '허가 확정 직후 바로 움직인다. 은행 심사에 시간이 걸린다.'),
      StageTask('w_pay', '잔금을 납부했나',
          hint: '납부와 «동시에» 소유권이 넘어온다. 인도명령도 이때부터 신청 가능.'),
      StageTask('w_tax', '취득세를 냈나',
          hint: '잔금 납부일로부터 «60일» 이내. 주택수에 따라 중과될 수 있다.'),
      StageTask('w_reg', '소유권이전등기를 마쳤나',
          hint: '법원 촉탁등기. 말소될 권리들이 «실제로» 지워졌는지 등기부로 확인한다.'),
      StageTask('w_insure', '화재보험에 들었나',
          hint: '대출이 있으면 보통 요구한다. 잊기 쉬운 항목.'),
    ],
  ),

  // ── 6 ────────────────────────────────────────────────────
  Stage(
    status: 'evicting',
    label: '명도',
    goal: '점유자를 내보내고 «열쇠»를 받는다',
    icon: Icons.key_rounded,
    color: AppColors.rose,
    tasks: [
      StageTask('e_order', '인도명령을 신청했나',
          hint: '잔금 납부와 «동시에» 신청한다. 6개월이 지나면 명도소송으로 가야 해서 훨씬 오래 걸린다.'),
      StageTask('e_contact', '점유자를 만나 이야기했나',
          hint: '먼저 대화한다. 대부분은 협상으로 끝난다 — 소송·집행은 비용도 시간도 크다.'),
      StageTask('e_deal', '이사비를 합의했나',
          hint: '강제집행 비용보다 싸면 주는 게 이득이다. 합의 이사일을 아래 「명도 목표일」에 적는다.'),
      StageTask('e_paper', '명도합의서를 썼나',
          hint: '이사 날짜 · 이사비 지급 시점 · 관리비 정산까지 한 장에 적는다.'),
      StageTask('e_util', '미납관리비·공과금을 정산했나',
          hint: '공용부는 낙찰자 부담이 될 수 있다. 이사 «전»에 끝낸다.'),
      StageTask('e_confirm', '명도확인서를 줬나',
          hint: '임차인이 배당받으려면 이게 필요하다. 열쇠와 «맞바꾼다».'),
      StageTask('e_key', '열쇠를 받고 점유를 확보했나',
          hint: '받는 즉시 현관 잠금을 교체한다.'),
      StageTask('e_force', '(불응 시) 강제집행을 예고했나',
          hint: '인도명령 결정문 → 집행문 → 계고 → 강제집행. 예고만으로 풀리는 경우가 많다.'),
    ],
  ),

  // ── 7 ────────────────────────────────────────────────────
  Stage(
    status: 'repairing',
    label: '수리',
    goal: '«팔리는 상태 / 세 나가는 상태»로 만든다',
    icon: Icons.handyman_rounded,
    color: _amber,
    tasks: [
      StageTask('p_scope', '수리 범위를 정했나 — 올수리 / 부분 / 청소만',
          hint: '임장 때 가늠한 것과 실제를 맞춰본다. 범위가 커지면 «출구 가격»도 같이 올려야 말이 된다.'),
      StageTask('p_leak', '«누수»부터 잡았나',
          hint: '도배·바닥을 먼저 하면 다시 뜯는다. 물 → 전기 → 마감 순서가 원칙.'),
      StageTask('p_quote', '견적을 «3곳» 받았나',
          hint: '같은 범위로 비교해야 의미가 있다. 항목별 단가를 받아둔다.'),
      StageTask('p_budget', '입찰 때 잡은 수리비 안에 들어오나',
          hint: '초과하면 수익이 그만큼 사라진다. 물건 상세의 「수리·인테리어」 금액을 실제값으로 고친다.'),
      StageTask('p_concept', '타깃에 맞는 컨셉인가',
          hint: '누가 살 집인지 정하고 거기 맞춘다. 1인·신혼이면 화이트 톤이 무난하다.'),
      StageTask('p_photo', 'before / after 사진을 찍었나',
          hint: '매물 광고에 그대로 쓴다. 청소 «전»에 찍어두면 대비가 산다.'),
      StageTask('p_clean', '입주청소를 넣었나',
          hint: '수리 마지막 순서. 이게 안 되면 아무리 고쳐도 안 팔린다.'),
      StageTask('p_done', '하자를 최종 점검했나',
          hint: '보일러·급배수·전기·문·창 여닫힘. 세입자 들이고 나서 부르면 훨씬 비싸다.'),
    ],
  ),

  // ── 8 ────────────────────────────────────────────────────
  Stage(
    status: 'exiting',
    label: '출구',
    goal: '«돈을 회수»한다 — 매도 또는 전세·월세 세팅',
    icon: Icons.exit_to_app_rounded,
    color: _indigo,
    tasks: [
      StageTask('x_price', '출구 가격을 확정했나',
          hint: '임장 때 들은 급매가·전세가를 기준으로. 대출이자가 매달 나가므로 «비어 있는 날이 곧 비용»이다.'),
      StageTask('x_list', '부동산 3곳 이상에 내놨나',
          hint: '한 곳에만 맡기면 늦어진다. 사진·설명을 직접 만들어 보내면 훨씬 빨리 걸린다.'),
      StageTask('x_photo', '매물 사진을 제대로 올렸나',
          hint: '낮에, 불 다 켜고, 넓게. 첫 사진 한 장이 문의 수를 가른다.'),

      // 차익형
      StageTask('x_buyer', '매수자를 잡았나', only: 'flip',
          hint: '계약금 → 중도금 → 잔금 일정을 대출 상환 일정과 맞춘다.'),
      StageTask('x_tax', '양도세를 계산해봤나', only: 'flip',
          hint: '«보유 기간»이 세율을 가른다. 단기 매도는 세금이 수익을 다 먹을 수 있다 — 팔기 «전»에 계산한다.'),

      // 플피
      StageTask('x_jeonse', '전세가가 낙찰가+비용을 넘나', only: 'plus',
          hint: '이게 넘어야 «플피»다. 못 넘으면 투자금이 묶인다 — 월세 전환도 같이 검토한다.'),
      StageTask('x_deposit', '전세보증보험 가입이 되는 물건인가', only: 'plus',
          hint: '요즘 세입자는 이걸 먼저 본다. 안 되면 전세가 안 나가거나 값을 깎인다.'),
      StageTask('x_hug', '전세 세팅으로 대출을 정리했나', only: 'plus',
          hint: '경락잔금대출을 전세보증금으로 상환하는 구조인지, 병존 가능한지 은행에 미리 확인.'),

      StageTask('x_contract', '계약서를 썼나',
          hint: '특약을 챙긴다. 잔금일·명도일·수리 책임 범위.'),
      StageTask('x_close', '잔금을 받았나',
          hint: '받는 즉시 대출을 정리하고 아래 「정산」으로 넘어간다.'),
    ],
  ),

  // ── 9 ────────────────────────────────────────────────────
  Stage(
    status: 'settling',
    label: '정산',
    goal: '«실제로 얼마 벌었나»를 확정하고 다음에 쓴다',
    icon: Icons.receipt_long_rounded,
    color: _teal,
    tasks: [
      StageTask('s_real', '실제 숫자로 다 고쳤나',
          hint: '낙찰가·수리비·명도비·이자·세금을 «예상»이 아니라 «실제»로. 이걸 안 하면 다음 판단도 틀린다.'),
      StageTask('s_profit', '순수익과 수익률을 계산했나',
          hint: '회수액 − 총투입 = 순수익. 투입 대비 몇 %인지, 몇 달 걸렸는지까지 적는다.'),
      StageTask('s_flow', '자금 흐름에 반영했나',
          hint: '들어온 돈·나간 돈을 「자금 흐름」에 넣어야 전체 현금흐름이 맞는다.'),
      StageTask('s_tax', '세금 신고를 마쳤나',
          hint: '양도세는 «매도일이 속한 달의 말일부터 2개월» 이내 예정신고.'),
      StageTask('s_review', '회고를 적었나',
          hint: '입찰가는 적정했나 · 놓친 비용은 · 시간이 어디서 샜나. 물건 상세의 「원인분석」에 남긴다.'),
      StageTask('s_rule', '다음에 바꿀 «기준» 하나를 정했나',
          hint: '한 건에서 규칙 하나씩만 얻어도 열 건이면 열 개다. 「기준」 탭에 반영한다.'),
    ],
  ),
];

/// 최종 상태 — 단계 목록에는 없다.
const kDoneStatuses = {'sold', 'pass'};

/// 진행 화면 밖(목록·상세·필터)에서 쓰는 상태 이름·색.
/// «여기가 유일한 출처다» — 세 군데 흩어져 있던 것을 모았다.
final Map<String, String> kStatusLabel = {
  for (final s in kStages) s.status: s.label,
  'sold': '완료',
  'pass': 'PASS',
};

final Map<String, Color> kStatusColor = {
  for (final s in kStages) s.status: s.color,
  'sold': AppColors.textFaint,
  'pass': AppColors.rose,
};

/// 상태 선택 목록 (상세 화면·필터 칩용). 진행 순서 그대로.
final List<(String, String, Color)> kStatusOptions = [
  for (final s in kStages) (s.status, s.label, s.color),
  ('sold', '완료', AppColors.textFaint),
  ('pass', 'PASS', AppColors.rose),
];

/// status → 단계. 없으면 null (sold·pass).
Stage? stageOf(String status) {
  for (final s in kStages) {
    if (s.status == status) return s;
  }
  return null;
}

/// status 의 진행 순번 (0부터). 모르면 -1.
int stageIndex(String status) {
  for (var i = 0; i < kStages.length; i++) {
    if (kStages[i].status == status) return i;
  }
  return status == 'sold' ? kStages.length : -1;
}

/// 이 전략에 해당하는 할 일만.
List<StageTask> tasksFor(Stage s, String strategy) =>
    s.tasks.where((t) => t.only == null || t.only == strategy).toList();

/// 이 단계에서 «아직 안 한» 할 일.
List<StageTask> pendingTasks(
        Stage s, Map<String, dynamic> checklist, String strategy) =>
    tasksFor(s, strategy).where((t) => checklist[t.key] != true).toList();

/// 단계 진행률 0.0~1.0.
double stageProgress(
    Stage s, Map<String, dynamic> checklist, String strategy) {
  final all = tasksFor(s, strategy);
  if (all.isEmpty) return 1;
  final done = all.where((t) => checklist[t.key] == true).length;
  return done / all.length;
}

/// 물건 전체 진행률 — 지난 단계는 완료로 친다.
double overallProgress(
    String status, Map<String, dynamic> checklist, String strategy) {
  final idx = stageIndex(status);
  if (idx < 0) return 0;
  if (idx >= kStages.length) return 1;
  final within = stageProgress(kStages[idx], checklist, strategy);
  return (idx + within) / kStages.length;
}

/// 진행 화면의 강조색.
const kProgressAccent = _teal;
