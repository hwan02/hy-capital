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
      decoration:
          InputDecoration(labelText: label, isDense: true, suffixText: suffix),
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
