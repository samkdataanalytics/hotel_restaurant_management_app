/// Non-web fallback: nothing to open. Present so code that links to an external
/// URL still compiles for `flutter test` and for native builds.
void openExternal(String url, {bool newTab = true}) {}
