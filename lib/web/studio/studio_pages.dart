import 'package:flutter/material.dart';

enum StudioWorkspace { pages, navigation, theme, media }

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
];

StudioPage? studioPageFor(String key) {
  for (final p in kStudioPages) {
    if (p.key == key) return p;
  }
  return null;
}
