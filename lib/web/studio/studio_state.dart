import 'package:flutter/foundation.dart';

/// Where the document being edited came from.
enum DocSource { draft, published, defaults }

enum SaveStatus {
  /// Nothing to save.
  saved,

  /// Edited, save not yet sent.
  dirty,
  saving,
  error,

  /// Someone else saved this draft since it was loaded. Autosave stops until the
  /// editor reloads, so one editor cannot silently overwrite the other.
  conflict,
}

enum IssueSeverity { error, warning }

/// A problem found in the document. Errors block publishing; warnings do not.
@immutable
class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.message,
    this.sectionId,
    this.path = const [],
  });

  final IssueSeverity severity;
  final String message;

  /// The section it belongs to, so the panel can jump to it.
  final String? sectionId;
  final List<Object> path;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '${severity.name}: $message';
}

@immutable
class StudioState {
  const StudioState({
    this.key = '',
    this.doc = const {},
    this.published = const {},
    this.source = DocSource.defaults,
    this.draftVersion = 0,
    this.publishedVersion = 0,
    this.status = SaveStatus.saved,
    this.loading = true,
    this.error,
    this.selectedId,
    this.canUndo = false,
    this.canRedo = false,
    this.issues = const [],
    this.publishing = false,
  });

  /// `page:home`, `global:theme`, …
  final String key;

  /// The working copy.
  final Map<String, dynamic> doc;

  /// What visitors see now (or the bundled default if nothing was ever published).
  final Map<String, dynamic> published;
  final DocSource source;
  final int draftVersion;
  final int publishedVersion;
  final SaveStatus status;
  final bool loading;
  final String? error;
  final String? selectedId;
  final bool canUndo;
  final bool canRedo;
  final List<ValidationIssue> issues;
  final bool publishing;

  List<ValidationIssue> get errors => issues.where((i) => i.isError).toList();
  List<ValidationIssue> get warnings => issues.where((i) => !i.isError).toList();

  StudioState copyWith({
    String? key,
    Map<String, dynamic>? doc,
    Map<String, dynamic>? published,
    DocSource? source,
    int? draftVersion,
    int? publishedVersion,
    SaveStatus? status,
    bool? loading,
    Object? error = _keep,
    Object? selectedId = _keep,
    bool? canUndo,
    bool? canRedo,
    List<ValidationIssue>? issues,
    bool? publishing,
  }) =>
      StudioState(
        key: key ?? this.key,
        doc: doc ?? this.doc,
        published: published ?? this.published,
        source: source ?? this.source,
        draftVersion: draftVersion ?? this.draftVersion,
        publishedVersion: publishedVersion ?? this.publishedVersion,
        status: status ?? this.status,
        loading: loading ?? this.loading,
        error: identical(error, _keep) ? this.error : error as String?,
        selectedId: identical(selectedId, _keep) ? this.selectedId : selectedId as String?,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
        issues: issues ?? this.issues,
        publishing: publishing ?? this.publishing,
      );

  static const _keep = Object();
}
