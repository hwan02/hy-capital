import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_theme.dart';

/// 입찰 전 조사표 — 접이식(아코디언) + 모바일 우선.
/// 섹션: 시세 조사 / 부동산 조사 / 권리 분석 / 현장 점검(임장) / 최종 점검.
/// 시세 평균가를 채우면 현재시세가 자동 계산된다.

const greenC = Color(0xFF1D9E75);
const pinkC = Color(0xFFD4537E);
const orangeC = Color(0xFFBA7517);
const blueC = Color(0xFF378ADD);
const _teal = Color(0xFF14B8A6);

/// 현재시세 자동계산에 쓰는 평균가 키.
const auctionAvgKeys = ['naver_avg', 'real_avg', 'kb_avg', 'a1_avg', 'a2_avg', 'a3_avg'];

double parseWon(String? s) {
  if (s == null) return 0;
  s = s.replaceAll(',', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return 0;
  final eok = RegExp(r'([\d.]+)\s*억').firstMatch(s);
  final man = RegExp(r'([\d.]+)\s*만').firstMatch(s);
  double v = 0;
  if (eok != null) v += (double.tryParse(eok.group(1)!) ?? 0) * 1e8;
  if (man != null) v += (double.tryParse(man.group(1)!) ?? 0) * 1e4;
  if (eok == null && man == null) v = double.tryParse(s) ?? 0;
  return v;
}

// 시세 상세(평균가 외) · 부동산 · 권리 필드 정의.
const _naverDetail = [('naver_low', '최저가'), ('naver_high', '최고가'), ('naver_jeonse', '전세'), ('naver_wolse', '월세'), ('naver_note', '비고')];
const _realDetail = [('real_low', '최저가'), ('real_high', '최고가')];
const _kbDetail = [('kb_low', '최저가'), ('kb_high', '최고가')];

const _agents = [
  ('부동산 1', 'a1'),
  ('부동산 2', 'a2'),
  ('부동산 3', 'a3'),
];
const _agentCols = [('quick', '급매가'), ('avg', '평균가'), ('high', '최고가'), ('jeonse', '전세'), ('wolse', '월세'), ('etc', '기타')];

const auctionRights = [
  ('right_acquired', '인수 권리'),
  ('right_tenant', '임차인 권리'),
  ('right_amount', '인수 금액'),
];

// 현장 점검(임장) 체크 항목.
const _fieldChecks = [
  ('fc_leak', '누수·결로·곰팡이'),
  ('fc_window', '샷시·창호'),
  ('fc_boiler', '보일러·난방'),
  ('fc_plumb', '급배수·배관'),
  ('fc_bath', '욕실·주방'),
  ('fc_elec', '전기·설비'),
  ('fc_wall', '도배·바닥'),
  ('fc_noise', '층간·외부 소음'),
  ('fc_light', '향·채광·조망'),
  ('fc_park', '주차'),
  ('fc_common', '공용부 상태'),
  ('fc_mgmt', '관리비·미납관리비'),
  ('fc_office', '관리사무소 문의'),
  ('fc_occupant', '점유자 확인'),
  ('fc_neighbor', '윗집·아랫집'),
];

const auctionFinalChecks = [
  ('final_appraisal', '감정평가서'),
  ('final_register', '등기부등본'),
  ('final_listing', '매각물건명세서'),
  ('final_survey', '현황조사서'),
  ('final_withdrawal', '취하변경'),
];

class AuctionChecklistForm extends StatefulWidget {
  final Map<String, dynamic> initial;
  const AuctionChecklistForm({super.key, required this.initial});

  @override
  State<AuctionChecklistForm> createState() => AuctionChecklistFormState();
}

class AuctionChecklistFormState extends State<AuctionChecklistForm> {
  final Map<String, TextEditingController> _c = {};
  final Map<String, bool> _checks = {};
  final Set<int> _open = {0}; // 기본: 시세 조사만 펼침
  bool _priceDetail = false;

  List<String> get _allTextKeys => [
        'naver_avg', 'real_avg', 'kb_avg',
        ..._naverDetail.map((e) => e.$1),
        ..._realDetail.map((e) => e.$1),
        ..._kbDetail.map((e) => e.$1),
        'nakchal',
        for (final (_, p) in _agents) ...['${p}_quick', '${p}_avg', '${p}_high', '${p}_jeonse', '${p}_wolse', '${p}_etc'],
        ...auctionRights.map((e) => e.$1),
        'field_note',
      ];

  @override
  void initState() {
    super.initState();
    final cl = widget.initial;
    for (final k in _allTextKeys) {
      _c[k] = TextEditingController(text: cl[k]?.toString() ?? '');
    }
    for (final (k, _) in [..._fieldChecks, ...auctionFinalChecks]) {
      _checks[k] = cl[k] == true;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  (Map<String, dynamic>, double) collect() {
    final data = <String, dynamic>{};
    _c.forEach((k, v) {
      if (v.text.trim().isNotEmpty) data[k] = v.text.trim();
    });
    _checks.forEach((k, v) {
      if (v) data[k] = true;
    });
    final avgs = auctionAvgKeys
        .map((k) => parseWon(data[k]?.toString()))
        .where((v) => v > 0)
        .toList();
    final price = avgs.isEmpty ? 0.0 : avgs.reduce((a, b) => a + b) / avgs.length;
    return (data, price);
  }

  int _filled(List<String> keys) =>
      keys.where((k) => (_c[k]?.text.trim().isNotEmpty ?? false)).length;
  int _checked(List<(String, String)> items) =>
      items.where((e) => _checks[e.$1] == true).length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cts) {
      final narrow = cts.maxWidth < 560;
      return Column(
        children: [
          _section(0, Icons.show_chart_rounded, '시세 조사', greenC,
              badge: '${_filled(['naver_avg', 'real_avg', 'kb_avg'])}/3',
              child: _priceBody(narrow)),
          _section(1, Icons.storefront_rounded, '부동산 조사', pinkC,
              badge:
                  '${_agents.where((a) => (_c['${a.$2}_avg']?.text.trim().isNotEmpty ?? false)).length}/3',
              child: _agentsBody(narrow)),
          _section(2, Icons.gavel_rounded, '권리 분석', orangeC,
              child: _fieldsCol(auctionRights, narrow, multiline: true)),
          _section(3, Icons.location_on_rounded, '현장 점검 (임장)', blueC,
              badge: '${_checked(_fieldChecks)}/${_fieldChecks.length}',
              child: _fieldBody(narrow)),
          _section(4, Icons.rule_folder_rounded, '입찰 직전 최종 점검', _teal,
              badge: '${_checked(auctionFinalChecks)}/${auctionFinalChecks.length}',
              child: _checkWrap(auctionFinalChecks)),
        ],
      );
    });
  }

  Widget _section(int i, IconData icon, String title, Color color,
      {String? badge, required Widget child}) {
    final open = _open.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
                () => open ? _open.remove(i) : _open.add(i)),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const Gap(10),
                  Text(title,
                      style: const TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.w700)),
                  if (badge != null) ...[
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(badge,
                          style: TextStyle(
                              color: color,
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textFaint),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: AppColors.border, height: 1),
                    const Gap(12),
                    child,
                  ]),
            ),
        ],
      ),
    );
  }

  // ── 시세 조사 ──
  Widget _priceBody(bool narrow) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bigField('naver_avg', '네이버 평균가'),
          _bigField('real_avg', '실거래 평균가'),
          _bigField('kb_avg', 'KB 평균가'),
          const Gap(4),
          InkWell(
            onTap: () => setState(() => _priceDetail = !_priceDetail),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(_priceDetail ? Icons.remove : Icons.add,
                    size: 15, color: greenC),
                const Gap(4),
                Text('최저·최고·전세·월세 상세',
                    style: TextStyle(color: greenC, fontSize: AppFont.label)),
              ]),
            ),
          ),
          if (_priceDetail) ...[
            const Gap(4),
            _sub('네이버'),
            _wrapFields(_naverDetail, narrow),
            const Gap(8),
            _sub('실거래'),
            _wrapFields(_realDetail, narrow),
            const Gap(8),
            _sub('KB'),
            _wrapFields(_kbDetail, narrow),
          ],
          const Gap(10),
          _sub('동일 번지 낙찰 사례'),
          TextField(
            controller: _c['nakchal'],
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: AppFont.body),
            decoration: _dec('감정가 대비 낙찰가, 날짜 등'),
          ),
        ],
      );

  // ── 부동산 조사 ──
  Widget _agentsBody(bool narrow) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, p) in _agents) ...[
            _sub(name),
            _wrapFields(
                [for (final (k, l) in _agentCols) ('${p}_$k', l)], narrow),
            const Gap(12),
          ],
        ],
      );

  // ── 현장 점검 ──
  Widget _fieldBody(bool narrow) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (k, label) in _fieldChecks) _checkRow(k, label),
          const Gap(10),
          _sub('메모 (전입세대 열람·점유자·특이사항)'),
          TextField(
            controller: _c['field_note'],
            minLines: 2,
            maxLines: 5,
            style: const TextStyle(fontSize: AppFont.body),
            decoration: _dec('예: 소유자 점유, 관리비 50만 미납, 우편물 확인'),
          ),
          const Gap(10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.photo_camera_rounded, color: _teal, size: 17),
              Gap(8),
              Expanded(
                  child: Text('현장 사진은 위 [사진] 탭에서 올리세요',
                      style: TextStyle(color: _teal, fontSize: AppFont.label))),
            ]),
          ),
        ],
      );

  // ── 필드/체크 헬퍼 ──
  Widget _bigField(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFont.label)),
            const Gap(5),
            TextField(
              controller: _c[key],
              style:
                  const TextStyle(fontSize: AppFont.section, fontWeight: FontWeight.w600),
              decoration: _dec('예: 4.5억 / 45,000만'),
            ),
          ],
        ),
      );

  Widget _fieldsCol(List<(String, String)> cols, bool narrow,
          {bool multiline = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (key, label) in cols)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: AppFont.label)),
                  const Gap(5),
                  TextField(
                    controller: _c[key],
                    minLines: multiline ? 1 : 1,
                    maxLines: multiline ? 3 : 1,
                    style: const TextStyle(fontSize: AppFont.body),
                    decoration: _dec('없음 / 내용'),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _wrapFields(List<(String, String)> cols, bool narrow) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (key, sub) in cols)
          SizedBox(
            width: narrow ? double.infinity : 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: AppFont.caption)),
                const Gap(3),
                TextField(
                  controller: _c[key],
                  style: const TextStyle(fontSize: AppFont.body),
                  decoration: _dec(''),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _checkRow(String key, String label) {
    final on = _checks[key] ?? false;
    return InkWell(
      onTap: () => setState(() => _checks[key] = !on),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(children: [
          Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: on ? blueC : AppColors.textFaint, size: 24),
          const Gap(12),
          Text(label,
              style: TextStyle(
                  fontSize: AppFont.body,
                  color: on ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _checkWrap(List<(String, String)> items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (key, label) in items)
            InkWell(
              onTap: () =>
                  setState(() => _checks[key] = !(_checks[key] ?? false)),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (_checks[key] ?? false)
                      ? _teal.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(
                      color: (_checks[key] ?? false) ? _teal : AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      (_checks[key] ?? false)
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: (_checks[key] ?? false)
                          ? _teal
                          : AppColors.textFaint),
                  const Gap(6),
                  Text(label,
                      style: TextStyle(
                          fontSize: AppFont.label,
                          fontWeight: FontWeight.w700,
                          color: (_checks[key] ?? false)
                              ? AppColors.textPrimary
                              : AppColors.textSecondary)),
                ]),
              ),
            ),
        ],
      );

  Widget _sub(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: AppFont.label, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}
