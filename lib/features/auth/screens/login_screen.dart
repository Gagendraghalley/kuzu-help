import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
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

  /// 'New to Kuzu Help?': back to Welcome to choose how they'll use it.
  void _createAccount() => context.canPop() ? context.pop() : context.go(Routes.welcome);

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(chosenRoleProvider);
    final isSignUp = role != null;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const AppBarLogo()),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  isSignUp ? AppStrings.signUpTitle : AppStrings.logInTitle,
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (role != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.signingUpAs(role),
                    style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ],
                const SizedBox(height: 8),
                Text(isSignUp ? AppStrings.codeByEmail : AppStrings.logInHint, style: text.bodyLarge),
                const SizedBox(height: 24),
                if (isSignUp) ...[
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: AppStrings.name),
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
                  decoration: const InputDecoration(labelText: AppStrings.email),
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
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: isSignUp ? AppStrings.sendCode : AppStrings.logIn,
                  isLoading: _busy && !_sendingReset,
                  onPressed: isSignUp ? _sendCode : _logIn,
                ),
                const SizedBox(height: 8),
                if (isSignUp)
                  TextButton(
                    onPressed: _busy ? null : () => _switchTo(role: null),
                    child: Text('${AppStrings.alreadyHaveAccount} ${AppStrings.logIn}'),
                  )
                else ...[
                  TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: Text(_sendingReset ? AppStrings.sendingCode : AppStrings.forgotPassword),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _createAccount,
                    child: const Text(AppStrings.newHereCreateAccount),
                  ),
                ],
              ],
            ),
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
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.alreadyRegisteredTitle,
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(AppStrings.alreadyRegisteredHelp),
            if (signingUpAsWorker) ...[
              const SizedBox(height: 8),
              const Text(AppStrings.alreadyRegisteredWorkerTip),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: onLogIn,
              child: const Text(AppStrings.logInInstead),
            ),
          ],
        ),
      ),
    );
  }
}
