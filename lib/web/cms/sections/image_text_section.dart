import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import '../render/link_action.dart';
import 'cta_band_section.dart' show CtaButtonContent;
import 'rich_text_section.dart';

/// Only images from the site's own media library are drawn. The editor offers
/// nothing else, and this stops a hand-edited document pointing at an arbitrary
/// URL (a tracking pixel, or something that is not an image at all).
bool isLibraryImageUrl(String url) {
  final u = Uri.tryParse(url);
  return u != null &&
      u.scheme == 'https' &&
      u.path.contains('/storage/v1/object/public/site-media/');
}

class ImageRef {
  const ImageRef({required this.url, required this.alt});

  factory ImageRef.fromJson(J j) => ImageRef(url: j.str('url'), alt: j.str('alt'));

  final String url;

  /// Read by screen readers; empty marks the image decorative.
  final String alt;

  bool get usable => isLibraryImageUrl(url);
}

class ImageTextContent {
  const ImageTextContent({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.image,
    required this.imageLeft,
    required this.cta,
  });

  factory ImageTextContent.fromJson(J j) => ImageTextContent(
        eyebrow: j.str('eyebrow'),
        title: j.str('title'),
        body: j.str('body'),
        image: ImageRef.fromJson(j.obj('image')),
        imageLeft: j.str('imageSide') == 'left',
        cta: CtaButtonContent.fromJson(j.obj('cta')),
      );

  final String eyebrow;
  final String title;
  final String body;
  final ImageRef image;
  final bool imageLeft;
  final CtaButtonContent cta;
}

final imageTextDefinition = SectionDefinition(
  type: 'imageText',
  label: 'Image and text',
  builder: (context, SectionNode node) =>
      ImageTextSection(content: ImageTextContent.fromJson(node.content)),
);

class ImageTextSection extends StatelessWidget {
  const ImageTextSection({super.key, required this.content});

  final ImageTextContent content;

  @override
  Widget build(BuildContext context) {
    final stacked = LK.isMobile(context) || LK.isTablet(context);

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.eyebrow.isNotEmpty) ...[
          Eyebrow(content.eyebrow),
          const SizedBox(height: 18),
        ],
        if (content.title.isNotEmpty) ...[
          Text(content.title, style: LK.h2(context)),
          const SizedBox(height: 18),
        ],
        RichBody(source: content.body),
        if (content.cta.label.isNotEmpty && !content.cta.link.isNone) ...[
          const SizedBox(height: 10),
          CtaButton(
            label: content.cta.label,
            icon: Icons.arrow_forward_rounded,
            onTap: () => runLink(context, content.cta.link),
          ),
        ],
      ],
    );

    final picture = _Picture(image: content.image);

    return Shell(
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [picture, const SizedBox(height: 32), copy],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (content.imageLeft) ...[
                  Expanded(child: picture),
                  const SizedBox(width: 64),
                  Expanded(child: copy),
                ] else ...[
                  Expanded(child: copy),
                  const SizedBox(width: 64),
                  Expanded(child: picture),
                ],
              ],
            ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.image});

  final ImageRef image;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: LK.surface,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: LK.muted, size: 36),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: image.usable
            ? Semantics(
                image: true,
                label: image.alt.isEmpty ? null : image.alt,
                excludeSemantics: image.alt.isEmpty,
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  // A slow or missing image shows the placeholder, never a gap
                  // or a thrown error in the middle of the page.
                  errorBuilder: (_, __, ___) => placeholder,
                  loadingBuilder: (_, child, p) => p == null ? child : placeholder,
                ),
              )
            : placeholder,
      ),
    );
  }
}
