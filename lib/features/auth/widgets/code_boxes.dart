import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six boxes for the one-time code (A4). A hidden text field on top does the
/// typing, so pasting and the keyboard's code autofill work.
class CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final String semanticLabel;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  const CodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.semanticLabel,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final digitStyle = Theme.of(context).textTheme.headlineSmall;

    return Stack(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Row(
            children: [
              for (var i = 0; i < length; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 62,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == value.text.length && !hasError ? const Color(0xFFFFF8F1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        width: i == value.text.length || hasError ? 2 : 1.2,
                        color: hasError
                            ? colors.error
                            : i == value.text.length
                                ? colors.primary
                                : i < value.text.length
                                    ? colors.outline
                                    : colors.outlineVariant,
                      ),
                    ),
                    child: Text(i < value.text.length ? value.text[i] : '', style: digitStyle),
                  ),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            alwaysIncludeSemantics: true, // screen readers still find the field
            child: Semantics(
              label: semanticLabel,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                showCursor: false,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                onChanged: (code) {
                  onChanged?.call(code);
                  if (code.length == length) onCompleted(code);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
