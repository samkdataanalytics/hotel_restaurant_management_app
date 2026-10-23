import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/service_providers.dart';
import '../../../services/plan_service.dart';

/// The active plans, fetched once per app session and shared by every section
/// that quotes a price. The comparison table and the pricing cards used to each
/// make their own request for the same rows.
///
/// Auto-disposed so that leaving the page and coming back fetches again, as each
/// section used to on its own, and a failed fetch is not remembered all session.
final activePlansProvider = FutureProvider.autoDispose<List<PlanModel>>(
  (ref) => ref.read(planServiceProvider).getActivePlans(),
);

/// The Starter plan's monthly price in whole currency units, or null while it
/// loads or if it cannot be had. Marketing copy shows a fallback in that case:
/// a missing price must not blank the page.
final starterMonthlyPriceProvider = FutureProvider.autoDispose<int?>((ref) async {
  try {
    final plans = await ref.watch(activePlansProvider.future);
    final starter = plans.where((p) => p.slug == 'starter').firstOrNull;
    return starter?.priceMonthly.toInt();
  } catch (_) {
    return null;
  }
});

/// 3450 -> "3,450".
String formatThousands(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
