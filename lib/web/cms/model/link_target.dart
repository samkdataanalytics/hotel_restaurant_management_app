import 'json_reader.dart';

enum LinkKind { none, internal, external, anchor, action }

/// Where a button or link goes.
///
/// A typed target rather than a free URL string, because an admin types these
/// and every visitor clicks them. Anything that fails validation becomes
/// [LinkKind.none] — an inert link — instead of a clickable surprise. There is
/// no `javascript:` or `data:` path: only the shapes below can be expressed.
class LinkTarget {
  const LinkTarget(this.kind, [this.value = '', this.newTab = false]);

  static const none = LinkTarget(LinkKind.none);

  /// Routes the public site actually serves. A link to anywhere else inside
  /// the app would land on the 404 screen, so it is rejected up front.
  static const allowedRoutes = {
    '/',
    '/signup',
    '/login',
    '/help',
    '/terms',
    '/privacy',
    '/returns',
  };

  /// Actions are code, not data: the admin picks one, they cannot define one.
  static const allowedActions = {'signup', 'login', 'openDemo', 'openContactSales'};

  static final _anchor = RegExp(r'^[a-z0-9][a-z0-9-]{0,39}$');
  static final _query = RegExp(r'^[A-Za-z0-9_=&-]*$');
  static final _mailto = RegExp(r'^mailto:[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$');
  static final _tel = RegExp(r'^tel:\+?[0-9 ()-]{5,24}$');

  final LinkKind kind;
  final String value;
  final bool newTab;

  /// Tolerant: invalid input yields [none], never an exception.
  factory LinkTarget.fromJson(J j) {
    final value = j.str('value').trim();
    final newTab = j.flag('newTab');
    switch (j.str('type')) {
      case 'internal':
        return isAllowedInternal(value) ? LinkTarget(LinkKind.internal, value) : none;
      case 'external':
        return isAllowedExternal(value) ? LinkTarget(LinkKind.external, value, newTab) : none;
      case 'anchor':
        return isValidAnchor(value) ? LinkTarget(LinkKind.anchor, value) : none;
      case 'action':
        return allowedActions.contains(value) ? LinkTarget(LinkKind.action, value) : none;
      default:
        return none;
    }
  }

  static bool isAllowedInternal(String v) {
    if (v.isEmpty || !v.startsWith('/') || v.startsWith('//')) return false;
    if (v.contains(RegExp(r'[\s\\]'))) return false;
    final hash = v.indexOf('#');
    final noHash = hash == -1 ? v : v.substring(0, hash);
    final q = noHash.indexOf('?');
    final path = q == -1 ? noHash : noHash.substring(0, q);
    final query = q == -1 ? '' : noHash.substring(q + 1);
    return allowedRoutes.contains(path) && _query.hasMatch(query);
  }

  static bool isAllowedExternal(String v) {
    // tel: is judged by its own pattern first, because it legitimately contains
    // spaces ("+94 11 234 5678"). A blanket whitespace check ahead of it made
    // every spaced number unacceptable.
    if (v.startsWith('tel:')) return _tel.hasMatch(v);
    if (v.contains(RegExp(r'\s'))) return false;
    if (v.startsWith('mailto:')) return _mailto.hasMatch(v);
    // https only. http would let a link downgrade a visitor off TLS, and every
    // site worth linking to serves https.
    final uri = Uri.tryParse(v);
    return uri != null && uri.scheme == 'https' && uri.host.contains('.');
  }

  static bool isValidAnchor(String v) => _anchor.hasMatch(v);

  bool get isNone => kind == LinkKind.none;

  @override
  bool operator ==(Object other) =>
      other is LinkTarget &&
      other.kind == kind &&
      other.value == value &&
      other.newTab == newTab;

  @override
  int get hashCode => Object.hash(kind, value, newTab);

  @override
  String toString() => 'LinkTarget(${kind.name}, $value${newTab ? ', newTab' : ''})';
}
