import 'package:hive/hive.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.amount,
    required this.categoryKey,
    required this.date,
    required this.note,
    required this.currencyCode,
    this.accountId = 'main',
    this.customCategoryId,
    this.customCategoryName,
    this.customCategoryIconCodePoint,
    this.customCategoryColorValue,
    this.isTransfer = false,
    this.transferGroupId,
  });

  final String id;
  final double amount;
  final String categoryKey;
  final DateTime date;
  final String note;
  final String currencyCode;
  final String accountId;
  final String? customCategoryId;
  final String? customCategoryName;
  final int? customCategoryIconCodePoint;
  final int? customCategoryColorValue;
  final bool isTransfer;
  final String? transferGroupId;

  Expense toEntity() {
    return Expense(
      id: id,
      amount: amount,
      category: ExpenseCategoryX.fromKey(categoryKey),
      date: date,
      note: note,
      currencyCode: currencyCode,
      accountId: accountId,
      customCategoryId: (customCategoryId ?? '').trim().isEmpty
          ? null
          : customCategoryId,
      customCategoryName: (customCategoryName ?? '').trim().isEmpty
          ? null
          : customCategoryName,
      customCategoryIconCodePoint: (customCategoryIconCodePoint ?? -1) < 0
          ? null
          : customCategoryIconCodePoint,
      customCategoryColorValue: (customCategoryColorValue ?? -1) < 0
          ? null
          : customCategoryColorValue,
      isTransfer: isTransfer,
      transferGroupId: (transferGroupId ?? '').trim().isEmpty
          ? null
          : transferGroupId,
    );
  }

  factory ExpenseModel.fromEntity(Expense expense) {
    return ExpenseModel(
      id: expense.id,
      amount: expense.amount,
      categoryKey: expense.category.key,
      date: expense.date,
      note: expense.note,
      currencyCode: expense.currencyCode,
      accountId: expense.accountId,
      customCategoryId: expense.customCategoryId,
      customCategoryName: expense.customCategoryName,
      customCategoryIconCodePoint: expense.customCategoryIconCodePoint,
      customCategoryColorValue: expense.customCategoryColorValue,
      isTransfer: expense.isTransfer,
      transferGroupId: expense.transferGroupId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'categoryKey': categoryKey,
      'date': date.toIso8601String(),
      'note': note,
      'currencyCode': currencyCode,
      'accountId': accountId,
      'customCategoryId': customCategoryId,
      'customCategoryName': customCategoryName,
      'customCategoryIconCodePoint': customCategoryIconCodePoint,
      'customCategoryColorValue': customCategoryColorValue,
      'isTransfer': isTransfer,
      'transferGroupId': transferGroupId,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryKey: map['categoryKey'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String,
      currencyCode: map['currencyCode'] as String,
      accountId: (map['accountId'] as String?) ?? 'main',
      customCategoryId: map['customCategoryId'] as String?,
      customCategoryName: map['customCategoryName'] as String?,
      customCategoryIconCodePoint: (map['customCategoryIconCodePoint'] as num?)
          ?.toInt(),
      customCategoryColorValue: (map['customCategoryColorValue'] as num?)
          ?.toInt(),
      isTransfer: (map['isTransfer'] as bool?) ?? false,
      transferGroupId: map['transferGroupId'] as String?,
    );
  }
}

class ExpenseModelAdapter extends TypeAdapter<ExpenseModel> {
  @override
  final int typeId = 1;

  @override
  ExpenseModel read(BinaryReader reader) {
    final String id = reader.readString();
    final double amount = reader.readDouble();
    final String categoryKey = reader.readString();
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final String note = reader.readString();
    final String currencyCode = reader.readString();
    String accountId = 'main';
    String? customCategoryId;
    String? customCategoryName;
    int? customCategoryIconCodePoint;
    int? customCategoryColorValue;
    bool isTransfer = false;
    String? transferGroupId;
    try {
      accountId = reader.readString();
    } catch (_) {}
    try {
      customCategoryId = reader.readString();
    } catch (_) {}
    try {
      customCategoryName = reader.readString();
    } catch (_) {}
    try {
      customCategoryIconCodePoint = reader.readInt();
    } catch (_) {}
    try {
      customCategoryColorValue = reader.readInt();
    } catch (_) {}
    try {
      isTransfer = reader.readBool();
    } catch (_) {}
    try {
      transferGroupId = reader.readString();
    } catch (_) {}

    return ExpenseModel(
      id: id,
      amount: amount,
      categoryKey: categoryKey,
      date: date,
      note: note,
      currencyCode: currencyCode,
      accountId: accountId,
      customCategoryId: (customCategoryId ?? '').trim().isEmpty
          ? null
          : customCategoryId,
      customCategoryName: (customCategoryName ?? '').trim().isEmpty
          ? null
          : customCategoryName,
      customCategoryIconCodePoint: (customCategoryIconCodePoint ?? -1) < 0
          ? null
          : customCategoryIconCodePoint,
      customCategoryColorValue: (customCategoryColorValue ?? -1) < 0
          ? null
          : customCategoryColorValue,
      isTransfer: isTransfer,
      transferGroupId: (transferGroupId ?? '').trim().isEmpty
          ? null
          : transferGroupId,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseModel obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.amount);
    writer.writeString(obj.categoryKey);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.note);
    writer.writeString(obj.currencyCode);
    writer.writeString(obj.accountId);
    writer.writeString(obj.customCategoryId ?? '');
    writer.writeString(obj.customCategoryName ?? '');
    writer.writeInt(obj.customCategoryIconCodePoint ?? -1);
    writer.writeInt(obj.customCategoryColorValue ?? -1);
    writer.writeBool(obj.isTransfer);
    writer.writeString(obj.transferGroupId ?? '');
  }
}

