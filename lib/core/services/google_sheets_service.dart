import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';
import 'package:wfer_flousk_firebase/core/constants/app_constants.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class GoogleSheetsService {
  GoogleSheetsService({
    String spreadsheetId = AppConstants.googleSheetsSpreadsheetId,
    String serviceAccountJson = AppConstants.googleSheetsServiceAccountJson,
  }) : _spreadsheetId = spreadsheetId.trim(),
       _serviceAccountJson = serviceAccountJson.trim();

  final String _spreadsheetId;
  final String _serviceAccountJson;

  bool get isConfigured {
    return _spreadsheetId.isNotEmpty && _serviceAccountJson.isNotEmpty;
  }

  Future<String> exportExpenses(List<Expense> expenses) async {
    if (!isConfigured) {
      throw StateError(
        'Google Sheets is not configured. Add spreadsheet id and service account credentials in AppConstants.',
      );
    }

    final GSheets gSheets = GSheets(_serviceAccountJson);
    final Spreadsheet spreadsheet = await gSheets.spreadsheet(_spreadsheetId);
    final String title =
        'Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    final Worksheet sheet =
        spreadsheet.worksheetByTitle(title) ??
        await spreadsheet.addWorksheet(title);

    await sheet.values.insertRow(1, <String>[
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
    ]);

    final List<List<String>> rows = expenses
        .map((Expense expense) {
          return <String>[
            expense.id,
            expense.amount.toString(),
            expense.category.key,
            expense.date.toIso8601String(),
            expense.note,
            expense.currencyCode,
            expense.accountId,
            expense.customCategoryId ?? '',
            expense.customCategoryName ?? '',
            expense.customCategoryIconCodePoint?.toString() ?? '',
            expense.customCategoryColorValue?.toString() ?? '',
            expense.isTransfer.toString(),
            expense.transferGroupId ?? '',
          ];
        })
        .toList(growable: false);

    if (rows.isNotEmpty) {
      await sheet.values.insertRows(2, rows);
    }

    return 'https://docs.google.com/spreadsheets/d/$_spreadsheetId';
  }
}

