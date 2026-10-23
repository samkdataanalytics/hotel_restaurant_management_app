// Saves text as a file through the browser's download mechanism.
//
// `dart.library.js_interop`, not `dart.library.html`: see open_external.dart.
export 'download_file_stub.dart' if (dart.library.js_interop) 'download_file_web.dart';
