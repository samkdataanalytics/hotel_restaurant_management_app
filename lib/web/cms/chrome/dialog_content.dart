import 'package:flutter/material.dart';

import '../model/json_reader.dart';
import '../model/link_target.dart';
import '../model/tokens.dart';
import '../registry/icon_registry.dart';

/// Icon tints an admin can pick for the demo highlights. Named, not free hex, so
/// the tile can never be unreadable.
const Map<String, Color> kHighlightTones = {
  'blue': Color(0xFF2563EB),
  'green': Color(0xFF16A34A),
  'teal': Color(0xFF0A7D77),
  'purple': Color(0xFF7C3AED),
  'red': Color(0xFFE5484D),
  'cyan': Color(0xFF0891B2),
};

class DemoHighlight {
  const DemoHighlight({required this.icon, required this.color, required this.title, required this.desc});

  factory DemoHighlight.fromJson(J j) => DemoHighlight(
        icon: IconRegistry.resolve(j.strOrNull('icon')),
        color: kHighlightTones[j.str('tone')] ?? kHighlightTones['teal']!,
        title: j.str('title'),
        desc: j.str('desc'),
      );

  final IconData icon;
  final Color color;
  final String title;
  final String desc;
}

class DemoTab {
  const DemoTab({required this.name, required this.items});

  factory DemoTab.fromJson(J j) => DemoTab(
        name: j.str('name'),
        items: j.list('items', DemoHighlight.fromJson).where((i) => i.title.isNotEmpty).toList(),
      );

  final String name;
  final List<DemoHighlight> items;
}

/// The "Watch demo" dialog.
class DemoContent {
  const DemoContent({
    required this.title,
    required this.subtitle,
    required this.closeLabel,
    required this.ctaLabel,
    required this.ctaLink,
    required this.tabs,
  });

  factory DemoContent.fromJson(J j) => DemoContent(
        title: expandTokens(j.str('title')),
        subtitle: expandTokens(j.str('subtitle')),
        closeLabel: j.str('closeLabel', 'Close'),
        ctaLabel: expandTokens(j.obj('cta').str('label')),
        ctaLink: LinkTarget.fromJson(j.obj('cta').obj('link')),
        tabs: j.list('tabs', DemoTab.fromJson).where((t) => t.name.isNotEmpty && t.items.isNotEmpty).toList(),
      );

  final String title;
  final String subtitle;
  final String closeLabel;
  final String ctaLabel;
  final LinkTarget ctaLink;
  final List<DemoTab> tabs;
}

/// The enterprise "Contact sales" dialog.
class ContactContent {
  const ContactContent({
    required this.title,
    required this.subtitle,
    required this.closeLabel,
    required this.nameLabel,
    required this.companyLabel,
    required this.emailLabel,
    required this.phoneLabel,
    required this.propertiesLabel,
    required this.messageLabel,
    required this.submitLabel,
    required this.successTitle,
    required this.successBody,
    required this.successClose,
  });

  factory ContactContent.fromJson(J j) => ContactContent(
        title: expandTokens(j.str('title')),
        subtitle: expandTokens(j.str('subtitle')),
        closeLabel: j.str('closeLabel', 'Close'),
        nameLabel: j.str('nameLabel', 'Full name'),
        companyLabel: j.str('companyLabel', 'Company / hotel group'),
        emailLabel: j.str('emailLabel', 'Work email'),
        phoneLabel: j.str('phoneLabel', 'Phone number'),
        propertiesLabel: j.str('propertiesLabel', 'Number of properties'),
        messageLabel: j.str('messageLabel', 'Tell us about your needs'),
        submitLabel: j.str('submitLabel', 'Send request'),
        successTitle: expandTokens(j.str('successTitle')),
        successBody: expandTokens(j.str('successBody')),
        successClose: j.str('successClose', 'Close'),
      );

  final String title;
  final String subtitle;
  final String closeLabel;
  final String nameLabel;
  final String companyLabel;
  final String emailLabel;
  final String phoneLabel;
  final String propertiesLabel;
  final String messageLabel;
  final String submitLabel;
  final String successTitle;
  final String successBody;
  final String successClose;
}
