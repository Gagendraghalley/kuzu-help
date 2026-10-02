import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show AppleLogoPainter;

import '../../../core/strings/app_strings.dart';

/// 'Continue with Apple' (A3, iPhones): black with Apple's logo, the size of
/// GoogleButton, as Apple's Human Interface Guidelines ask (never smaller than
/// another sign-in button). Shows a spinner while [isLoading].
class AppleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppleButton({super.key, required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.6),
        disabledForegroundColor: Colors.white,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: Colors.white,
                semanticsLabel: AppStrings.continueWithApple,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Apple's logo sits a little high in its box; nudged down to line up with the text.
                Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: SizedBox(
                    width: 16, // the logo's 25:31, as in the package's own button
                    height: 20,
                    child: CustomPaint(painter: AppleLogoPainter(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10),
                Flexible(child: Text(AppStrings.continueWithApple, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}
