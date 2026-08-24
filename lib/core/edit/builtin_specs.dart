import '../theme/app_theme.dart';
import 'field_spec.dart';
import 'package:flutter/material.dart';

/// 기존(내장) 모듈의 편집 폼 정의: 테이블명 + 필드 + 강조색.
class BuiltinSpec {
  final String table;
  final String title;
  final Color accent;
  final List<FieldSpec> fields;
  const BuiltinSpec({
    required this.table,
    required this.title,
    required this.accent,
    required this.fields,
  });
}

const goalsSpec = BuiltinSpec(
  table: 'goals',
  title: '목표',
  accent: AppColors.violet,
  fields: [
    FieldSpec(key: 'title', label: '목표 이름', type: FieldType.text, required: true),
    FieldSpec(key: 'unit', label: '단위', type: FieldType.select, required: true,
        options: ['KRW', 'count', 'percent']),
    FieldSpec(key: 'target_value', label: '목표값', type: FieldType.number),
    FieldSpec(key: 'current_value', label: '현재값', type: FieldType.number),
    FieldSpec(key: 'target_date', label: '목표일', type: FieldType.date),
    FieldSpec(key: 'status', label: '상태', type: FieldType.select,
        options: ['active', 'done']),
  ],
);

const airbnbSpec = BuiltinSpec(
  table: 'airbnb_units',
  title: '에어비앤비 호점',
  accent: AppColors.sky,
  fields: [
    FieldSpec(key: 'name', label: '호점 이름', type: FieldType.text, required: true),
    FieldSpec(key: 'status', label: '상태', type: FieldType.select, required: true,
        options: ['planning', 'preparing', 'open']),
    FieldSpec(key: 'reserve_fund', label: '준비금', type: FieldType.money),
    FieldSpec(key: 'target_fund', label: '목표자금', type: FieldType.money),
    FieldSpec(key: 'expected_open', label: '예상 오픈일', type: FieldType.date),
    FieldSpec(key: 'monthly_profit', label: '이번 달 순이익', type: FieldType.money),
    FieldSpec(key: 'monthly_target', label: '월 목표 순이익', type: FieldType.money),
  ],
);

const shortsSpec = BuiltinSpec(
  table: 'shorts_channels',
  title: '숏폼 채널',
  accent: AppColors.rose,
  fields: [
    FieldSpec(key: 'name', label: '채널명', type: FieldType.text, required: true),
    FieldSpec(key: 'platform', label: '플랫폼', type: FieldType.select, required: true,
        options: ['YouTube', 'TikTok', 'Instagram']),
    FieldSpec(key: 'link', label: '채널 링크', type: FieldType.text),
    FieldSpec(key: 'uploads', label: '업로드 수', type: FieldType.number),
    FieldSpec(key: 'views', label: '조회수', type: FieldType.number),
    FieldSpec(key: 'revenue', label: '매출', type: FieldType.money),
    FieldSpec(key: 'net_profit', label: '순이익', type: FieldType.money),
  ],
);

const landSpec = BuiltinSpec(
  table: 'land_projects',
  title: '토지 프로젝트',
  accent: Color(0xFFB4844E),
  fields: [
    FieldSpec(key: 'name', label: '후보지', type: FieldType.text, required: true),
    FieldSpec(key: 'status', label: '상태', type: FieldType.select, required: true,
        options: ['reviewing', 'holding', 'sold']),
    FieldSpec(key: 'principal', label: '원금', type: FieldType.money),
    FieldSpec(key: 'target_price', label: '목표 매도가', type: FieldType.money),
    FieldSpec(key: 'reserve_fund', label: '사업자금 적립', type: FieldType.money),
    FieldSpec(key: 'target_fund', label: '사업자금 목표', type: FieldType.money),
    FieldSpec(key: 'catalyst', label: '개발호재', type: FieldType.longtext),
    FieldSpec(key: 'analysis', label: '분석', type: FieldType.longtext),
    FieldSpec(key: 'expert_opinion', label: '전문가 의견', type: FieldType.longtext),
  ],
);

