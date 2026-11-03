// The only place the CMS touches `package:web`. Everything else imports this
// file, so section widgets stay compilable under `flutter test`.
//
// `dart.library.js_interop`, not `dart.library.html`: the latter silently picks
// the stub under a wasm build (the repo's url_strategy import has that bug).
export 'open_external_stub.dart'
    if (dart.library.js_interop) 'open_external_web.dart';
