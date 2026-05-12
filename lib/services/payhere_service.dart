import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as webpkg;

class PayHereService {

  /// Initiates a PayHere checkout session.
  ///
  /// Calls the `payhere-hash` Edge Function to generate the payment hash
  /// server-side (keeps the merchant secret out of the client bundle),
  /// then submits a hidden POST form to the PayHere checkout page.
  static Future<void> checkout({
    required String planName,
    required String planSlug,
    required int    amount,        // effective monthly price in LKR
    required bool   isAnnual,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String orgId,
  }) async {
    final billing      = isAnnual ? amount * 12 : amount;
    final orderId      = const Uuid().v4();
    final amountStr    = billing.toStringAsFixed(2);
    const currency     = 'LKR';
    final billingCycle = isAnnual ? 'annually' : 'monthly';

    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        'payhere-hash',
        body: {
          'orderId':      orderId,
          'amount':       amountStr,
          'currency':     currency,
          'orgId':        orgId,
          'planSlug':     planSlug,
          'billingCycle': billingCycle,
        },
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = (details is Map && details.containsKey('error'))
          ? details['error'] as String
          : details?.toString() ?? 'Unexpected error';
      throw Exception(msg);
    }

    final data        = response.data as Map<String, dynamic>;
    final hash        = data['hash']        as String;
    final merchantId  = data['merchantId']  as String;
    final notifyUrl   = data['notifyUrl']   as String;
    final checkoutUrl = data['checkoutUrl'] as String;

    final origin = webpkg.window.location.origin;

    final fields = {
      'merchant_id': merchantId,
      'return_url':  '$origin/app/dashboard?upgraded=1',
      'cancel_url':  '$origin/app/upgrade',
      'notify_url':  notifyUrl,
      'order_id':    orderId,
      'items':       '$planName – ${isAnnual ? "Annual" : "Monthly"}',
      'currency':    currency,
      'amount':      amountStr,
      'first_name':  firstName,
      'last_name':   lastName,
      'email':       email,
      'phone':       phone,
      'address':     'N/A',
      'city':        'Colombo',
      'country':     'Sri Lanka',
      'hash':        hash,
    };

    final form = webpkg.document.createElement('form') as webpkg.HTMLFormElement;
    form.method = 'post';
    form.action = checkoutUrl; // sandbox or production — decided server-side
    for (final e in fields.entries) {
      final input = webpkg.document.createElement('input') as webpkg.HTMLInputElement;
      input.type  = 'hidden';
      input.name  = e.key;
      input.value = e.value;
      form.appendChild(input);
    }
    webpkg.document.body!.appendChild(form);
    form.submit();
  }
}
