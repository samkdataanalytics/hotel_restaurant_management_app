import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Resizes image bytes using the browser canvas, so no extra package is needed.
///
/// Moved out of `invoice_service.dart` behind a conditional import: it was the
/// only web-only code in that file, and it alone prevented the invoice service
/// from compiling for native at all.
Future<Uint8List> resizeForPdf(
  Uint8List bytes, {
  int maxDimension = 160,
  double quality = 0.80,
}) async {
  final completer = Completer<Uint8List>();
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final img = web.HTMLImageElement()..src = url;

  web.EventListener? onLoad;
  web.EventListener? onError;

  onLoad = (web.Event _) {
    final w = img.naturalWidth > 0 ? img.naturalWidth : maxDimension;
    final h = img.naturalHeight > 0 ? img.naturalHeight : maxDimension;
    int outW, outH;
    if (w >= h) {
      outW = w > maxDimension ? maxDimension : w;
      outH = (outW * h / w).round();
    } else {
      outH = h > maxDimension ? maxDimension : h;
      outW = (outH * w / h).round();
    }
    final canvas = web.HTMLCanvasElement()
      ..width = outW
      ..height = outH;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0);
    web.URL.revokeObjectURL(url);
    final dataUrl = canvas.toDataURL('image/jpeg', quality.toJS);
    final base64Str = dataUrl.split(',').last;
    img.removeEventListener('load', onLoad);
    img.removeEventListener('error', onError);
    completer.complete(base64Decode(base64Str));
  }.toJS;

  onError = (web.Event _) {
    web.URL.revokeObjectURL(url);
    img.removeEventListener('load', onLoad);
    img.removeEventListener('error', onError);
    completer.complete(bytes);
  }.toJS;

  img.addEventListener('load', onLoad);
  img.addEventListener('error', onError);

  return completer.future;
}
