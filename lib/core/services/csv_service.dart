import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class CsvService {
  CsvService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<String> exportExpenses(List<Expense> expenses) async {
    final List<List<dynamic>> rows = <List<dynamic>>[
      <String>[
        'id',
        'amount',
        'category',
        'date',
        'note',
        'currencyCode',
        'accountId',
        'customCategoryId',
        'customCategoryName',
        'customCategoryIconCodePoint',
        'customCategoryColorValue',
        'isTransfer',
        'transferGroupId',
      ],
      ...expenses.map(
        (Expense expense) => <dynamic>[
          expense.id,
          expense.amount,
          expense.category.key,
          expense.date.toIso8601String(),
          expense.note,
          expense.currencyCode,
          expense.accountId,
          expense.customCategoryId ?? '',
          expense.customCategoryName ?? '',
          expense.customCategoryIconCodePoint ?? '',
          expense.customCategoryColorValue ?? '',
          expense.isTransfer,
          expense.transferGroupId ?? '',
        ],
      ),
    ];

    final String csvText = const ListToCsvConverter().convert(rows);
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory exportDir = Directory('${docsDir.path}/csv_exports');
    if (!exportDir.existsSync()) {
      await exportDir.create(recursive: true);
    }

    final String timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());
    final File file = File('${exportDir.path}/expenses_$timestamp.csv');
    await file.writeAsString(csvText);
    return file.path;
  }

  Future<List<Expense>> importExpenses({
    required String fallbackCurrency,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
      withData: false,
    );

    if (result == null || result.files.single.path == null) {
      return <Expense>[];
    }

    final String content = await File(result.files.single.path!).readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);

    if (rows.length <= 1) {
      return <Expense>[];
    }

    final List<Expense> expenses = <Expense>[];
    for (int i = 1; i < rows.length; i++) {
      final List<dynamic> row = rows[i];
      if (row.length < 6) {
        continue;
      }

      final String id = (row[0] as String?)?.trim().isNotEmpty == true
          ? (row[0] as String)
          : _uuid.v4();
      final double amount =
          double.tryParse((row[1] as String?)?.replaceAll(',', '.') ?? '') ?? 0;
      if (amount <= 0) {
        continue;
      }

      final String categoryKey = (row[2] as String?)?.trim() ?? 'other';
      final DateTime date =
          DateTime.tryParse((row[3] as String?)?.trim() ?? '') ??
          DateTime.now();
      final String note = (row[4] as String?) ?? '';
      final String currencyCode = (row[5] as String?)?.trim().isNotEmpty == true
          ? (row[5] as String)
          : fallbackCurrency;
      final String accountId = row.length >= 7
          ? ((row[6] as String?)?.trim().isNotEmpty == true
                ? (row[6] as String)
                : 'main')
          : 'main';
      final String? customCategoryId = row.length >= 8
          ? _nullableText(row[7] as String?)
          : null;
      final String? customCategoryName = row.length >= 9
          ? _nullableText(row[8] as String?)
          : null;
      final int? customCategoryIconCodePoint = row.length >= 10
          ? int.tryParse((row[9] as String?)?.trim() ?? '')
          : null;
      final int? customCategoryColorValue = row.length >= 11
          ? int.tryParse((row[10] as String?)?.trim() ?? '')
          : null;
      final bool isTransfer = row.length >= 12
          ? ((row[11] as String?)?.toLowerCase().trim() == 'true')
          : false;
      final String? transferGroupId = row.length >= 13
          ? _nullableText(row[12] as String?)
          : null;

      expenses.add(
        Expense(
          id: id,
          amount: amount,
          category: ExpenseCategoryX.fromKey(categoryKey),
          date: date,
          note: note,
          currencyCode: currencyCode,
          accountId: accountId,
          customCategoryId: customCategoryId,
          customCategoryName: customCategoryName,
          customCategoryIconCodePoint: customCategoryIconCodePoint,
          customCategoryColorValue: customCategoryColorValue,
          isTransfer: isTransfer,
          transferGroupId: transferGroupId,
        ),
      );
    }

    return expenses;
  }

  String? _nullableText(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return text;
  }
}

