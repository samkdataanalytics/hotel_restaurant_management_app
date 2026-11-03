import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the bundled fonts for widget tests.
///
/// `flutter test` otherwise draws every glyph in the Ahem test font, which is
/// as wide as it is tall. Text then wraps far earlier than in a browser, and
/// fixed-height sections like the hero report overflows that never happen on
/// the real page. Loading the real files makes layout assertions mean something.
Future<void> loadBrandFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await File('assets/fonts/$f').readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Outfit', [
    'Outfit-Regular.ttf',
    'Outfit-Medium.ttf',
    'Outfit-SemiBold.ttf',
    'Outfit-Bold.ttf',
    'Outfit-ExtraBold.ttf',
  ]);
  await load('Inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
    'Inter-ExtraBold.ttf',
  ]);
  await load('DMSerifDisplay', ['DMSerifDisplay-Regular.ttf']);
}
