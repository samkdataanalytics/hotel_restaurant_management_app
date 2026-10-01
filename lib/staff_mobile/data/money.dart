import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/organization_service.dart';
import '../session/staff_session.dart';

/// Formats amounts in the active property's currency.
///
/// Every property carries an ISO code (`hotels.currency`), and the web already
/// maps those to symbols via [kCurrencies]. Until now the mobile app rendered
/// bare numbers — "4800.00" with no indication of what 4800 was — which is
/// wrong everywhere and actively misleading for an operator running properties
/// in more than one currency.
///
/// Decimal places follow the currency rather than being fixed at two: yen and
/// rupiah have no minor unit, and printing "¥4800.00" marks the app out as
/// foreign-built to anyone in Tokyo.
class Money {
  final String code;
  final String symbol;

  Money({required this.code, required this.symbol});

  /// Currencies with no minor unit in normal use.
  static const _zeroDecimal = {'JPY', 'KRW', 'IDR', 'VND', 'CLP', 'ISK'};

  int get _decimals => _zeroDecimal.contains(code) ? 0 : 2;

  late final NumberFormat _format = NumberFormat.currency(
    symbol: '',
    decimalDigits: _decimals,
  );

  /// e.g. `Rs 4,800.00`, or `¥4,800`.
  ///
  /// Grouped thousands, because a five-figure bill read off a phone at arm's
  /// length is otherwise easy to misread by an order of magnitude.
  String format(double amount) => '$symbol${_format.format(amount).trim()}';

  /// Without the symbol, for places that show it separately.
  String bare(double amount) => _format.format(amount).trim();

  /// Signed, for a discount or a refund line.
  String signed(double amount) =>
      amount < 0 ? '-${format(amount.abs())}' : format(amount);
}

/// Money formatter for the active property.
///
/// Falls back to the plain number with no symbol rather than guessing dollars:
/// showing the wrong currency is worse than showing none.
final moneyProvider = Provider<Money>((ref) {
  final code = ref.watch(
    staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.currency),
  );
  if (code == null || code.isEmpty) {
    return Money(code: '', symbol: '');
  }
  return Money(code: code, symbol: currencySymbolFor(code));
});
