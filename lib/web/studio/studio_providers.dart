import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cms/data/site_content_store.dart';
import '../cms/data/site_providers.dart';
import '../cms/defaults/site_defaults.dart';
import '../cms/model/site_document.dart';
import 'studio_controller.dart';
import 'studio_pages.dart';
import 'studio_state.dart';
import 'studio_validation.dart';

/// The editor session. Deliberately not auto-disposed: the superadmin shell
/// rebuilds a tab's screen when the admin switches away and back, and the working
/// copy, undo history and selection should survive that.
final studioControllerProvider = StateNotifierProvider<StudioController, StudioState>((ref) {
  return StudioController(
    repository: ref.watch(siteRepositoryProvider),
    defaults: siteDefaultJson,
    validator: validateSiteDocument,
    onPublished: () {
      // The admin's own browser should show the new content on the very next
      // load, not the copy cached before they published.
      SiteContentStore.instance.clearCache();
      SiteContentStore.instance.refresh();
    },
  );
});

/// Which part of the studio is showing, and how.
class StudioUi {
  const StudioUi({
    this.workspace = StudioWorkspace.pages,
    this.device = Device.desktop,
    this.pageKey = 'page:home',
    this.navDoc = 'global:header',
    this.panelTab = PanelTab.content,
    this.leftOpen = false,
    this.rightOpen = false,
  });

  final StudioWorkspace workspace;
  final Device device;
  final String pageKey;

  /// `global:header` or `global:footer`.
  final String navDoc;
  final PanelTab panelTab;

  /// Slide-over panels on narrow windows (a tablet): the section list and the
  /// property panel cover the preview instead of squeezing it.
  final bool leftOpen;
  final bool rightOpen;

  StudioUi copyWith({
    StudioWorkspace? workspace,
    Device? device,
    String? pageKey,
    String? navDoc,
    PanelTab? panelTab,
    bool? leftOpen,
    bool? rightOpen,
  }) =>
      StudioUi(
        workspace: workspace ?? this.workspace,
        device: device ?? this.device,
        pageKey: pageKey ?? this.pageKey,
        navDoc: navDoc ?? this.navDoc,
        panelTab: panelTab ?? this.panelTab,
        leftOpen: leftOpen ?? this.leftOpen,
        rightOpen: rightOpen ?? this.rightOpen,
      );

  /// The document the current workspace edits, or null for the media library.
  String? get docKey => switch (workspace) {
        StudioWorkspace.pages => pageKey,
        StudioWorkspace.navigation => navDoc,
        StudioWorkspace.theme => 'global:theme',
        StudioWorkspace.media => null,
      };
}

enum PanelTab { content, layout, style, typography, visibility }

/// The id the property panel uses for "the page itself" rather than a section.
const kPageSettingsId = '__page__';

class StudioUiNotifier extends StateNotifier<StudioUi> {
  StudioUiNotifier() : super(const StudioUi());

  void update(StudioUi Function(StudioUi) f) => state = f(state);
}

final studioUiProvider =
    StateNotifierProvider<StudioUiNotifier, StudioUi>((_) => StudioUiNotifier());
