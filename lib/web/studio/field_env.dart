import 'package:flutter/widgets.dart';

import '../cms/data/site_repository.dart';
import 'json_path.dart';
import 'studio_state.dart';

/// Everything a field editor needs from the studio, so editors stay free of
/// providers and can be tested on their own.
class FieldEnv {
  const FieldEnv({
    required this.edit,
    this.anchors = const [],
    this.issues = const [],
    this.pickImage,
    this.columnCount = 0,
    this.columnNames = const [],
  });

  /// Sets (or, with null, removes) the value at a path in the document.
  final void Function(JsonPath path, Object? value) edit;

  /// Anchors defined on the current page, for "go to section" links.
  final List<String> anchors;

  /// Current validation issues, shown next to the fields they concern.
  final List<ValidationIssue> issues;

  /// Opens the media library and returns the chosen image, or null.
  final Future<MediaItem?> Function(BuildContext context)? pickImage;

  /// For comparison rows: how many cells each row has.
  final int columnCount;
  final List<String> columnNames;

  List<ValidationIssue> issuesAt(JsonPath path) =>
      issues.where((i) => _same(i.path, path)).toList();

  static bool _same(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  FieldEnv copyWith({int? columnCount, List<String>? columnNames}) => FieldEnv(
        edit: edit,
        anchors: anchors,
        issues: issues,
        pickImage: pickImage,
        columnCount: columnCount ?? this.columnCount,
        columnNames: columnNames ?? this.columnNames,
      );
}
