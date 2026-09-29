import 'package:flutter/material.dart';

import '../../core/constants/app_images.dart';
import '../../core/strings/app_strings.dart';

/// The Kuzu Help mark and name, sized for an app bar title.
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.appName,
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppImages.mark, height: 36),
          const SizedBox(width: 8),
          Image.asset(AppImages.wordmark, height: 20),
        ],
      ),
    );
  }
}
