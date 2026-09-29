import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/logout_button.dart';
import '../widgets/password_field.dart';

/// A5 Set password
/// Purpose: After confirming their email with a code, users choose the password
/// they log in with from then on. Also the last step of 'Forgot password?', and
/// 'Change password' in Settings (D1), where it goes back when saved.
/// Backend: Updates the auth user's password and marks it in user metadata.
/// Done when: The user can log out and log back in with email and password.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  static const _minLength = AppConstants.minPasswordLength;

  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  // Read once: saving clears the code request, and the title shouldn't change.
  late final bool _isReset = ref.read(otpRequestProvider)?.isPasswordReset ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authActionsProvider).setPassword(_password.text);
      if (!mounted) return;
      if (context.canPop()) {
        // Changed from Settings.
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.passwordChanged)));
      } else {
        context.go(Routes.splash); // on to the user's first screen
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changing = context.canPop();

    return AuthScaffold(
      icon: Icons.lock_outline_rounded,
      title: changing
          ? AppStrings.changePassword
          : _isReset
              ? AppStrings.newPasswordTitle
              : AppStrings.createPasswordTitle,
      subtitle: changing ? AppStrings.changePasswordHint : AppStrings.createPasswordHint,
      // No back button during sign-up: the user is logged in, and a password comes first.
      showBack: changing,
      actions: changing ? const [] : const [LogoutButton()],
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _password,
                label: AppStrings.password,
                helperText: AppStrings.passwordHint(_minLength),
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').length < _minLength ? AppStrings.passwordTooShort(_minLength) : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: AppStrings.confirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                validator: (v) => v == _password.text ? null : AppStrings.passwordsDontMatch,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                FormError(_error!),
              ],
              const SizedBox(height: 28),
              PrimaryButton(label: AppStrings.savePassword, isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
