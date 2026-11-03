// Warns before the tab is closed or reloaded while there are unsaved edits.
//
// `dart.library.js_interop`, not `dart.library.html`: see open_external.dart.
export 'unload_guard_stub.dart' if (dart.library.js_interop) 'unload_guard_web.dart';
