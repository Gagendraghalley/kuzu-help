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
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../customer/providers/search_providers.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';
import '../widgets/note_dialog.dart';

/// Admin: every user, searchable by name or email. Tap one to deactivate
/// (blacklist) or reactivate them, or to open a worker's page.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.users)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: AppStrings.searchUsers,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: AppStrings.cancel,
                    onPressed: () {
                      _search.clear();
                      ref.read(userSearchProvider.notifier).state = '';
                    },
                  ),
                ),
                onSubmitted: (text) => ref.read(userSearchProvider.notifier).state = text,
              ),
            ),
            Expanded(
              child: AsyncView(
                value: users,
                onRetry: () => ref.invalidate(usersProvider),
                data: (users) => users.isEmpty
                    ? const EmptyState(icon: Icons.person_search_outlined, message: AppStrings.noUsersFound)
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(usersProvider.future),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _UserTile(user: users[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Profile user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final email = user.email;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AvatarImage(url: user.avatarUrl, name: user.fullName, size: 48),
        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null) Text(email),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _RoleTag(role: user.role),
                if (!user.isActive) const DeactivatedBadge(),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.more_vert),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _UserActions(user: user),
        ),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  final String role;

  const _RoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(20)),
      child: Text(
        AppStrings.roleLabel(role),
        style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

/// What an admin can do with one user.
class _UserActions extends ConsumerStatefulWidget {
  final Profile user;

  const _UserActions({required this.user});

  @override
  ConsumerState<_UserActions> createState() => _UserActionsState();
}

class _UserActionsState extends ConsumerState<_UserActions> {
  bool _saving = false;

  Future<void> _setActive(bool active) async {
    final user = widget.user;
    String? reason;
    if (!active) {
      reason = await showNoteDialog(
        context,
        title: AppStrings.deactivateTitle,
        hint: AppStrings.deactivateHint,
        confirmLabel: AppStrings.deactivate,
      );
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(adminRepositoryProvider).setUserActive(user.id, active: active, reason: reason);
      ref.invalidate(usersProvider);
      ref.invalidate(workerDetailsProvider(user.id));
      ref.invalidate(workerSearchProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(active
            ? AppStrings.userReactivated(user.fullName)
            : AppStrings.userDeactivated(user.fullName)),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final reason = user.deactivatedReason?.trim() ?? '';
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AvatarImage(url: user.avatarUrl, name: user.fullName, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      if (user.email case final email?) Text(email),
                    ],
                  ),
                ),
              ],
            ),
            if (!user.isActive && reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              InfoNote(icon: Icons.block, iconColor: AppColors.error, text: reason),
            ],
            const SizedBox(height: 16),
            if (user.role == UserRole.worker)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.handyman_outlined, color: Theme.of(context).colorScheme.primary),
                title: const Text(AppStrings.openWorkerPage),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  context.push(Routes.workerDetailsFor(user.id));
                },
              ),
            const SizedBox(height: 8),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else if (user.role == UserRole.admin)
              const Text(AppStrings.adminsCantBeDeactivated, textAlign: TextAlign.center)
            else if (user.isActive)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                icon: const Icon(Icons.block),
                label: const Text(AppStrings.deactivateAccount),
                onPressed: () => _setActive(false),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.verified),
                icon: const Icon(Icons.lock_open),
                label: const Text(AppStrings.reactivateAccount),
                onPressed: () => _setActive(true),
              ),
          ],
        ),
      ),
    );
  }
}
