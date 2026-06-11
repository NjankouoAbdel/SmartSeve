class BudgetGoal {
  const BudgetGoal({
    required this.id,
    required this.monthlyLimit,
    required this.categoryKey,
    required this.last80AlertMonth,
    required this.last100AlertMonth,
  });

  final String id;
  final double monthlyLimit;
  final String? categoryKey;
  final String? last80AlertMonth;
  final String? last100AlertMonth;

  bool get isGlobal => categoryKey == null;

  BudgetGoal copyWith({
    String? id,
    double? monthlyLimit,
    String? categoryKey,
    String? last80AlertMonth,
    String? last100AlertMonth,
  }) {
    return BudgetGoal(
      id: id ?? this.id,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      categoryKey: categoryKey ?? this.categoryKey,
      last80AlertMonth: last80AlertMonth ?? this.last80AlertMonth,
      last100AlertMonth: last100AlertMonth ?? this.last100AlertMonth,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'monthlyLimit': monthlyLimit,
      'categoryKey': categoryKey,
      'last80AlertMonth': last80AlertMonth,
      'last100AlertMonth': last100AlertMonth,
    };
  }

  factory BudgetGoal.fromMap(Map<dynamic, dynamic> map) {
    return BudgetGoal(
      id: (map['id'] as String?) ?? '',
      monthlyLimit: ((map['monthlyLimit'] as num?) ?? 0).toDouble(),
      categoryKey: map['categoryKey'] as String?,
      last80AlertMonth: map['last80AlertMonth'] as String?,
      last100AlertMonth: map['last100AlertMonth'] as String?,
    );
  }
}
