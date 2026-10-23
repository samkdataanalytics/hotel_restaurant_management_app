// Small string store used to remember the last published content between
// visits. `localStorage` on the web, a map elsewhere (tests, native).
//
// `dart.library.js_interop`, not `dart.library.html`: see open_external.dart.
export 'kv_store_stub.dart' if (dart.library.js_interop) 'kv_store_web.dart';
