import 'package:flutter/material.dart';

import '../format/formatters.dart';

/// 입력 필드 타입.
enum FieldType { text, longtext, number, money, percent, date, boolean, select }

FieldType _typeFromString(String s) {
  switch (s) {
    case 'longtext':
      return FieldType.longtext;
    case 'number':
      return FieldType.number;
    case 'money':
      return FieldType.money;
    case 'percent':
      return FieldType.percent;
    case 'date':
      return FieldType.date;
    case 'bool':
    case 'boolean':
      return FieldType.boolean;
    case 'select':
      return FieldType.select;
    default:
      return FieldType.text;
  }
}

String typeToString(FieldType t) {
  switch (t) {
    case FieldType.longtext:
      return 'longtext';
    case FieldType.number:
      return 'number';
    case FieldType.money:
      return 'money';
    case FieldType.percent:
      return 'percent';
    case FieldType.date:
      return 'date';
    case FieldType.boolean:
      return 'bool';
    case FieldType.select:
      return 'select';
    case FieldType.text:
      return 'text';
  }
}

const kFieldTypeLabels = {
  FieldType.text: '텍스트',
  FieldType.longtext: '긴 텍스트',
  FieldType.number: '숫자',
  FieldType.money: '금액(원)',
  FieldType.percent: '퍼센트(%)',
  FieldType.date: '날짜',
  FieldType.boolean: '예/아니오',
  FieldType.select: '선택',
};

/// 하나의 입력 필드 정의.
class FieldSpec {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final List<String> options; // select 용

  const FieldSpec({
    required this.key,
    required this.label,
    this.type = FieldType.text,
    this.required = false,
    this.options = const [],
  });

  factory FieldSpec.fromMap(Map<String, dynamic> m) => FieldSpec(
        key: m['key'] as String,
        label: m['label'] as String,
        type: _typeFromString(m['type'] as String? ?? 'text'),
        required: m['required'] as bool? ?? false,
        options: (m['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'type': typeToString(type),
        'required': required,
        if (options.isNotEmpty) 'options': options,
      };

  /// 값 표시용 포맷.
  String display(dynamic v) {
    if (v == null || (v is String && v.isEmpty)) return '—';
    switch (type) {
      case FieldType.money:
        return '${Won.compact((v as num).toDouble())}원';
      case FieldType.percent:
        return '${(v as num).toString()}%';
      case FieldType.number:
        return v.toString();
      case FieldType.date:
        return Dates.ymd(DateTime.parse(v.toString()));
      case FieldType.boolean:
        return (v == true) ? '예' : '아니오';
      default:
        return v.toString();
    }
  }

  IconData get icon {
    switch (type) {
      case FieldType.money:
        return Icons.payments_rounded;
      case FieldType.percent:
        return Icons.percent_rounded;
      case FieldType.number:
        return Icons.numbers_rounded;
      case FieldType.date:
        return Icons.event_rounded;
      case FieldType.boolean:
        return Icons.toggle_on_rounded;
      case FieldType.select:
        return Icons.list_rounded;
      case FieldType.longtext:
        return Icons.notes_rounded;
      case FieldType.text:
        return Icons.text_fields_rounded;
    }
  }
}
