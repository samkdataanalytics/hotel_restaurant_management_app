import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../landing/landing_dialogs.dart';
import '../model/link_target.dart';
import '../platform/open_external.dart';
import 'site_scope.dart';

/// Performs a [LinkTarget]. The one place section widgets navigate from.
///
/// Centralised for two reasons: an admin-defined link must go through the same
/// validation-and-dispatch path everywhere, and a preview must be able to make
/// every link inert in a single check rather than in each of twenty call sites.
void runLink(BuildContext context, LinkTarget target) {
  final scope = SiteScope.maybeOf(context);
  if (scope != null && !scope.live) return;

  switch (target.kind) {
    case LinkKind.none:
      return;
    case LinkKind.internal:
      context.go(target.value);
    case LinkKind.external:
      openExternal(target.value, newTab: target.newTab);
    case LinkKind.anchor:
      scope?.onScrollTo?.call(target.value);
    case LinkKind.action:
      switch (target.value) {
        case 'signup':
          context.go('/signup');
        case 'login':
          context.go('/login');
        case 'openDemo':
          showDialog<void>(context: context, builder: (_) => const DemoDialog());
        case 'openContactSales':
          showDialog<void>(
              context: context, builder: (_) => const EnterpriseContactDialog());
      }
  }
}
