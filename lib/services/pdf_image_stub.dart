import 'dart:typed_data';

/// Native fallback for [resizeForPdf].
///
/// Returns the bytes untouched. Downscaling is a speed optimisation for
/// `pdf.save()`, not a correctness requirement, and the web implementation
/// already returns the original bytes whenever the canvas path fails — so
/// skipping it here produces a valid, if slightly larger, PDF.
///
/// Doing it properly on native would mean adding an image package; that is
/// worth it only if logo size actually shows up as a problem in practice.
Future<Uint8List> resizeForPdf(
  Uint8List bytes, {
  int maxDimension = 160,
  double quality = 0.80,
}) async =>
    bytes;
