import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class ExportArtifact {
  const ExportArtifact({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

class ExportService {
  Future<ExportArtifact> generateExpensesPdf(
    List<Expense> expenses,
    String currencyCode,
  ) async {
    final pw.Document document = pw.Document();
    final List<Expense> sorted = expenses.toList(growable: false)
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));

    document.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Text(
                'Smart Daily Expense Manager_firebase - Expense Report',
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 12),
            if (expenses.isEmpty)
              pw.Text('No expenses available.')
            else
              pw.TableHelper.fromTextArray(
                headers: const <String>['Date', 'Category', 'Amount', 'Note'],
                data: sorted
                    .map(
                      (Expense expense) => <String>[
                        DateUtilsX.short(expense.date),
                        expense.categoryLabel('en'),
                        CurrencyUtils.formatAmount(
                          expense.amount,
                          currencyCode,
                        ),
                        expense.note,
                      ],
                    )
                    .toList(),
              ),
          ];
        },
      ),
    );

    final String timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());
    return ExportArtifact(
      fileName: 'expense_report_$timestamp.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList(await document.save()),
    );
  }

  Future<ExportArtifact> generateExpensesExcel(
    List<Expense> expenses,
    String currencyCode,
  ) async {
    final xl.Excel workbook = xl.Excel.createExcel();
    final String defaultSheet = workbook.getDefaultSheet() ?? 'Sheet1';
    const String sheetName = 'Expenses';
    if (defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }

    workbook.appendRow(sheetName, <xl.CellValue?>[
      xl.TextCellValue('Date'),
      xl.TextCellValue('Category'),
      xl.TextCellValue('Amount'),
      xl.TextCellValue('Currency'),
      xl.TextCellValue('Account'),
      xl.TextCellValue('Note'),
    ]);

    final List<Expense> sorted = expenses.toList(growable: false)
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));
    for (final Expense expense in sorted) {
      workbook.appendRow(sheetName, <xl.CellValue?>[
        xl.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(expense.date)),
        xl.TextCellValue(expense.categoryLabel('en')),
        xl.DoubleCellValue(expense.amount),
        xl.TextCellValue(currencyCode),
        xl.TextCellValue(expense.accountId),
        xl.TextCellValue(expense.note),
      ]);
    }

    final List<int>? encoded = workbook.encode();
    if (encoded == null) {
      throw StateError('Failed to generate Excel file.');
    }

    final String timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());
    return ExportArtifact(
      fileName: 'expense_report_$timestamp.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      bytes: Uint8List.fromList(encoded),
    );
  }

  Future<ExportArtifact> generateBackupJson(List<Expense> expenses) async {
    final String timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());

    final Map<String, dynamic> payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'expenses': expenses
          .map(
            (Expense expense) => <String, dynamic>{
              'id': expense.id,
              'amount': expense.amount,
              'category': expense.category.key,
              'date': expense.date.toIso8601String(),
              'note': expense.note,
              'currencyCode': expense.currencyCode,
              'accountId': expense.accountId,
              'customCategoryId': expense.customCategoryId,
              'customCategoryName': expense.customCategoryName,
              'customCategoryIconCodePoint':
                  expense.customCategoryIconCodePoint,
              'customCategoryColorValue': expense.customCategoryColorValue,
              'isTransfer': expense.isTransfer,
              'transferGroupId': expense.transferGroupId,
            },
          )
          .toList(),
    };

    return ExportArtifact(
      fileName: 'expense_backup_$timestamp.json',
      mimeType: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    );
  }

  List<Expense> parseBackupJson({
    required Uint8List bytes,
    required String fallbackCurrency,
  }) {
    final String jsonString = utf8.decode(bytes);
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file format.');
    }

    final dynamic rawExpenses = decoded['expenses'];
    if (rawExpenses is! List) {
      throw const FormatException('Backup file does not contain expenses.');
    }

    final List<Expense> restored = <Expense>[];
    for (final dynamic item in rawExpenses) {
      if (item is! Map) {
        continue;
      }

      final Map<dynamic, dynamic> map = item;
      final String id = (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : 'restored_${DateTime.now().microsecondsSinceEpoch}';
      final double amount = (map['amount'] as num?)?.toDouble() ?? 0;
      if (amount == 0) {
        continue;
      }

      final String categoryKey = (map['category'] as String?) ?? 'other';
      final DateTime date =
          DateTime.tryParse((map['date'] as String?) ?? '') ?? DateTime.now();
      final String note = (map['note'] as String?) ?? '';
      final String currencyCode =
          (map['currencyCode'] as String?)?.trim() ?? '';
      final String accountId =
          (map['accountId'] as String?)?.trim().isNotEmpty == true
          ? map['accountId'] as String
          : 'main';

      restored.add(
        Expense(
          id: id,
          amount: amount,
          category: ExpenseCategoryX.fromKey(categoryKey),
          date: date,
          note: note,
          currencyCode: currencyCode.isEmpty ? fallbackCurrency : currencyCode,
          accountId: accountId,
          customCategoryId: _asNullableString(map['customCategoryId']),
          customCategoryName: _asNullableString(map['customCategoryName']),
          customCategoryIconCodePoint:
              (map['customCategoryIconCodePoint'] as num?)?.toInt(),
          customCategoryColorValue: (map['customCategoryColorValue'] as num?)
              ?.toInt(),
          isTransfer: (map['isTransfer'] as bool?) ?? false,
          transferGroupId: _asNullableString(map['transferGroupId']),
        ),
      );
    }

    return restored;
  }

  static String? _asNullableString(dynamic value) {
    final String text = (value as String?)?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return text;
  }
}

