import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';

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

  void dispose() {
    _textRecognizer.close();
  }
}

class OcrServiceException implements Exception {
  const OcrServiceException(this.message);

  final String message;
}

