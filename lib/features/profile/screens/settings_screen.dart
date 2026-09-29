import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/profile_repository.dart';
import '../providers/profile_providers.dart';

/// D1 Settings
/// Purpose: Account management for everyone; admins also reach their tools here.
/// Backend: Updates profiles. Users can't delete their own account: admins
/// deactivate accounts instead (Users).
/// Done when: Logout returns to Welcome.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  /// Runs [action] once, showing any error. The router moves on by itself
  /// after logging out.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logOut() async {
    final ok = await confirm(context, title: AppStrings.logoutConfirm, confirmLabel: AppStrings.logout);
    if (ok) await _run(() => ref.read(authActionsProvider).signOut());
  }

  Future<void> _becomeWorker() async {
    final ok = await confirm(
      context,
      title: AppStrings.becomeWorker,
      message: AppStrings.becomeWorkerMessage,
      confirmLabel: AppStrings.continueLabel,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(profileRepositoryProvider).becomeWorker();
      ref.invalidate(myProfileProvider);
      // The splash (A1) sends workers to profile setup (B1).
      if (mounted) context.go(Routes.splash);
    });
  }

  Future<void> _stopOfferingServices() async {
    if (!await confirmStopOfferingServices(context)) return;
    await _run(() async {
      await ref.read(profileRepositoryProvider).becomeCustomer();
      ref.invalidate(myProfileProvider);
      // The splash (A1) sends customers to Customer Home (C1).
      if (mounted) context.go(Routes.splash);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: SafeArea(
        child: AsyncView(
          value: profile,
          onRetry: () => ref.invalidate(myProfileProvider),
          data: (profile) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (profile != null) ...[
                _ProfileHeader(profile: profile),
                const SizedBox(height: 28),
              ],
              if (profile?.role == UserRole.admin) ...[
                Card(
                  child: Column(
                    children: [
                      _Item(
                        icon: Icons.how_to_reg_outlined,
                        label: AppStrings.workersAwaitingApproval,
                        onTap: () => context.push(Routes.pendingWorkers),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      _Item(
                        icon: Icons.manage_accounts_outlined,
                        label: AppStrings.users,
                        onTap: () => context.push(Routes.users),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
              const SectionHeader(AppStrings.account),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _Item(
                      icon: Icons.person_outline,
                      label: AppStrings.editProfile,
                      // Workers edit everything customers see on B1.
                      onTap: () => context.push(
                        profile?.role == UserRole.worker ? Routes.workerSetup : Routes.editProfile,
                      ),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    _Item(
                      icon: Icons.lock_outline,
                      label: AppStrings.changePassword,
                      onTap: () => context.push(Routes.setPassword),
                    ),
                    // Customers and workers can switch; admins can't.
                    if (profile?.role == UserRole.worker) ...[
                      const Divider(indent: 16, endIndent: 16),
                      _Item(
                        icon: Icons.handyman_outlined,
                        label: AppStrings.myServices,
                        onTap: () => context.push(Routes.workerServices),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      _Item(
                        icon: Icons.search,
                        label: AppStrings.stopOfferingServices,
                        hint: AppStrings.stopOfferingServicesHint,
                        onTap: _busy ? null : _stopOfferingServices,
                      ),
                    ],
                    if (profile?.role == UserRole.customer) ...[
                      const Divider(indent: 16, endIndent: 16),
                      _Item(
                        icon: Icons.storefront_outlined,
                        label: AppStrings.becomeWorker,
                        hint: AppStrings.becomeWorkerHint,
                        onTap: _busy ? null : _becomeWorker,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: _Item(
                  icon: Icons.logout,
                  label: AppStrings.logout,
                  onTap: _busy ? null : _logOut,
                  showChevron: false,
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Profile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = profile.email;

    return Row(
      children: [
        AvatarImage(url: profile.avatarUrl, name: profile.fullName, size: 72),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.fullName, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              if (email != null)
                Text(email, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  AppStrings.roleLabel(profile.role),
                  style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  final bool showChevron;

  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: hint == null ? null : Text(hint),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
