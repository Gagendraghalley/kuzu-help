import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

/// A3 Login
/// Purpose: Sign up with an email code, or log in with email and password.
/// Backend: Sign-ups check the email isn't registered, then send an OTP with
/// name + role as metadata (A4, then A5 sets the password). Log-ins check the
/// password. 'Forgot password?' sends an OTP and ends on A5 with a new password.
/// Done when: A code arrives within a minute; the right password logs in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _sendingReset = false;
  bool _alreadyRegistered = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs [action] with the loading state, showing any error.
  Future<void> _run(Future<void> Function() action, {bool reset = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _sendingReset = reset;
      _alreadyRegistered = false;
      _error = null;
    });
    try {
      await action();
    } on AccountProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _alreadyRegistered = problem == AccountProblem.alreadyRegistered;
        _error = problem == AccountProblem.noAccount ? AppStrings.noAccountFound : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sendingReset = false;
        });
      }
    }
  }

  /// Sign-up: email a code to confirm the address.
  void _sendCode() {
    if (!_formKey.currentState!.validate()) return;
    _run(() async {
      await ref.read(authActionsProvider).sendCode(email: _email.text, fullName: _name.text);
      if (mounted) context.push(Routes.verifyOtp);
    });
  }

  /// Log in: on success the router moves on by itself and this screen closes.
  void _logIn() {
    if (!_formKey.currentState!.validate()) return;
    _run(() => ref.read(authActionsProvider).logIn(email: _email.text, password: _password.text));
  }

  /// 'Forgot password?': only the email is needed.
  void _resetPassword() {
    if (!_emailKey.currentState!.validate()) return;
    _run(reset: true, () async {
      await ref.read(authActionsProvider).sendCode(email: _email.text);
      if (mounted) context.push(Routes.verifyOtp);
    });
  }

  /// Between sign-up and log-in on this screen, keeping the email typed.
  void _switchTo({required String? role}) {
    ref.read(chosenRoleProvider.notifier).state = role;
    setState(() {
      _alreadyRegistered = false;
      _error = null;
    });
  }

  /// 'New to Kuzu Help?': back to Welcome to choose how they'll use it; on
  /// the way to booking a ground, straight to signing up as a player.
  void _createAccount() {
    if (ref.read(afterLoginRouteProvider) != null) return _switchTo(role: UserRole.player);
    context.canPop() ? context.pop() : context.go(Routes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(chosenRoleProvider);
    final isSignUp = role != null;

    return AuthScaffold(
      // Signing up, the badge shows how they'll use the app; logging in, the logo.
      icon: switch (role) {
        null => null,
        UserRole.worker => Icons.handyman_outlined,
        UserRole.player => Icons.sports_soccer_rounded,
        _ => Icons.search_rounded,
      },
      pill: role == null ? null : AppStrings.signingUpAs(role),
      title: isSignUp ? AppStrings.signUpTitle : AppStrings.logInTitle,
      subtitle: isSignUp ? AppStrings.codeByEmail : AppStrings.logInHint,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSignUp) ...[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: AppStrings.name,
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v ?? '').trim().length < 2 ? AppStrings.enterName : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: _emailKey,
                controller: _email,
                decoration: const InputDecoration(
                  labelText: AppStrings.email,
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: isSignUp ? TextInputAction.done : TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: (v) => EmailUtils.isValid(v ?? '') ? null : AppStrings.invalidEmail,
                onFieldSubmitted: isSignUp ? (_) => _sendCode() : null,
              ),
              if (!isSignUp) ...[
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: AppStrings.password,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: (v) => (v ?? '').isEmpty ? AppStrings.enterPassword : null,
                  onFieldSubmitted: (_) => _logIn(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: Text(_sendingReset ? AppStrings.sendingCode : AppStrings.forgotPassword),
                  ),
                ),
              ],
              if (_alreadyRegistered) ...[
                const SizedBox(height: 16),
                _AlreadyRegistered(
                  signingUpAsWorker: role == UserRole.worker,
                  onLogIn: () => _switchTo(role: null),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                FormError(_error!),
              ],
              SizedBox(height: isSignUp ? 28 : 16),
              PrimaryButton(
                label: isSignUp ? AppStrings.sendCode : AppStrings.logIn,
                isLoading: _busy && !_sendingReset,
                onPressed: isSignUp ? _sendCode : _logIn,
              ),
              const SizedBox(height: 16),
              // The other way in, at the foot of the form.
              if (isSignUp)
                TextButton(
                  onPressed: _busy ? null : () => _switchTo(role: null),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                      text: '${AppStrings.alreadyHaveAccount} ',
                      style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                    const TextSpan(text: AppStrings.logIn),
                  ])),
                )
              else
                TextButton(
                  onPressed: _busy ? null : _createAccount,
                  child: const Text(AppStrings.newHereCreateAccount, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signing up with an email that has an account: what to do instead.
class _AlreadyRegistered extends StatelessWidget {
  final bool signingUpAsWorker;
  final VoidCallback onLogIn;

  const _AlreadyRegistered({required this.signingUpAsWorker, required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.info_outline_rounded, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.alreadyRegisteredTitle,
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(AppStrings.alreadyRegisteredHelp, style: TextStyle(color: AppColors.inkSoft)),
            if (signingUpAsWorker) ...[
              const SizedBox(height: 8),
              const Text(AppStrings.alreadyRegisteredWorkerTip, style: TextStyle(color: AppColors.inkSoft)),
            ],
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: onLogIn,
              child: const Text(AppStrings.logInInstead),
            ),
          ],
        ),
      ),
    );
  }
}
