import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/text_utils.dart';

/// Asks the admin for a note to show the user (rejecting, deactivating).
/// Returns the note ('' when optional and left empty), or null if cancelled.
Future<String?> showNoteDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String? requiredMessage,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      requiredMessage: requiredMessage,
    ),
  );
}

class _NoteDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final String? requiredMessage; // shown when the note is required but empty

  const _NoteDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.requiredMessage,
  });

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.orNull;
    if (note == null && widget.requiredMessage != null) {
      setState(() => _error = widget.requiredMessage);
      return;
    }
    Navigator.pop(context, note ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _note,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint, errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.cancel)),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
