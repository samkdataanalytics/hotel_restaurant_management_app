import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/staff_mobile/data/money.dart';

void main() {
  group('decimal places follow the currency', () {
    test('a normal currency gets two', () {
      expect(Money(code: 'LKR', symbol: 'Rs').format(4800), 'Rs4,800.00');
      expect(Money(code: 'USD', symbol: r'$').format(12.5), r'$12.50');
    });

    test('a zero-decimal currency gets none', () {
      // Printing "¥4,800.00" marks the app out as foreign-built in Tokyo.
      expect(Money(code: 'JPY', symbol: '¥').format(4800), '¥4,800');
      expect(Money(code: 'IDR', symbol: 'Rp').format(50000), 'Rp50,000');
    });
  });

  group('readability', () {
    test('groups thousands, so a five-figure bill cannot be misread', () {
      expect(Money(code: 'LKR', symbol: 'Rs').format(1234567.89),
          'Rs1,234,567.89');
    });

    test('rounds to the currency precision rather than truncating', () {
      expect(Money(code: 'USD', symbol: r'$').format(9.999), r'$10.00');
    });
  });

  group('variants', () {
    test('bare omits the symbol for places that show it separately', () {
      expect(Money(code: 'USD', symbol: r'$').bare(40), '40.00');
    });

    test('signed marks a negative, for a discount or refund line', () {
      final money = Money(code: 'USD', symbol: r'$');
      expect(money.signed(-25), r'-$25.00');
      expect(money.signed(25), r'$25.00');
    });

    test('zero formats normally rather than as a dash or blank', () {
      expect(Money(code: 'USD', symbol: r'$').format(0), r'$0.00');
    });
  });

  test('an unknown property currency degrades to a bare number', () {
    // Showing the wrong currency is worse than showing none.
    expect(Money(code: '', symbol: '').format(100), '100.00');
  });
}
