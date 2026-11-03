import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// Colours and small shared pieces for the studio chrome. The studio is part of
/// the superadmin console, so it uses the admin tokens, not the marketing site's.
class SC {
  SC._();

  static const bg = AppTheme.pageBg;
  static const panel = Colors.white;
  static const border = AppTheme.cardBorder;
  static const text = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const accent = AppTheme.brandTeal;
  static const accentBg = Color(0xFFEFF8F7);
  static const danger = AppTheme.statusRed;
  static const warn = AppTheme.statusAmber;
  static const ok = AppTheme.statusGreen;
  static const warnBg = Color(0xFFFFF7E6);
  static const dangerBg = Color(0xFFFEF2F2);

  static const label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: text);
  static const small = TextStyle(fontSize: 12, color: muted, height: 1.4);
  static const body = TextStyle(fontSize: 13.5, color: text, height: 1.4);
  static const title = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text);

  static InputDecoration input({String? hint, String? suffix, String? error, bool dense = true}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: faint, fontSize: 13),
        suffixText: suffix,
        errorText: error,
        isDense: dense,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      );
}

/// A small coloured pill.
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.color = SC.muted, this.bg, this.icon});

  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg ?? color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}
