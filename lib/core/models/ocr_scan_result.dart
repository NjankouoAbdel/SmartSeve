import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class OcrScanResult {
  const OcrScanResult({
    required this.rawText,
    required this.amount,
    required this.date,
    required this.suggestedNote,
  });

  final String rawText;
  final double? amount;
  final DateTime? date;
  final String suggestedNote;
}

/// Une transaction detectee dans un relevé bancaire scanne, avant validation
/// par l'utilisateur dans l'ecran de revue.
///
/// IMPORTANT - convention de signe: `amount` suit la convention utilisee
/// partout ailleurs dans l'app (voir Expense): positif = depense, negatif =
/// revenu. C'est l'inverse de la plupart des relevés bancaires papier, qui
/// affichent les depenses en negatif et les credits en positif — la
/// conversion est faite au moment du parsing, pas dans l'UI.
class ScannedTransaction {
  ScannedTransaction({
    required this.rawLine,
    required this.amount,
    this.date,
    this.description = '',
    this.suggestedCategory = ExpenseCategory.other,
    this.included = true,
  });

  /// La ligne de texte brute d'ou vient cette transaction (utile pour que
  /// l'utilisateur verifie/corrige en cas de doute sur le parsing).
  final String rawLine;

  double amount;
  DateTime? date;
  String description;
  ExpenseCategory suggestedCategory;

  /// Coche par defaut; l'utilisateur peut decocher une ligne mal detectee
  /// avant l'import group.
  bool included;
}

class BankStatementScanResult {
  const BankStatementScanResult({
    required this.rawText,
    required this.transactions,
  });

  final String rawText;
  final List<ScannedTransaction> transactions;
}
