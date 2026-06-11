import 'package:flutter_test/flutter_test.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';

void main() {
  test('Currency format uses configured symbol', () {
    expect(CurrencyUtils.formatAmount(1234.5, 'USD'), r'$ 1,234.50');
  });
}

