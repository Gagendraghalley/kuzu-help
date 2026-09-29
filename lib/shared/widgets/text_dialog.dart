import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/text_utils.dart';

/// Asks for a short text: a reply to a review, a note with a job answer.
/// Returns the trimmed text ('' when optional and left empty), or null if
/// cancelled. With [requiredMessage], empty text isn't accepted.
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String? initialText,
  String? requiredMessage,
  int maxLength = 500,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initialText: initialText,
      requiredMessage: requiredMessage,
      maxLength: maxLength,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;
  final String? initialText;
  final String? requiredMessage;
  final int maxLength;

  const _TextDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initialText,
    required this.requiredMessage,
    required this.maxLength,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initialText);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.orNull;
    if (text == null && widget.requiredMessage != null) {
      setState(() => _error = widget.requiredMessage);
      return;
    }
    Navigator.pop(context, text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint, errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.cancel)),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
