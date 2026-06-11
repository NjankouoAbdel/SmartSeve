import 'package:intl/intl.dart';

class CurrencyUtils {
  static const Map<String, String> _symbols = <String, String>{
    'USD': r'$',
    'EUR': 'EUR',
    'MAD': 'MAD',
    'GBP': 'GBP',
    'AED': 'AED',
    'CHF': 'CHF',
    'CAD': 'CAD',
    'AUD': 'AUD',
    'JPY': 'JPY',
    'CNY': 'CNY',
    'SAR': 'SAR',
    'QAR': 'QAR',
    'KWD': 'KWD',
    'BTC': 'BTC',
    'ETH': 'ETH',
    'USDT': 'USDT',
    'BNB': 'BNB',
    'SOL': 'SOL',
    'ADA': 'ADA',
    'DOGE': 'DOGE',
    'DOT': 'DOT',
    'MATIC': 'MATIC',
    'LTC': 'LTC',
    'XRP': 'XRP',
  };

  static List<String> get supportedCurrencies => _symbols.keys.toList();

  static String symbolOf(String code) {
    return _symbols[code] ?? code;
  }

  static String formatAmount(double amount, String currencyCode) {
    final String symbol = symbolOf(currencyCode);
    final String value = NumberFormat('#,##0.00').format(amount);
    return '$symbol $value';
  }
}
