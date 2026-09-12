// 계산기 공통 입력·출력 조각.
//
// 경매 계산기와 정비구역 계산기가 «같은 모양»이어야 한다. 한쪽에만 콤마가
// 붙거나 한쪽만 소수점을 받으면 같은 앱을 쓰는 느낌이 안 난다.
// 금액은 반드시 MoneyField(콤마 + 한글 환산)를 거친다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/money_field.dart';

/// 금액 입력칸. [revision] 은 이력을 불러왔을 때 초기값을 다시 심기 위한 key.
Widget calcMoney(String label, double value, ValueChanged<double> onChanged,
        int revision, {Color accent = AppColors.gold}) =>
    MoneyField(
      key: ValueKey('$label-$revision'),
      label: label,
      initial: value,
      accent: accent,
      onChanged: onChanged,
    );

/// 비율(%) 입력칸. 소수 허용(취득세 1.1% 같은 값이 있다).
Widget calcPct(String label, double value, ValueChanged<double> onChanged,
        int revision) =>
    calcNumber(label, value, onChanged, revision, suffix: '%');

/// 금액이 아닌 숫자 입력칸(비율·면적 등). 소수 허용.
Widget calcNumber(String label, double value, ValueChanged<double> onChanged,
        int revision, {String? suffix}) =>
    TextFormField(
      key: ValueKey('$label-$revision'),
      initialValue: value == 0
          ? ''
          : (value == value.roundToDouble()
              ? value.toStringAsFixed(0)
              : value.toString()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      // 금액칸(MoneyField)과 «생김새가 같아야» 한 줄에 섞여도 높이가 맞는다.
      style: const TextStyle(fontSize: AppFont.section),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: AppFont.label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixText: suffix,
        suffixStyle: const TextStyle(
            color: AppColors.textFaint, fontSize: AppFont.label),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
    );

/// 계산 결과 한 줄 (금액).
Widget calcRow(String label, double value, {bool strong = false, Color? color}) =>
    calcTextRow(label, '${Won.compact(value)}원', strong: strong, color: color);

/// 계산 결과 한 줄 (임의 문자열 — 비율·판정 등).
/// [color] 는 강조가 아니어도 «값»에 적용된다 (환급금처럼 부호가 뒤집히는 줄).
Widget calcTextRow(String label, String value,
        {bool strong = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: strong ? AppFont.body : AppFont.label,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  color: strong
                      ? (color ?? AppColors.textPrimary)
                      : AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: strong ? AppFont.section : AppFont.body,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary)),
      ]),
    );

/// 시나리오/결론 카드 맨 아래의 강조 띠.
Widget calcTail(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: AppFont.label, fontWeight: FontWeight.w700, color: color)),
        Text(value,
            style: TextStyle(
                fontSize: AppFont.display, fontWeight: FontWeight.w900, color: color)),
      ]),
    );

// ── 한 줄짜리 입력/계산 줄 ─────────────────────────────────
// 계산기는 «내가 넣는 칸»과 «자동으로 나오는 줄»이 한눈에 갈려야 한다.
// 엑셀 원본이 입력칸을 파란 숫자로 칠해둔 것과 같은 규칙이다:
//   왼쪽에 파란 띠가 있으면 내가 넣는 칸, 없으면 계산된 값.
// 띠가 없는 줄도 «같은 만큼 들여써서» 줄이 어긋나지 않게 한다.
//
// 한 줄에 «하나»씩 세로로 쌓는다. 격자로 2~3개씩 늘어놓으면 카드마다
// 칸 개수가 달라 폭이 제각각이 되고, 어디를 채워야 하는지 눈이 헤맨다.

/// 입력칸 색 — 엑셀의 파란 숫자(0070C0)에 대응.
const calcInputAccent = AppColors.sky;

/// 한 줄을 감싼다. [blue] 면 왼쪽에 파란 띠.
Widget calcLine(Widget child, {bool blue = false}) => Container(
      padding: const EdgeInsets.only(left: 11),
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(
                color: blue ? calcInputAccent : Colors.transparent, width: 3)),
      ),
      child: child,
    );

Widget _note(String? note) => note == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(note,
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.textFaint)),
      );

/// 금액 입력 한 줄 (라벨 + 설명).
Widget calcMoneyRow(String label, double value, ValueChanged<double> onChanged,
        int revision, {String? note, bool blue = true}) =>
    calcLine(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          calcMoney(label, value, onChanged, revision,
              accent: blue ? calcInputAccent : AppColors.gold),
          _note(note),
        ]),
      ),
      blue: blue,
    );

/// 숫자(%·면적 등) 입력 한 줄.
Widget calcNumRow(String label, double value, ValueChanged<double> onChanged,
        int revision,
        {required String suffix, String? note, bool blue = true}) =>
    calcLine(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          calcNumber(label, value, onChanged, revision, suffix: suffix),
          _note(note),
        ]),
      ),
      blue: blue,
    );

/// 입력 묶음과 계산 묶음 사이 구분선.
Widget calcDivider() => const Divider(height: 20, color: AppColors.border);
