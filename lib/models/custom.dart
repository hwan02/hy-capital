import '../core/edit/field_spec.dart';

/// 사용자 정의 모듈.
class CustomModule {
  final String id;
  final String name;
  final String icon;      // icon_catalog 키
  final String colorHex;  // RRGGBB
  final int sortOrder;
  final List<FieldSpec> fields;

  CustomModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.sortOrder,
    required this.fields,
  });

  factory CustomModule.fromMap(Map<String, dynamic> m) => CustomModule(
        id: m['id'],
        name: m['name'],
        icon: m['icon'] ?? 'widgets',
        colorHex: m['color'] ?? '38BDF8',
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        fields: ((m['fields'] as List?) ?? [])
            .map((e) => FieldSpec.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  String get route => '/m/$id';
}

/// 커스텀 모듈의 레코드.
class CustomRecord {
  final String id;
  final String moduleId;
  final Map<String, dynamic> data;
  final int sortOrder;

  CustomRecord({
    required this.id,
    required this.moduleId,
    required this.data,
    required this.sortOrder,
  });

  factory CustomRecord.fromMap(Map<String, dynamic> m) => CustomRecord(
        id: m['id'],
        moduleId: m['module_id'],
        data: Map<String, dynamic>.from(m['data'] ?? {}),
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );
}
