import 'package:flutter/material.dart';

enum StudioWorkspace { pages, navigation, theme, settings, media }

/// A document the studio can edit as a list of sections.
class StudioPage {
  const StudioPage(this.key, this.label, this.icon, this.route, {this.legal = false});

  final String key;
  final String label;
  final IconData icon;

  /// Where it lives on the public site, for the "view live" link.
  final String route;

  /// Legal text: publishing needs a note saying what changed and why.
  final bool legal;
}

/// Pages in the page picker. Add a page here, in `kSiteDefaults`, and give its
/// route a screen that reads the document.
const List<StudioPage> kStudioPages = [
  StudioPage('page:home', 'Home', Icons.home_rounded, '/'),
  StudioPage('page:help', 'Help centre', Icons.menu_book_rounded, '/help'),
  StudioPage('page:terms', 'Terms of service', Icons.gavel_rounded, '/terms', legal: true),
  StudioPage('page:privacy', 'Privacy policy', Icons.privacy_tip_rounded, '/privacy', legal: true),
  StudioPage('page:returns', 'Refund policy', Icons.assignment_return_rounded, '/returns', legal: true),
  StudioPage('page:auth', 'Sign-in & sign-up', Icons.login_rounded, '/login'),
];

StudioPage? studioPageFor(String key) {
  for (final p in kStudioPages) {
    if (p.key == key) return p;
  }
  return null;
}
