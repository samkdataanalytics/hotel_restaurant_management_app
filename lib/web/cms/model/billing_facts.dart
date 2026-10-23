/// Numbers the site quotes that are also enforced elsewhere.
///
/// They are constants here, not content: if an admin could retype "45" in a
/// headline, the page could promise a trial the database does not grant, or an
/// annual saving the checkout does not apply. Copy refers to them by token
/// (`{trialDays}`, `{annualDiscountPct}`), and `test/cms/billing_facts_test.dart`
/// fails if these drift from the SQL functions and the payhere-hash edge
/// function that actually apply them.
class BillingFacts {
  BillingFacts._();

  /// `create_organization` sets `trial_ends_at = now() + interval '45 days'`.
  static const trialDays = 45;

  /// `ANNUAL_DISCOUNT = 0.20` in supabase/functions/payhere-hash.
  static const annualDiscountPct = 20;

  /// Per-month price on annual billing: the monthly rate less the discount,
  /// rounded the same way the checkout rounds it.
  static int annualMonthly(double monthly) =>
      (monthly * (1 - annualDiscountPct / 100)).round();

  static const tokens = {
    'trialDays': '$trialDays',
    'annualDiscountPct': '$annualDiscountPct',
  };
}
