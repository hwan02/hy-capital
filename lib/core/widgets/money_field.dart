// 금액 입력 공통 위젯.
//
// 이 앱은 금액을 다루는 화면이 많아서(경매·배당·자금흐름·목표) 입력 방식이
// 화면마다 다르면 매번 헷갈린다. 규칙은 하나다:
//   · 타이핑하면 천단위 콤마가 자동으로 붙는다
//   · 오른쪽에 «1,000만원» 처럼 한글 단위로 실시간 환산해 보여준다
//
// 새 금액 입력을 만들 때 TextField 를 직접 쓰지 말고 이 위젯을 쓴다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/formatters.dart';
import '../theme/app_theme.dart';

/// 천단위 콤마 자동 삽입 (정수만).
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = moneyComma(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 숫자 문자열/값에 천단위 콤마를 붙인다.
String moneyComma(Object v) {
  final s = v is num ? v.round().toString() : v.toString();
  return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

/// 콤마가 섞인 입력값을 숫자로. 못 읽으면 0.
double moneyValue(String text) =>
    double.tryParse(text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

/// 금액 입력칸. 콤마 자동 + 오른쪽에 한글 단위 환산.
class MoneyField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;

  /// 환산 표시 색. 화면 강조색에 맞춘다.
  final Color accent;

  /// 여러 칸을 촘촘히 놓을 때(경매 계산기) 작게.
  final bool dense;
  final bool autofocus;
  final String? hint;
  final void Function(double)? onSubmitted;

  const MoneyField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.accent = AppColors.primary,
    this.dense = false,
    this.autofocus = false,
    this.hint,
    this.onSubmitted,
  });

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.initial > 0 ? moneyComma(widget.initial) : '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = moneyValue(_c.text);
    return TextField(
      controller: _c,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: const [MoneyInputFormatter()],
      onChanged: (v) {
        widget.onChanged(moneyValue(v));
        setState(() {}); // 오른쪽 환산 표시 갱신
      },
      onSubmitted:
          widget.onSubmitted == null ? null : (v) => widget.onSubmitted!(moneyValue(v)),
      style: TextStyle(fontSize: widget.dense ? AppFont.body : AppFont.section),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(
            fontSize: widget.dense ? AppFont.caption : AppFont.label),
        isDense: widget.dense,
        contentPadding: widget.dense
            ? const EdgeInsets.fromLTRB(10, 12, 8, 8)
            : null,
        suffixText: n > 0 ? '${Won.compact(n)}원' : '원',
        suffixStyle: n > 0
            ? TextStyle(
                color: widget.accent,
                fontWeight: FontWeight.w800,
                fontSize: widget.dense ? AppFont.caption : AppFont.body)
            : const TextStyle(
                color: AppColors.textFaint, fontSize: AppFont.label),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.dense ? 9 : 12),
            borderSide: BorderSide.none),
      ),
    );
  }
}
