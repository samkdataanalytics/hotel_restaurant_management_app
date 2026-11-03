import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import 'section_head_content.dart';

class Testimonial {
  const Testimonial({
    required this.quote,
    required this.name,
    required this.role,
    required this.place,
    required this.initials,
  });

  factory Testimonial.fromJson(J j) {
    final name = j.str('name');
    return Testimonial(
      quote: j.str('quote'),
      name: name,
      role: j.str('role'),
      place: j.str('place'),
      // Derived from the name unless set, so adding a quote needs no extra field.
      initials: j.strOrNull('initials') ?? _initialsOf(name),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = String.fromCharCode(parts.first.runes.first);
    if (parts.length == 1) return first.toUpperCase();
    return (first + String.fromCharCode(parts.last.runes.first)).toUpperCase();
  }

  final String quote;
  final String name;
  final String role;
  final String place;
  final String initials;
}

class TestimonialsContent {
  const TestimonialsContent({required this.head, required this.items});

  factory TestimonialsContent.fromJson(J j) => TestimonialsContent(
        head: HeadContent.fromJson(j),
        items: j.list('items', Testimonial.fromJson).where((t) => t.quote.isNotEmpty).toList(),
      );

  final HeadContent head;
  final List<Testimonial> items;
}

final testimonialsDefinition = SectionDefinition(
  type: 'testimonials',
  label: 'Testimonials',
  builder: (context, SectionNode node) =>
      TestimonialsSection(content: TestimonialsContent.fromJson(node.content)),
);

class TestimonialsSection extends StatelessWidget {
  const TestimonialsSection({super.key, required this.content});

  final TestimonialsContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final tablet = LK.isTablet(context);
    final cols = mobile ? 1 : (tablet ? 2 : 3);

    return Shell(
      child: Column(
        children: [
          SectionHead(
            eyebrow: content.head.eyebrow,
            title: content.head.title,
            lead: content.head.lead,
          ),
          SizedBox(height: mobile ? 36 : 56),
          LayoutBuilder(builder: (_, c) {
            const gap = 18.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in content.items)
                  SizedBox(width: w, child: _TestimonialCard(item: t)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final Testimonial item;
  const _TestimonialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final byline = [item.role, item.place].where((p) => p.isNotEmpty).join(' · ');

    return Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.star_rounded, size: 16, color: LK.amber),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.quote,
            style: LK.small.copyWith(color: LK.ink, fontSize: 15, height: 1.65),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: LK.line),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LK.navy,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  item.initials,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: LK.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (byline.isNotEmpty)
                      Text(byline, style: LK.micro.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
