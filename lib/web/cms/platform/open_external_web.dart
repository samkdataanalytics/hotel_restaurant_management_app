import 'package:web/web.dart' as web;

/// Opens [url] in a new tab, or in the current one.
///
/// `noopener,noreferrer` on the new-tab path: the destination is an arbitrary
/// URL an admin typed, so it must not get a handle back to this window.
void openExternal(String url, {bool newTab = true}) {
  if (newTab) {
    web.window.open(url, '_blank', 'noopener,noreferrer');
  } else {
    web.window.location.href = url;
  }
}
