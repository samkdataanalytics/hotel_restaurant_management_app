import 'package:flutter/material.dart';

import '../studio_theme.dart';

/// A text field that edits a value owned elsewhere.
///
/// The usual trap: a controller created once never sees the value change (undo,
/// reset, a restored revision), and one recreated on every build loses the cursor
/// while typing. This keeps one controller and only overwrites its text when the
/// incoming value is different from what this field itself last reported.
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.suffix,
    this.error,
    this.keyboardType,
    this.dense = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final String? suffix;
  final String? error;
  final TextInputType? keyboardType;
  final bool dense;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  String _lastSent = '';

  @override
  void initState() {
    super.initState();
    _lastSent = widget.value;
  }

  @override
  void didUpdateWidget(SyncedTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _lastSent && widget.value != _c.text) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      _lastSent = widget.value;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.maxLength;
    final near = max != null && _c.text.length > max * 0.8;

    return TextField(
      controller: _c,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      style: SC.body,
      onChanged: (v) {
        _lastSent = v;
        widget.onChanged(v);
        if (max != null) setState(() {});
      },
      decoration: SC.input(hint: widget.hint, suffix: widget.suffix, error: widget.error).copyWith(
            counterText: near ? '${_c.text.length}/$max' : '',
            counterStyle: TextStyle(
              fontSize: 11,
              color: max != null && _c.text.length > max ? SC.danger : SC.faint,
            ),
          ),
    );
  }
}
