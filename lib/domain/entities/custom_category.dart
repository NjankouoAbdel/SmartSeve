class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomCategory.fromMap(Map<String, dynamic> map) {
    return CustomCategory(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : 'cat_default',
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Custom',
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt() ?? 0xe14c,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF64B5F6,
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
