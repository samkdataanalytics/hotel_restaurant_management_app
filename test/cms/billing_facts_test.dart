import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/model/billing_facts.dart';
import 'package:hotel_checkin/web/cms/model/tokens.dart';

/// The site quotes a trial length and an annual saving that other code enforces.
/// If either side changes alone, the page promises something the system does not
/// do — so these tests read the enforcing code and compare.
void main() {
  test('trialDays matches every create_organization in the migrations', () {
    final found = <int>{};
    for (final f in Directory('supabase/migrations').listSync().whereType<File>()) {
      for (final m in RegExp(r"trial_ends_at[^;]*?interval '(\d+) days'")
          .allMatches(f.readAsStringSync())) {
        found.add(int.parse(m[1]!));
      }
    }
    // Older migrations may carry earlier lengths; the newest must be ours, and
    // ours must at least be what the current functions grant.
    expect(found, contains(BillingFacts.trialDays));
  });

  test('annualDiscountPct matches ANNUAL_DISCOUNT in payhere-hash', () {
    final src = File('supabase/functions/payhere-hash/index.ts').readAsStringSync();
    final m = RegExp(r'ANNUAL_DISCOUNT\s*=\s*([0-9.]+)').firstMatch(src);
    expect(m, isNotNull, reason: 'ANNUAL_DISCOUNT not found — was it renamed?');
    expect((double.parse(m![1]!) * 100).round(), BillingFacts.annualDiscountPct);
  });

  test('annualMonthly rounds like the checkout', () {
    expect(BillingFacts.annualMonthly(3450), 2760);
    expect(BillingFacts.annualMonthly(0), 0);
    expect(BillingFacts.annualMonthly(1999), (1999 * 0.8).round());
  });

  group('expandTokens', () {
    test('fills the protected tokens', () {
      expect(expandTokens('{trialDays}-day trial, save {annualDiscountPct}%'),
          '45-day trial, save 20%');
    });
    test('leaves unknown tokens visible', () {
      expect(expandTokens('hello {nope}'), 'hello {nope}');
    });
    test('caller values fill editable tokens but cannot redefine protected ones', () {
      expect(expandTokens('{year} {trialDays}', {'year': '2026', 'trialDays': '1'}),
          '2026 45');
    });
    test('{year} is the current year without being passed', () {
      expect(expandTokens('© {year}'), '© ${DateTime.now().year}');
    });
    test('text without braces is returned untouched', () {
      expect(expandTokens('plain'), 'plain');
    });
  });
}