const auctionSpec = BuiltinSpec(
  table: 'auction_properties',
  title: '경매 물건',
  accent: Color(0xFF14B8A6),
  fields: [
    FieldSpec(key: 'title', label: '물건명/단지', type: FieldType.text, required: true),
    FieldSpec(key: 'address', label: '주소', type: FieldType.text),
    FieldSpec(key: 'case_no', label: '사건번호', type: FieldType.text),
    FieldSpec(
        key: 'status',
        label: '상태',
        type: FieldType.select,
        required: true,
        options: [
          'interest',
          'researching',
          'visited',
          'bidding',
          'won',
          'sold',
          'pass'
        ]),
    FieldSpec(key: 'current_price', label: '현재시세', type: FieldType.money),
    FieldSpec(key: 'expected_sale_price', label: '예상매도가', type: FieldType.money),
    FieldSpec(key: 'min_price', label: '최저가', type: FieldType.money),
    FieldSpec(key: 'bid_price', label: '예상입찰가', type: FieldType.money),
    FieldSpec(key: 'loan_amount', label: '경락잔금대출', type: FieldType.money),
    FieldSpec(key: 'acquisition_cost', label: '취득·등기비', type: FieldType.money),
    FieldSpec(key: 'repair_cost', label: '수리/인테리어', type: FieldType.money),
    FieldSpec(key: 'eviction_cost', label: '명도비', type: FieldType.money),
    FieldSpec(key: 'other_cost', label: '기타/예비비/미납관리비', type: FieldType.money),
    FieldSpec(key: 'sale_cost', label: '매도비용(중개 등)', type: FieldType.money),
    FieldSpec(key: 'finance_cost', label: '대출이자/금융비용', type: FieldType.money),
    FieldSpec(key: 'target_profit', label: '목표수익', type: FieldType.money),
    FieldSpec(key: 'score', label: '투자점수(0~100)', type: FieldType.number),
    FieldSpec(
        key: 'verdict',
        label: '판단',
        type: FieldType.select,
        options: ['GO', 'HOLD', 'PASS']),
    FieldSpec(key: 'memo', label: '조사·메모 (#시세 #대출 #권리 #명도 #현장 …)', type: FieldType.longtext),
  ],
);

const referenceAccountSpec = BuiltinSpec(
  table: 'reference_accounts',
  title: '롤모델 계정',
  accent: Color(0xFFE1306C),
  fields: [
    FieldSpec(key: 'name', label: '계정명 / 채널명', type: FieldType.text, required: true),
    FieldSpec(
        key: 'platform',
        label: '플랫폼',
        type: FieldType.select,
        required: true,
        options: ['Instagram', 'YouTube', 'TikTok', '기타']),
    FieldSpec(key: 'url', label: '링크 (프로필·릴스 URL)', type: FieldType.text),
    FieldSpec(key: 'category', label: '분야 (부동산·재테크·브이로그 등)', type: FieldType.text),
    FieldSpec(key: 'followers', label: '팔로워 수', type: FieldType.number),
    FieldSpec(key: 'memo', label: '벤치마킹 포인트', type: FieldType.longtext),
  ],
);

const dividendSpec = BuiltinSpec(
  table: 'dividend_holdings',
  title: '배당 종목',
  accent: AppColors.primary,
  fields: [
    FieldSpec(key: 'ticker', label: '종목', type: FieldType.text, required: true),
    FieldSpec(key: 'market', label: '시장', type: FieldType.select, required: true,
        options: ['국장', '미장']),
    FieldSpec(key: 'symbol', label: '티커/코드 (국장=6자리 예 441800 · 미장=심볼 예 AGNC)', type: FieldType.text),
    FieldSpec(key: 'shares', label: '수량(주)', type: FieldType.number),
    FieldSpec(key: 'purchase_amount', label: '매입액 (주당·미장은 \$)', type: FieldType.number),
    FieldSpec(key: 'market_value', label: '평가액 (주당·미장은 \$)', type: FieldType.number),
    FieldSpec(key: 'annual_yield', label: '연배당률(%)', type: FieldType.percent),
  ],
);

const taskSpec = BuiltinSpec(
  table: 'tasks',
  title: '할 일',
  accent: AppColors.primary,
  fields: [
    FieldSpec(key: 'title', label: '할 일', type: FieldType.text, required: true),
    FieldSpec(
        key: 'module',
        label: '분류',
        type: FieldType.select,
        options: ['airbnb', 'shorts', '토지', '경매', '배당금']),
    FieldSpec(key: 'due_date', label: '기한', type: FieldType.date),
    FieldSpec(key: 'done', label: '완료', type: FieldType.boolean),
  ],
);

const cashFlowSpec = BuiltinSpec(
  table: 'cash_flows',
  title: '자금 흐름',
  accent: AppColors.gold,
  fields: [
    FieldSpec(key: 'source', label: '유입원', type: FieldType.text, required: true),
    FieldSpec(key: 'target', label: '배분처', type: FieldType.text, required: true),
    FieldSpec(key: 'amount', label: '금액', type: FieldType.money, required: true),
    FieldSpec(key: 'occurred_on', label: '일자', type: FieldType.date),
    FieldSpec(key: 'is_salary', label: '월급 여부', type: FieldType.boolean),
    FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
  ],
);

const dividendHoldingSpec = dividendSpec;

const incomeSpec = BuiltinSpec(
  table: 'income_sources',
  title: '들어오는 돈',
  accent: AppColors.gold,
  fields: [
    FieldSpec(key: 'label', label: '수입원', type: FieldType.text, required: true),
    FieldSpec(key: 'monthly_amount', label: '월 금액', type: FieldType.money, required: true),
  ],
);

