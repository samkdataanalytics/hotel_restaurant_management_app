import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool downloadTextFile(String filename, String content, {String mime = 'text/csv'}) {
  try {
    // The byte-order mark makes Excel read the file as UTF-8, so names with
    // accents or other scripts survive.
    final blob = web.Blob(['﻿$content'.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    web.document.body?.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}
