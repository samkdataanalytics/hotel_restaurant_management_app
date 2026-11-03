import 'package:flutter/widgets.dart';

import '../model/json_reader.dart';
import '../model/responsive.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';

class SpacerContent {
  const SpacerContent({required this.height});

  factory SpacerContent.fromJson(J j) => SpacerContent(
        height: Responsive.number(j.obj('height'), min: 0, max: 400) ?? const Responsive<double>(48),
      );

  final Responsive<double> height;
}

final spacerDefinition = SectionDefinition(
  type: 'spacer',
  label: 'Spacer',
  builder: (context, SectionNode node) =>
      SpacerSection(content: SpacerContent.fromJson(node.content)),
);

/// Empty vertical space, sized per device.
class SpacerSection extends StatelessWidget {
  const SpacerSection({super.key, required this.content});

  final SpacerContent content;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final device = w < 768 ? Device.mobile : (w < 1100 ? Device.tablet : Device.desktop);
    return SizedBox(height: content.height.resolve(device));
  }
}
