import 'package:flutter/material.dart';

/// Large full-width button with a loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3, semanticsLabel: label),
            )
          : Text(label),
    );
  }
}
