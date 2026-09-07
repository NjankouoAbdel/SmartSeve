import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';

class OcrService {
  OcrService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<OcrScanResult?> scanReceipt(ImageSource source) async {
    if (kIsWeb) {
      throw const OcrServiceException(
        'Receipt scanner is available on Android and iOS. Web does not support ML OCR here.',
      );
    }

    final bool allowed = await _requestPermission(source);
    if (!allowed) {
      throw const OcrServiceException(
        'Camera/Photos permission is required to scan receipts.',
      );
    }

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (image == null) {
      return null;
    }

    final InputImage inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognized = await _textRecognizer.processImage(
      inputImage,
    );

    final String text = recognized.text;
    if (text.trim().isEmpty) {
      throw const OcrServiceException(
        'No readable text was found. Try a clearer photo.',
      );
    }
    final double? amount = _extractAmount(text);
    final DateTime? date = _extractDate(text);
    final String note = _extractNote(recognized);

    return OcrScanResult(
      rawText: text,
      amount: amount,
      date: date,
      suggestedNote: note,
    );
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final PermissionStatus status = await Permission.camera.request();
      return status.isGranted;
    }

    final PermissionStatus photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) {
      return true;
    }

    final PermissionStatus storage = await Permission.storage.request();
    return storage.isGranted;
  }

  double? _extractAmount(String text) {
    final RegExp regex = RegExp(r'(\d+[\.,]\d{2})');
    final Iterable<RegExpMatch> matches = regex.allMatches(text);
    double? best;

    for (final RegExpMatch match in matches) {
      final String? group = match.group(0);
      if (group == null) {
        continue;
      }
      final double? value = double.tryParse(group.replaceAll(',', '.'));
      if (value == null) {
        continue;
      }

      if (best == null || value > best) {
        best = value;
      }
    }

    return best;
  }

  DateTime? _extractDate(String text) {
    final RegExp slashDate = RegExp(r'(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})');
    final RegExpMatch? match = slashDate.firstMatch(text);
    if (match == null) {
      return null;
    }

    final int? day = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');
    int? year = int.tryParse(match.group(3) ?? '');

    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 100) {
      year += 2000;
    }

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _extractNote(RecognizedText recognizedText) {
    for (final TextBlock block in recognizedText.blocks) {
      for (final TextLine line in block.lines) {
        final String clean = line.text.trim();
        if (clean.length > 3 && !_looksLikeOnlyNumbers(clean)) {
          return clean;
        }
      }
    }

    return 'Scanned receipt';
  }

  bool _looksLikeOnlyNumbers(String value) {
    return RegExp(r'^[\d\s\.,\-/:]+$').hasMatch(value);
  }

  // ===========================================================================
  // SCAN DE RELEVE BANCAIRE - plusieurs transactions en une seule photo
  // ===========================================================================
  //
  // Contrairement a scanReceipt() (qui cherche UN montant sur UN recu), ici on
  // essaie de retrouver PLUSIEURS transactions, une par ligne du relevé.
  // C'est un parsing "au mieux": la reconnaissance de texte ne recree pas
  // parfaitement un tableau, donc une ligne mal alignee ou mal photographiee
  // peut etre ratee ou mal lue. C'est pour ca que l'ecran de revue (cote UI)
  // laisse l'utilisateur corriger/decocher chaque ligne avant l'import.

  // Date: 05/09/2026, 05-09-26, 05.09.2026, etc.
  static final RegExp _dateLineRegex = RegExp(
    r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})',
  );

  // Montant: -45,20 / +1 200,00 / 1.200,00 / 60.00 (espace ou point comme
  // separateur de milliers, virgule ou point comme separateur decimal).
  static final RegExp _amountLineRegex = RegExp(
    r'([+-]?\d{1,3}(?:[ .]\d{3})*(?:[.,]\d{2}))',
  );

  static const List<String> _incomeKeywords = <String>[
    'virement recu',
    'vir recu',
    'salaire',
    'remboursement',
    'remb.',
    'depot',
    'credit ',
    'paie',
    'salary',
    'refund',
    'deposit',
  ];

  static const Map<String, ExpenseCategory> _categoryKeywordHints = <String, ExpenseCategory>{
    'carrefour': ExpenseCategory.food,
    'supermarche': ExpenseCategory.food,
    'super u': ExpenseCategory.food,
    'leclerc': ExpenseCategory.food,
    'monoprix': ExpenseCategory.food,
    'restaurant': ExpenseCategory.food,
    'boulangerie': ExpenseCategory.food,
    'uber': ExpenseCategory.transport,
    'sncf': ExpenseCategory.transport,
    'ratp': ExpenseCategory.transport,
    'essence': ExpenseCategory.transport,
    'station': ExpenseCategory.transport,
    'parking': ExpenseCategory.transport,
    'loyer': ExpenseCategory.rent,
    'edf': ExpenseCategory.bills,
    'engie': ExpenseCategory.bills,
    'orange': ExpenseCategory.bills,
    'sfr': ExpenseCategory.bills,
    'free mobile': ExpenseCategory.bills,
    'bouygues': ExpenseCategory.bills,
    'facture': ExpenseCategory.bills,
    'assurance': ExpenseCategory.bills,
    'amazon': ExpenseCategory.shopping,
    'zara': ExpenseCategory.shopping,
    'fnac': ExpenseCategory.shopping,
  };

  /// Scanne une photo de relevé bancaire et tente d'en extraire toutes les
  /// transactions (une par ligne detectee avec a la fois une date et un
  /// montant). Retourne `null` si l'utilisateur annule la selection d'image.
  Future<BankStatementScanResult?> scanBankStatement(ImageSource source) async {
    if (kIsWeb) {
      throw const OcrServiceException(
        'Bank statement scanning is available on Android and iOS. Web does not support ML OCR here.',
      );
    }

    final bool allowed = await _requestPermission(source);
    if (!allowed) {
      throw const OcrServiceException(
        'Camera/Photos permission is required to scan a statement.',
      );
    }

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (image == null) {
      return null;
    }

    final InputImage inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognized = await _textRecognizer.processImage(
      inputImage,
    );

    final String text = recognized.text;
    if (text.trim().isEmpty) {
      throw const OcrServiceException(
        'No readable text was found. Try a clearer, well-lit photo of the statement.',
      );
    }

    final List<ScannedTransaction> transactions = _parseStatementTransactions(
      recognized,
    );
    if (transactions.isEmpty) {
      throw const OcrServiceException(
        'No transaction lines were recognized. Make sure the photo shows '
        'clear rows with a date and an amount on each line.',
      );
    }

    return BankStatementScanResult(rawText: text, transactions: transactions);
  }

  List<ScannedTransaction> _parseStatementTransactions(
    RecognizedText recognized,
  ) {
    final List<ScannedTransaction> results = <ScannedTransaction>[];
    // Cap de securite: une tres longue liste de lignes mal reconnues ne doit
    // pas produire des centaines de fausses transactions a trier.
    const int maxTransactions = 200;

    for (final TextBlock block in recognized.blocks) {
      for (final TextLine line in block.lines) {
        if (results.length >= maxTransactions) {
          return results;
        }
        final String raw = line.text.trim();
        if (raw.isEmpty) {
          continue;
        }

        final DateTime? date = _extractLineDate(raw);
        final RegExpMatch? amountMatch = _amountLineRegex.firstMatch(raw);
        if (date == null || amountMatch == null) {
          continue; // pas assez d'info pour etre sur d'une transaction
        }

        final double? parsedAmount = _parseAmountToken(amountMatch.group(0)!);
        if (parsedAmount == null) {
          continue;
        }

        final String token = amountMatch.group(0)!;
        final bool explicitDebit = token.trim().startsWith('-');
        final bool explicitCredit = token.trim().startsWith('+');
        final bool incomeLike = _looksLikeIncome(raw);

        // Convention de l'app: positif = depense, negatif = revenu (voir le
        // commentaire sur ScannedTransaction). Le relevé, lui, montre les
        // depenses en negatif -> on inverse le signe ici.
        final double appAmount = explicitDebit
            ? parsedAmount.abs()
            : explicitCredit
            ? -parsedAmount.abs()
            : (incomeLike ? -parsedAmount.abs() : parsedAmount.abs());

        String description = raw.replaceAll(token, ' ');
        description = description.replaceAll(_dateLineRegex, ' ');
        description = description.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (description.length < 2) {
          description = 'Transaction';
        }

        results.add(
          ScannedTransaction(
            rawLine: raw,
            amount: appAmount,
            date: date,
            description: description,
            suggestedCategory: _guessCategory(description),
          ),
        );
      }
    }

    return results;
  }

  DateTime? _extractLineDate(String line) {
    final RegExpMatch? match = _dateLineRegex.firstMatch(line);
    if (match == null) {
      return null;
    }
    final int? day = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');
    int? year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) {
      return null;
    }
    if (year < 100) {
      year += 2000;
    }
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  double? _parseAmountToken(String token) {
    String normalized = token.trim().replaceAll(' ', '');
    normalized = normalized.replaceAll(RegExp(r'^[+-]'), '');
    if (normalized.contains(',')) {
      // Format europeen: point = milliers, virgule = decimales.
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  bool _looksLikeIncome(String line) {
    final String lower = line.toLowerCase();
    return _incomeKeywords.any((String k) => lower.contains(k));
  }

  ExpenseCategory _guessCategory(String description) {
    final String lower = description.toLowerCase();
    for (final MapEntry<String, ExpenseCategory> entry
        in _categoryKeywordHints.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return ExpenseCategory.other;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class OcrServiceException implements Exception {
  const OcrServiceException(this.message);

  final String message;
}

