import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/profile.dart';

/// Lets the admin tick the roles [user] has: Customer, Player and Worker
/// (UserRole.editable). A ground manager's role shows, locked: it comes with
/// a venue. Returns every role they should have, or null if cancelled or
/// unchanged.
Future<Set<String>?> showRolesDialog(BuildContext context, Profile user) =>
    showDialog<Set<String>>(context: context, builder: (_) => _RolesDialog(user: user));

class _RolesDialog extends StatefulWidget {
  final Profile user;

  const _RolesDialog({required this.user});

  @override
  State<_RolesDialog> createState() => _RolesDialogState();
}

class _RolesDialogState extends State<_RolesDialog> {
  late final Set<String> _before = widget.user.allRoles.toSet();
  late final Set<String> _roles = {..._before};

  bool get _isManager => _roles.contains(UserRole.groundManager);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final changed = _roles.length != _before.length || !_roles.containsAll(_before);

    return AlertDialog(
      title: Text(AppStrings.rolesTitle(widget.user.fullName)),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final role in UserRole.editable)
              CheckboxListTile(
                value: _roles.contains(role),
                title: Text(AppStrings.roleLabel(role), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(role == UserRole.worker && _isManager
                    ? AppStrings.workerNotWithManager
                    : AppStrings.roleHint(role)),
                // The database allows a ground manager only customer and player besides.
                onChanged: role == UserRole.worker && _isManager
                    ? null
                    : (on) => setState(() => on! ? _roles.add(role) : _roles.remove(role)),
              ),
            if (_isManager)
              CheckboxListTile(
                value: true,
                title: Text(
                  AppStrings.roleLabel(UserRole.groundManager),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(AppStrings.roleHint(UserRole.groundManager)),
                onChanged: null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(
                _roles.isEmpty ? AppStrings.pickARole : AppStrings.mainRoleNote(UserRole.mainOf(_roles)),
                style: text.bodyMedium?.copyWith(color: _roles.isEmpty ? AppColors.error : AppColors.muted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _roles.isEmpty || !changed ? null : () => Navigator.pop(context, {..._roles}),
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
