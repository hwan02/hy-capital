// 경매를 «순서대로» 끌고 가기 위한 단계 정의.
//
// 물건 하나는 반드시 이 6단계를 지난다.
//   찾기 → 권리분석 → 임장 → 입찰 → 낙찰·잔금 → 명도 (→ 매도)
//
// 각 단계는 «할 일»을 갖는다. 체크는 물건의 checklist jsonb 에 저장한다 —
// 새 테이블을 만들지 않는다. 물건 하나가 진실의 원천이다.
//
// 여기 적힌 할 일은 자료실에서 나온 것이다. 근거가 있는 것은 출처를 달았다.
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
  const StageTask(this.key, this.label, {this.hint});
}

const _teal = Color(0xFF14B8A6);

/// 경매 진행 6단계. 순서가 곧 화면 순서다.
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
      StageTask('r_names', '소유자 / 채무자 / 점유자 «이름 셋»을 겹쳐봤나',
          hint: '갑구 소유자 ≠ 근저당 채무자인데 그 채무자가 점유자면 물상보증 구조 → 가족·위장임차 의심.'),
      StageTask('r_bank', '근저당이 있는데 선순위 전입자가 있나',
          hint: '은행은 무상거주확인서를 받아두고 대출한다. 근저당 존재 자체가 임차를 실질로 안 봤다는 정황.'),
      StageTask('r_claim', '배당요구를 했나',
          hint: '배당요구했고 보증금이 전액 배당되면 인수액 0. 배당요구종기일도 같이 본다.'),
      StageTask('r_docs', '서류 4종을 다 읽었나',
          hint: '매각물건명세서 · 현황조사서 · 감정평가서 · 등기부. 공매는 압류재산명세서.'),
      StageTask('r_amount', '인수 금액을 «숫자»로 적었나',
          hint: '0원이면 0원이라고 적는다. 모르면 들어가지 않는다 — 손실 규모를 계량할 수 없으면 베팅이 아니다.'),
      StageTask('r_special', '특수권리를 확인했나',
          hint: '유치권 · 법정지상권 · 지분 · 선순위 가등기/가처분. 하나라도 있으면 초보는 넘긴다.'),
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
          hint: '전용부 미납분은 낙찰자가 물어줄 수 있다. 금액을 받아 적는다.'),
      StageTask('v_occupant', '점유자를 확인했나',
          hint: '누가 실제로 사는지. 명도 계획이 여기서 갈린다.'),
      StageTask('v_agent', '부동산 3곳에서 시세를 들었나',
          hint: '급매가 · 평균가 · 전세 · 월세. 책상 시세(네이버·KB)와 어긋나면 현장이 맞다.'),
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
          hint: '낙찰가+수리비+명도비 < 급매가. 현장에서 즉흥으로 올리지 않는다.'),
      StageTask('b_cash', '필요 현금이 준비됐나',
          hint: '보증금 + 잔금 중 대출 안 되는 부분 + 취득세 + 수리비 + 명도비.'),
      StageTask('b_loan', '경락잔금대출 한도를 확인했나',
          hint: '규제지역·주택수·생애최초 여부로 LTV가 갈린다. 자료실 「경락잔금대출 한도」 참고.'),
      StageTask('b_deposit', '보증금을 «수표 1장»으로 준비했나',
          hint: '최저가의 10% (재매각은 20~30%). 수표 한 장이 세기 편하다.'),
      StageTask('b_form', '기일입찰표를 미리 써놨나',
          hint: '현장에서 쓰면 «0»을 하나 더 붙이는 사고가 난다. 집에서 쓰고 검산한다.'),
      StageTask('b_id', '신분증·도장을 챙겼나',
          hint: '대리입찰이면 위임장 + 인감증명서까지.'),
      StageTask('b_recheck', '당일 아침에 등기부를 «다시» 발급했나',
          hint: '조사 후 권리가 바뀌었을 수 있다. 법원 발급기에서 최종본을 뽑는다.'),
      StageTask('b_cancel', '취하·변경·연기를 확인했나',
          hint: '헛걸음을 막는다. 사건 진행내역을 당일 아침에 본다.'),
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
      StageTask('w_due', '잔금 기한을 «달력에 박았나»',
          hint: '넘기면 보증금을 몰수당한다. 이 앱의 「잔금」 날짜가 그것이다.'),
      StageTask('w_loanexec', '경락잔금대출을 신청했나',
          hint: '허가 확정 직후 바로 움직인다. 은행 심사에 시간이 걸린다.'),
      StageTask('w_pay', '잔금을 납부했나',
          hint: '납부와 «동시에» 소유권이 넘어온다. 인도명령도 이때부터 신청 가능.'),
      StageTask('w_tax', '취득세를 냈나',
          hint: '잔금 납부일로부터 60일 이내. 주택수에 따라 중과될 수 있다.'),
      StageTask('w_reg', '소유권이전등기를 마쳤나',
          hint: '법원 촉탁등기. 말소될 권리들이 실제로 지워졌는지 등기부로 확인한다.'),
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
          hint: '강제집행 비용보다 싸면 주는 게 이득이다. 합의 이사일을 「명도」 날짜에 적는다.'),
      StageTask('e_paper', '명도합의서를 썼나',
          hint: '이사 날짜 · 이사비 지급 시점 · 관리비 정산까지 한 장에 적는다.'),
      StageTask('e_util', '미납관리비·공과금을 정산했나',
          hint: '전용부는 낙찰자 부담이 되는 경우가 있다. 이사 «전»에 끝낸다.'),
      StageTask('e_confirm', '명도확인서를 줬나',
          hint: '임차인이 배당받으려면 이게 필요하다. 열쇠와 «맞바꾼다».'),
      StageTask('e_key', '열쇠를 받고 점유를 확보했나',
          hint: '받는 즉시 현관 잠금을 교체한다.'),
      StageTask('e_force', '(불응 시) 강제집행을 예고했나',
          hint: '인도명령 결정문 → 집행문 → 계고 → 강제집행. 예고만으로 풀리는 경우가 많다.'),
    ],
  ),
];

/// 최종 상태 — 단계 목록에는 없지만 물건은 여기로 끝난다.
const kDoneStatuses = {'sold', 'pass'};

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

/// 이 단계에서 «아직 안 한» 할 일. 없으면 빈 목록.
List<StageTask> pendingTasks(Stage s, Map<String, dynamic> checklist) =>
    s.tasks.where((t) => checklist[t.key] != true).toList();

/// 단계 진행률 0.0~1.0.
double stageProgress(Stage s, Map<String, dynamic> checklist) {
  if (s.tasks.isEmpty) return 1;
  final done = s.tasks.where((t) => checklist[t.key] == true).length;
  return done / s.tasks.length;
}

/// 물건 전체 진행률 — 지난 단계는 완료로 친다.
double overallProgress(String status, Map<String, dynamic> checklist) {
  final idx = stageIndex(status);
  if (idx < 0) return 0;
  if (idx >= kStages.length) return 1;
  final within = stageProgress(kStages[idx], checklist);
  return (idx + within) / kStages.length;
}

/// 진행 화면의 강조색.
const kProgressAccent = _teal;
