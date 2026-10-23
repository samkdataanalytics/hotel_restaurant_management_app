import '../model/site_document.dart';
import 'chrome_defaults.dart';
import 'home_defaults.dart';

/// Every document the CMS manages, as it shipped before the CMS: what the site
/// renders when nothing has been published, and what "Start from the live site"
/// loads into a new draft.
///
/// Keys match `site_documents.key`. Add a page here and in `kEditablePages`.
final Map<String, Map<String, Object?>> kSiteDefaults = {
  'page:home': kHomeDefaults,
  'global:header': kHeaderDefaults,
  'global:footer': kFooterDefaults,
  'global:theme': kThemeDefaults,
};

/// Deep copy, so a caller mutating the result (the editor does) cannot change
/// the bundled constant for everyone else.
Map<String, dynamic> siteDefaultJson(String key) => _clone(kSiteDefaults[key] ?? const {});

SiteDocument siteDefaultDocument(String key) => SiteDocument.fromJson(kSiteDefaults[key]);

Map<String, dynamic> _clone(Map<Object?, Object?> m) => {
      for (final e in m.entries) e.key as String: _cloneValue(e.value),
    };

Object? _cloneValue(Object? v) => switch (v) {
      Map() => _clone(v),
      List() => [for (final x in v) _cloneValue(x)],
      _ => v,
    };
