import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../cms/data/site_repository.dart';
import '../studio_theme.dart';
import '../widgets/synced_field.dart';
import 'media_rules.dart';

/// A file chosen by the user, before it is checked or uploaded.
class PickedFile {
  const PickedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

typedef FilePickFn = Future<PickedFile?> Function();

Future<PickedFile?> pickImageFile() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
  final f = result?.files.firstOrNull;
  if (f == null || f.bytes == null) return null;
  return PickedFile(f.name, f.bytes!);
}

Future<({int width, int height})?> decodeSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (width: frame.image.width, height: frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    return null;
  }
}

/// The picture library: upload, browse, describe and delete.
///
/// Used in two places: as the Media workspace, and in a dialog when a field asks
/// for an image ([onPick] set), where tapping a picture chooses it.
class MediaLibrary extends StatefulWidget {
  const MediaLibrary({
    super.key,
    required this.repository,
    this.onPick,
    this.pickFile = pickImageFile,
    this.usageOf,
  });

  final SiteRepository repository;

  /// Picker mode: called with the chosen item.
  final ValueChanged<MediaItem>? onPick;

  /// Injectable so tests need no file dialog.
  final FilePickFn pickFile;

  /// Which pages use a URL, for the delete warning. Null skips the check.
  final List<String> Function(String url)? usageOf;

  @override
  State<MediaLibrary> createState() => _MediaLibraryState();
}

class _MediaLibraryState extends State<MediaLibrary> {
  List<MediaItem> _items = const [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.listMedia();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the library: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final file = await widget.pickFile();
    if (file == null || !mounted) return;

    final size = await decodeSize(file.bytes);
    final check = checkImage(file.bytes, width: size?.width, height: size?.height);
    if (!check.ok) {
      setState(() => _error = check.problem);
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final item = await widget.repository.uploadMedia(
        bytes: file.bytes,
        mime: check.mime!,
        originalName: file.name,
        width: size?.width,
        height: size?.height,
        // A sensible starting alt: the file name without its extension. The admin
        // is expected to improve it; an empty alt is flagged at publish time.
        alt: _altFrom(file.name),
      );
      if (!mounted) return;
      setState(() {
        _items = [item, ..._items.where((m) => m.id != item.id)];
        _selectedId = item.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _altFrom(String name) {
    final base = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }

  Future<void> _delete(MediaItem m) async {
    final used = widget.usageOf?.call(m.url) ?? const [];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this picture?'),
        content: Text(used.isEmpty
            ? 'It will be removed from the library and from storage.'
            : 'It is used on: ${used.join(', ')}. Those pages will show a placeholder until you '
                'choose another picture.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SC.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.deleteMedia(m.id);
      if (mounted) setState(() => _items = _items.where((x) => x.id != m.id).toList());
    } catch (e) {
      if (mounted) setState(() => _error = 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final picking = widget.onPick != null;
    final selected = _items.where((m) => m.id == _selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(picking ? 'Choose a picture' : 'Media library', style: SC.title),
              const SizedBox(width: 10),
              Chip2('${_items.length}', color: SC.muted),
              const Spacer(),
              FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                style: FilledButton.styleFrom(backgroundColor: SC.accent),
                icon: _uploading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(_uploading ? 'Uploading…' : 'Upload'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'JPEG, PNG, WebP or GIF, up to 5 MB and 4000 px. Pictures are served exactly as uploaded, '
            'so compress large photos first. No SVG.',
            style: SC.small,
          ),
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SC.dangerBg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: SC.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: SC.small.copyWith(color: SC.text))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _error = null),
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _items.isEmpty
                  ? const Center(child: Text('No pictures yet. Upload one to get started.', style: SC.small))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return _Tile(
                          item: m,
                          selected: m.id == _selectedId,
                          onTap: () {
                            setState(() => _selectedId = m.id);
                            if (picking && m.id == _selectedId) {
                              // Single tap selects; the Choose button confirms.
                            }
                          },
                          onDoubleTap: picking ? () => widget.onPick!(m) : null,
                        );
                      },
                    ),
        ),
        if (selected != null)
          _Details(
            item: selected,
            onAlt: (alt) async {
              try {
                await widget.repository.setMediaAlt(selected.id, alt);
                if (mounted) {
                  setState(() => _items = [for (final m in _items) m.id == selected.id ? m.copyWith(alt: alt) : m]);
                }
              } catch (_) {}
            },
            onDelete: () => _delete(selected),
            onChoose: picking ? () => widget.onPick!(selected) : null,
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.selected, required this.onTap, this.onDoubleTap});

  final MediaItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? SC.accent : SC.border, width: selected ? 2.5 : 1),
          color: const Color(0xFFF1F5F9),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: SC.faint)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  item.alt.isEmpty ? 'No alt text' : item.alt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: item.alt.isEmpty ? const Color(0xFFFFD58A) : Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.item, required this.onAlt, required this.onDelete, this.onChoose});

  final MediaItem item;
  final ValueChanged<String> onAlt;
  final VoidCallback onDelete;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final dims = item.width != null && item.height != null ? '${item.width}×${item.height} px · ' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: SC.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dims${(item.bytes / 1024).round()} KB · ${item.mime.replaceFirst('image/', '').toUpperCase()}', style: SC.small),
                const SizedBox(height: 6),
                const Text('Alt text', style: SC.label),
                const SizedBox(height: 4),
                SyncedTextField(
                  key: ValueKey(item.id),
                  value: item.alt,
                  hint: 'Describe the picture for screen readers',
                  maxLength: 160,
                  onChanged: onAlt,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: SC.danger),
          ),
          if (onChoose != null)
            FilledButton(
              onPressed: onChoose,
              style: FilledButton.styleFrom(backgroundColor: SC.accent),
              child: const Text('Choose'),
            ),
        ],
      ),
    );
  }
}

/// Opens the library as a dialog and returns the chosen picture.
Future<MediaItem?> showMediaPicker(BuildContext context, SiteRepository repo,
    {List<String> Function(String url)? usageOf, FilePickFn pickFile = pickImageFile}) {
  return showDialog<MediaItem>(
    context: context,
    builder: (c) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 760,
        height: 620,
        child: MediaLibrary(
          repository: repo,
          usageOf: usageOf,
          pickFile: pickFile,
          onPick: (m) => Navigator.pop(c, m),
        ),
      ),
    ),
  );
}
