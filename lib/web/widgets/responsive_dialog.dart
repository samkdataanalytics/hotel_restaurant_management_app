import 'package:flutter/material.dart';

/// A [Dialog] that:
/// - caps its width at [maxWidth] (default 480)
/// - shrinks to fit on narrow screens instead of overflowing
/// - uses tighter horizontal inset padding on phones so dialogs
///   aren't squeezed into tiny strips
/// - wraps content in a [SingleChildScrollView] so tall dialogs
///   remain usable on small screens
///
/// Drop-in replacement for:
///   Dialog(shape: ..., child: SizedBox(width: 480, child: ...))
/// →
///   ResponsiveDialog(child: ...)
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final BorderRadius? borderRadius;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final radius = borderRadius ?? BorderRadius.circular(isMobile ? 16 : 20);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: radius),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
        vertical: isMobile ? 8 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

/// Same as [ResponsiveDialog] but without the [SingleChildScrollView] wrapper —
/// use this when the dialog content manages its own scrolling internally
/// (e.g. contains a ListView or its own scroll view).
class ResponsiveDialogNoScroll extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final BorderRadius? borderRadius;

  const ResponsiveDialogNoScroll({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final radius = borderRadius ?? BorderRadius.circular(isMobile ? 16 : 20);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: radius),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
        vertical: isMobile ? 8 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Constrain an [AlertDialog]'s content width on mobile.
/// Use in place of `content: SizedBox(width: 420, child: ...)`:
///   content: alertDialogContent(context, maxWidth: 420, child: ...)
Widget alertDialogContent(
  BuildContext context, {
  required Widget child,
  double maxWidth = 420,
}) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: (MediaQuery.of(context).size.width - 48).clamp(0, maxWidth),
    ),
    child: child,
  );
}
