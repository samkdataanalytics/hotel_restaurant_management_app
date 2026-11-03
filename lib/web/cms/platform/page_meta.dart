// Sets the browser tab title and the description meta tag.
//
// The site is drawn on a canvas, so this only reaches crawlers that run
// JavaScript; social-card scrapers still see the static index.html. That limit
// is documented, and an edge function would be the fix if it ever matters.
//
// `dart.library.js_interop`, not `dart.library.html`: see open_external.dart.
export 'page_meta_stub.dart' if (dart.library.js_interop) 'page_meta_web.dart';
