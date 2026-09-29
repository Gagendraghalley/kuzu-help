import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/theme/app_colors.dart';
import 'dzong_hero.dart';

/// The frame of the log in and password screens (A3–A5): the brand's roof
/// (DzongHero) with a badge, an optional [pill] line, [title] and [subtitle],
/// then [child], the form. The badge shows the logo, or [icon] when given.
/// The top of the roof holds what an app bar would: Back and [actions].
/// Everything scrolls together, so small phones and large text still fit.
class AuthScaffold extends StatelessWidget {
  final IconData? icon;
  final String? pill;
  final String? title;
  final String subtitle;
  final bool showBack;
  final List<Widget> actions;
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.subtitle,
    required this.child,
    this.icon,
    this.pill,
    this.title,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pill = this.pill;
    final title = this.title;
    final canGoBack = showBack && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons on the roof.
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DzongHero(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: SizedBox(
                          height: kToolbarHeight,
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              if (canGoBack) const BackButton(color: Colors.white),
                              const Spacer(),
                              ...actions,
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _Badge(icon: icon),
                            const SizedBox(height: 18),
                            if (pill != null) ...[
                              _Pill(label: pill),
                              const SizedBox(height: 12),
                            ],
                            if (title != null) ...[
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: text.headlineSmall?.copyWith(color: Colors.white, fontSize: 26),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: text.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 24), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo mark, or an icon, on a white tile with a soft halo.
class _Badge extends StatelessWidget {
  final IconData? icon;

  const _Badge({required this.icon});

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: icon == null
            ? Image.asset(AppImages.mark, height: 46, excludeFromSemantics: true)
            : Icon(icon, size: 34, color: AppColors.primaryDeep),
      ),
    );
  }
}

/// A short line in a see-through white pill, e.g. who they're signing up as.
class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
