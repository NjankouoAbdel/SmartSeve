import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wfer_flousk_firebase/core/services/export_service.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

void main() {
  final ExportService service = ExportService();
  final List<Expense> sampleExpenses = <Expense>[
    Expense(
      id: '1',
      amount: 120.50,
      category: ExpenseCategory.food,
      date: DateTime(2026, 3, 1, 12, 30),
      note: 'Groceries',
      currencyCode: 'MAD',
    ),
    Expense(
      id: '2',
      amount: -6000,
      category: ExpenseCategory.other,
      date: DateTime(2026, 3, 2, 9, 0),
      note: 'Salary',
      currencyCode: 'MAD',
    ),
  ];

  test('generateExpensesPdf returns non-empty pdf bytes', () async {
    final ExportArtifact artifact = await service.generateExpensesPdf(
      sampleExpenses,
      'MAD',
    );

    expect(artifact.fileName.endsWith('.pdf'), isTrue);
    expect(artifact.mimeType, 'application/pdf');
    expect(artifact.bytes.isNotEmpty, isTrue);
  });

  test('generateExpensesExcel returns non-empty xlsx bytes', () async {
    final ExportArtifact artifact = await service.generateExpensesExcel(
      sampleExpenses,
      'MAD',
    );

    expect(artifact.fileName.endsWith('.xlsx'), isTrue);
    expect(
      artifact.mimeType,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(artifact.bytes.isNotEmpty, isTrue);
  });

  test('generateBackupJson returns valid json bytes', () async {
    final ExportArtifact artifact = await service.generateBackupJson(
      sampleExpenses,
    );

    expect(artifact.fileName.endsWith('.json'), isTrue);
    expect(artifact.mimeType, 'application/json');
    expect(artifact.bytes.isNotEmpty, isTrue);

    final Map<String, dynamic> decoded = jsonDecode(
      utf8.decode(artifact.bytes),
    ) as Map<String, dynamic>;
    expect(decoded.containsKey('generatedAt'), isTrue);
    expect(decoded.containsKey('expenses'), isTrue);
  });
}

