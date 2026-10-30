import '../../core/edit/builtin_specs.dart';
import '../../core/edit/field_spec.dart';
import '../../core/theme/app_theme.dart';

// 공통 레코드 폼으로 편집한 값을 물건별 calc_records.inputs에 스냅샷 저장한다.
const investmentCostSpec = BuiltinSpec(
  table: 'calc_records',
  title: '취득·비용·세금 가정',
  accent: AppColors.sky,
  fields: [
    FieldSpec(
      key: 'bid',
      label: '검토 입찰가',
      type: FieldType.money,
      required: true,
    ),
    FieldSpec(
      key: 'deposit',
      label: '입찰보증금 (특별조건 원문 확인)',
      type: FieldType.money,
    ),
    FieldSpec(
      key: 'acq_pct',
      label: '취득 관련 합산세율 % (확인 전 가정)',
      type: FieldType.percent,
    ),
    FieldSpec(key: 'legal', label: '등기·법무비', type: FieldType.money),
    FieldSpec(key: 'takeover', label: '인수 보증금·권리 비용', type: FieldType.money),
    FieldSpec(
      key: 'capitalized',
      label: '취득원가에 포함할 추가 지출',
      type: FieldType.money,
    ),
    FieldSpec(
      key: 'expenses',
      label: '명도·수리·보유 등 일반 비용',
      type: FieldType.money,
    ),
    FieldSpec(
      key: 'reserve',
      label: '미사용 예비현금 (세무 비용 아님)',
      type: FieldType.money,
    ),
    FieldSpec(
      key: 'sale_fee_pct',
      label: '매도 중개 등 매도가 비례 비용 %',
      type: FieldType.percent,
    ),
    FieldSpec(
      key: 'ordinary_pct',
      label: '일반 법인세 비교 세율 %',
      type: FieldType.percent,
    ),
    FieldSpec(
      key: 'additional_pct',
      label: '주택 추가과세 비교 세율 %',
      type: FieldType.percent,
    ),
    FieldSpec(
      key: 'local_pct',
      label: '법인세 대비 지방세 비교 비율 %',
      type: FieldType.percent,
    ),
    FieldSpec(
      key: 'tax_note',
      label: '명의·법인 유형·사업연도·비용 처리 근거',
      type: FieldType.longtext,
    ),
  ],
);
const investmentFundingSpec = BuiltinSpec(
  table: 'calc_records',
  title: '자금·목표·본인 배분',
  accent: AppColors.gold,
  fields: [
    FieldSpec(key: 'cash', label: '입찰일 사용 가능한 자기 현금', type: FieldType.money),
    FieldSpec(key: 'credit', label: '개인 신용대출', type: FieldType.money),
    FieldSpec(
      key: 'credit_confirmed',
      label: '신용대출 실행 조건 확정',
      type: FieldType.boolean,
    ),
    FieldSpec(
      key: 'credit_rate',
      label: '신용대출 연이율 % (본인 부담)',
      type: FieldType.percent,
    ),
    FieldSpec(key: 'mortgage', label: '잔금 시 실행 가능한 주담대', type: FieldType.money),
    FieldSpec(
      key: 'mortgage_confirmed',
      label: '해당 물건·명의 주담대 승인 확정',
      type: FieldType.boolean,
    ),
    FieldSpec(
      key: 'mortgage_rate',
      label: '주담대 연이율 %',
      type: FieldType.percent,
    ),
    FieldSpec(key: 'joint', label: '공투자 출자금', type: FieldType.money),
    FieldSpec(
      key: 'joint_confirmed',
      label: '공투 출자·추가부담 약정 확정',
      type: FieldType.boolean,
    ),
    FieldSpec(
      key: 'joint_rate',
      label: '공투자 세후 우선배분 연율 % (이익 한도·없으면0)',
      type: FieldType.percent,
    ),
    FieldSpec(
      key: 'share',
      label: '법인세 후 본인 이익 배분율 %',
      type: FieldType.percent,
    ),
    FieldSpec(
      key: 'distribution_cost',
      label: '개인 출금세금·성과보수 등 추정액',
      type: FieldType.money,
    ),
    FieldSpec(key: 'target', label: '목표 수익', type: FieldType.money),
    FieldSpec(
      key: 'target_scope',
      label: '목표 적용 범위',
      type: FieldType.select,
      options: ['own', 'project'],
      optionLabels: {'own': '본인 배분 후', 'project': '물건 전체'},
    ),
  ],
);
const investmentMarketSpec = BuiltinSpec(
  table: 'calc_records',
  title: '매도 가격·보유기간 시나리오',
  accent: AppColors.primary,
  fields: [
    FieldSpec(key: 'low_sale', label: '보수적 매도가', type: FieldType.money),
    FieldSpec(key: 'low_months', label: '보수적 보유 개월', type: FieldType.number),
    FieldSpec(key: 'base_sale', label: '기준 매도가', type: FieldType.money),
    FieldSpec(key: 'base_months', label: '기준 보유 개월', type: FieldType.number),
    FieldSpec(key: 'high_sale', label: '공격적 매도가', type: FieldType.money),
    FieldSpec(key: 'high_months', label: '공격적 보유 개월', type: FieldType.number),
    FieldSpec(
      key: 'market_note',
      label: '비교거래·면적·층·거래일·차이·출처',
      type: FieldType.longtext,
      minLines: 4,
    ),
  ],
);
const investmentEvidenceSpec = BuiltinSpec(
  table: 'calc_records',
  title: '조사 근거',
  accent: AppColors.violet,
  fields: [
    FieldSpec(
      key: 'status',
      label: '확인 상태',
      type: FieldType.select,
      options: ['unknown', 'pass', 'fail'],
      optionLabels: {'unknown': '미확인', 'pass': '확인·통과', 'fail': '부적합·제외'},
    ),
    FieldSpec(
      key: 'kind',
      label: '근거 구분',
      type: FieldType.select,
      options: ['미확인', '공식 원문', '사용자 제공', '현장 확인', '민간 자료', '계산 가정'],
    ),
    FieldSpec(key: 'source', label: '출처 URL·문서명·페이지', type: FieldType.text),
    FieldSpec(key: 'checked_on', label: '확인일', type: FieldType.date),
    FieldSpec(
      key: 'detail',
      label: '확인한 사실·조건·남은 불확실성',
      type: FieldType.longtext,
      minLines: 4,
    ),
  ],
);
