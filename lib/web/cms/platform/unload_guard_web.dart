import 'dart:js_interop';

import 'package:web/web.dart' as web;

JSFunction? _listener;

/// While [active], the browser asks for confirmation before leaving the page.
void setUnloadGuard(bool active) {
  if (active && _listener == null) {
    final fn = ((web.Event e) {
      e.preventDefault();
      // Some browsers only show the prompt when returnValue is set.
      (e as web.BeforeUnloadEvent).returnValue = '';
    }).toJS;
    _listener = fn;
    web.window.addEventListener('beforeunload', fn);
  } else if (!active && _listener != null) {
    web.window.removeEventListener('beforeunload', _listener);
    _listener = null;
  }
}