const allocationSpec = BuiltinSpec(
  table: 'allocations',
  title: '자금 분배',
  accent: AppColors.gold,
  fields: [
    FieldSpec(key: 'label', label: '배분처', type: FieldType.text, required: true),
    FieldSpec(key: 'pool', label: '자금 종류', type: FieldType.select, required: true,
        options: ['business', 'salary']),
    FieldSpec(key: 'monthly_amount', label: '월 배분액', type: FieldType.money, required: true),
    FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
  ],
);

/// 목표·기준선 설정 (profiles 는 id 로 update).
const profileSpec = BuiltinSpec(
  table: 'profiles',
  title: '목표 · 기준선',
  accent: AppColors.primary,
  fields: [
    FieldSpec(key: 'display_name', label: '이름', type: FieldType.text),
    FieldSpec(
        key: 'freedom_target',
        label: '월 목표 현금흐름 (Freedom 기준선)',
        type: FieldType.money,
        required: true),
    FieldSpec(key: 'monthly_expenses', label: '월 생활비', type: FieldType.money),
    FieldSpec(key: 'net_worth_goal', label: '순자산 목표', type: FieldType.money),
  ],
);

/// 이번 달 재무 현황 입력 (financial_snapshots).
const snapshotSpec = BuiltinSpec(
  table: 'financial_snapshots',
  title: '재무 현황',
  accent: AppColors.gold,
  fields: [
    FieldSpec(key: 'as_of', label: '기준일', type: FieldType.date, required: true),
    FieldSpec(key: 'net_worth', label: '순자산', type: FieldType.money),
    FieldSpec(key: 'cash', label: '현금', type: FieldType.money),
    FieldSpec(
        key: 'non_salary_cashflow',
        label: '월급 제외 현금흐름',
        type: FieldType.money),
    FieldSpec(key: 'salary_cashflow', label: '월급 현금흐름', type: FieldType.money),
  ],
);

/// 공모주 청약. 수익금·수익률은 계산값이므로 입력 필드에 없다.
const ipoSpec = BuiltinSpec(
  table: 'ipo_subscriptions',
  title: '공모주',
  accent: Color(0xFF6366F1),
  fields: [
    FieldSpec(key: 'name', label: '종목', type: FieldType.text, required: true),
    FieldSpec(
        key: 'broker',
        label: '증권사',
        type: FieldType.select,
        options: [
          '한투',
          '신한투자',
          '삼성',
          '나무',
          'KB',
          '미래에셋',
          '키움',
          'NH',
          '대신',
          '하나',
          '기타'
        ]),
    FieldSpec(key: 'offer_price', label: '공모가 (주당)', type: FieldType.money, required: true),
    FieldSpec(key: 'shares', label: '배정 수량(주)', type: FieldType.number),
    FieldSpec(key: 'sell_price', label: '매도가 (주당 · 비우면 미매도)', type: FieldType.money),
    FieldSpec(key: 'listing_date', label: '상장일', type: FieldType.date),
    FieldSpec(key: 'invested', label: '청약금(증거금)', type: FieldType.money),
    FieldSpec(key: 'competition_rate', label: '경쟁률', type: FieldType.number),
    FieldSpec(key: 'memo', label: '메모', type: FieldType.text),
  ],
);

/// 구역 — 모아타운·신통기획 선정지.
const zoneSpec = BuiltinSpec(
  table: 'zones',
  title: '구역',
  accent: AppColors.violet,
  fields: [
    FieldSpec(key: 'name', label: '구역명 (예: 강서구 화곡동 354)', type: FieldType.text, required: true),
    FieldSpec(
        key: 'kind',
        label: '종류',
        type: FieldType.select,
        required: true,
        options: ['모아타운', '신통기획', '일반']),
    FieldSpec(key: 'district', label: '자치구', type: FieldType.text),
    FieldSpec(key: 'consent_rate', label: '조합설립 동의율(%)', type: FieldType.percent),
    FieldSpec(key: 'union_expected', label: '조합설립 예상 시기', type: FieldType.date),
    FieldSpec(key: 'memo', label: '메모 (강의 사례·특이사항)', type: FieldType.longtext),
  ],
);

/// 단지 — 조사·임장이 붙는 단위.
const complexSpec = BuiltinSpec(
  table: 'complexes',
  title: '단지',
  accent: AppColors.sky,
  fields: [
    FieldSpec(key: 'name', label: '단지명 (예: 남성아트빌)', type: FieldType.text, required: true),
    FieldSpec(
        key: 'kind',
        label: '종류',
        type: FieldType.select,
        required: true,
        options: ['빌라', '다세대', '연립', '아파트', '기타']),
    FieldSpec(key: 'address', label: '주소', type: FieldType.text),
    FieldSpec(key: 'memo', label: '메모', type: FieldType.longtext),
  ],
);
