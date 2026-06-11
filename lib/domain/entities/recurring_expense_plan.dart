enum PlannedCadence { oneTime, monthly, weekly, yearly }

extension PlannedCadenceX on PlannedCadence {
  String get key {
    switch (this) {
      case PlannedCadence.oneTime:
        return 'one_time';
      case PlannedCadence.monthly:
        return 'monthly';
      case PlannedCadence.weekly:
        return 'weekly';
      case PlannedCadence.yearly:
        return 'yearly';
    }
  }

  static PlannedCadence fromKey(String value) {
    switch (value) {
      case 'one_time':
        return PlannedCadence.oneTime;
      case 'weekly':
        return PlannedCadence.weekly;
      case 'yearly':
        return PlannedCadence.yearly;
      case 'monthly':
      default:
        return PlannedCadence.monthly;
    }
  }
}

class RecurringExpensePlan {
  const RecurringExpensePlan({
    required this.id,
    required this.amount,
    required this.categoryKey,
    required this.note,
    required this.currencyCode,
    required this.dayOfMonth,
    required this.startDate,
    required this.lastAppliedAt,
    required this.isActive,
    this.cadence = PlannedCadence.monthly,
    this.weekDay = 1,
    this.monthOfYear = 1,
    this.endDate,
  });

  final String id;
  final double amount;
  final String categoryKey;
  final String note;
  final String currencyCode;
  final int dayOfMonth;
  final DateTime startDate;
  final DateTime? lastAppliedAt;
  final bool isActive;
  final PlannedCadence cadence;
  final int weekDay;
  final int monthOfYear;
  final DateTime? endDate;

  RecurringExpensePlan copyWith({
    String? id,
    double? amount,
    String? categoryKey,
    String? note,
    String? currencyCode,
    int? dayOfMonth,
    DateTime? startDate,
    DateTime? lastAppliedAt,
    bool? isActive,
    PlannedCadence? cadence,
    int? weekDay,
    int? monthOfYear,
    DateTime? endDate,
  }) {
    return RecurringExpensePlan(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryKey: categoryKey ?? this.categoryKey,
      note: note ?? this.note,
      currencyCode: currencyCode ?? this.currencyCode,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
      isActive: isActive ?? this.isActive,
      cadence: cadence ?? this.cadence,
      weekDay: weekDay ?? this.weekDay,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      endDate: endDate ?? this.endDate,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'categoryKey': categoryKey,
      'note': note,
      'currencyCode': currencyCode,
      'dayOfMonth': dayOfMonth,
      'startDate': startDate.toIso8601String(),
      'lastAppliedAt': lastAppliedAt?.toIso8601String(),
      'isActive': isActive,
      'cadence': cadence.key,
      'weekDay': weekDay,
      'monthOfYear': monthOfYear,
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory RecurringExpensePlan.fromMap(Map<dynamic, dynamic> map) {
    final DateTime parsedStartDate =
        DateTime.tryParse((map['startDate'] as String?) ?? '') ??
        DateTime.now();
    final int parsedDayOfMonth = ((map['dayOfMonth'] as num?) ?? 1)
        .toInt()
        .clamp(1, 31);
    final int parsedWeekday =
        ((map['weekDay'] as num?) ?? parsedStartDate.weekday).toInt().clamp(
          1,
          7,
        );
    final int parsedMonthOfYear =
        ((map['monthOfYear'] as num?) ?? parsedStartDate.month).toInt().clamp(
          1,
          12,
        );

    return RecurringExpensePlan(
      id: (map['id'] as String?) ?? '',
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      categoryKey: (map['categoryKey'] as String?) ?? 'other',
      note: (map['note'] as String?) ?? '',
      currencyCode: (map['currencyCode'] as String?) ?? 'USD',
      dayOfMonth: parsedDayOfMonth,
      startDate: parsedStartDate,
      lastAppliedAt: DateTime.tryParse((map['lastAppliedAt'] as String?) ?? ''),
      isActive: (map['isActive'] as bool?) ?? true,
      cadence: PlannedCadenceX.fromKey(
        (map['cadence'] as String?) ?? 'monthly',
      ),
      weekDay: parsedWeekday,
      monthOfYear: parsedMonthOfYear,
      endDate: DateTime.tryParse((map['endDate'] as String?) ?? ''),
    );
  }
}
