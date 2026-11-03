import 'dart:typed_data';

/// Largest file the library accepts. The bucket enforces the same 5 MB.
const kMaxImageBytes = 5 * 1024 * 1024;

/// Largest side, in pixels. Beyond this a photo only costs bandwidth: the widest
/// the site ever draws an image is about 1200 px, even on a 2x screen.
const kMaxImagePixels = 4000;

const kImageMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

/// The real type of [bytes], by signature, or null.
///
/// The file name and the picker's reported type are what the user's machine
/// claims; they are not evidence. A renamed `.exe`, or an SVG saved as `.png`
/// (SVG can carry script), must not get through on its extension.
String? sniffImageMime(Uint8List b) {
  if (b.length < 12) return null;
  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
    return 'image/png';
  }
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38 && (b[4] == 0x37 || b[4] == 0x39) && b[5] == 0x61) {
    return 'image/gif';
  }
  if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

class ImageCheck {
  const ImageCheck.ok(this.mime) : problem = null;
  const ImageCheck.rejected(this.problem) : mime = null;

  final String? mime;
  final String? problem;

  bool get ok => problem == null;
}

/// Checks a candidate upload before anything is sent.
ImageCheck checkImage(Uint8List bytes, {int? width, int? height}) {
  if (bytes.isEmpty) return const ImageCheck.rejected('That file is empty.');
  if (bytes.length > kMaxImageBytes) {
    final mb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
    return ImageCheck.rejected('That file is $mb MB. The limit is 5 MB. Compress it first, '
        'for example with squoosh.app.');
  }
  final mime = sniffImageMime(bytes);
  if (mime == null) {
    return const ImageCheck.rejected('Only JPEG, PNG, WebP and GIF images can be uploaded '
        '(SVG is not allowed because it can carry script).');
  }
  if (width != null && height != null && (width > kMaxImagePixels || height > kMaxImagePixels)) {
    return ImageCheck.rejected('That image is ${width}x$height px. The limit is $kMaxImagePixels px '
        'on the longest side; the site never shows an image larger than about 1200 px.');
  }
  return ImageCheck.ok(mime);
}

/// Where [url] appears in [docs] (document key → JSON), so deleting a picture
/// can warn about the pages that would lose it.
List<String> findMediaUsage(String url, Map<String, Object?> docs) {
  final hits = <String>[];
  bool contains(Object? v) => switch (v) {
        String s => s == url,
        Map m => m.values.any(contains),
        List l => l.any(contains),
        _ => false,
      };
  docs.forEach((key, doc) {
    if (contains(doc)) hits.add(key);
  });
  return hits;
}
