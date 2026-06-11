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
