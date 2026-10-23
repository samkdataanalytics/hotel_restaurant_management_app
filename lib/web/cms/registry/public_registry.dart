import '../sections/before_after_section.dart';
import '../sections/comparison_section.dart';
import '../sections/cta_band_section.dart';
import '../sections/faq_section.dart';
import '../sections/feature_grid_section.dart';
import '../sections/hero_section.dart';
import '../sections/image_text_section.dart';
import '../sections/pricing_section.dart';
import '../sections/rich_text_section.dart';
import '../sections/spacer_section.dart';
import '../sections/stats_section.dart';
import '../sections/steps_section.dart';
import '../sections/testimonials_section.dart';
import 'section_registry.dart';

/// Every section type a page can contain. The public site and the studio's
/// preview both render through this, so what the editor shows is what
/// visitors get. Adding a type means adding it here, giving it a field spec in
/// the studio, and a default in `defaults/`.
final SectionRegistry publicRegistry = SectionRegistry.of([
  heroDefinition,
  statsDefinition,
  beforeAfterDefinition,
  stepsDefinition,
  featureGridDefinition,
  comparisonDefinition,
  testimonialsDefinition,
  pricingDefinition,
  faqDefinition,
  ctaBandDefinition,
  richTextDefinition,
  imageTextDefinition,
  spacerDefinition,
]);
