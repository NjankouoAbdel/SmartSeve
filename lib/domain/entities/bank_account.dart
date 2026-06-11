class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    required this.institution,
    required this.createdAt,
    this.iconCodePoint = 0xe850,
    this.colorValue = 0xFF42A5F5,
  });

  final String id;
  final String name;
  final String institution;
  final DateTime createdAt;
  final int iconCodePoint;
  final int colorValue;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'institution': institution,
      'createdAt': createdAt.toIso8601String(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : 'main',
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Main Account',
      institution: (map['institution'] as String?) ?? 'General',
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt() ?? 0xe850,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF42A5F5,
    );
  }
}
