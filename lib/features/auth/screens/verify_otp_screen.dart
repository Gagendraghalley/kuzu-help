import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/code_boxes.dart';

/// A4 Verify code
/// Purpose: Confirm the code and log in.
/// Backend: Verifies the OTP, creating the session.
/// Done when: User lands on the right screen and stays logged in after restart.
class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _resendTimer;
  int _secondsLeft = 0;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// 'Resend code' unlocks after 60 seconds.
  void _startResendTimer() {
    _secondsLeft = AppConstants.otpResendSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_verifying || _code.text.length != AppConstants.otpLength) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      // On success the router moves on by itself and this screen closes.
      await ref.read(authActionsProvider).verifyCode(_code.text);
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      _codeFocus.requestFocus();
      setState(() {
        _verifying = false;
        _error = ErrorMessages.from(e);
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authActionsProvider).resendCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(AppStrings.codeResent)));
      setState(_startResendTimer);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(otpRequestProvider);
    final email = request?.email ?? '';

    return AuthScaffold(
      icon: Icons.mark_email_read_outlined,
      title: AppStrings.verifyTitle,
      subtitle: AppStrings.codeSentTo(email),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Signing up with an email that has an account: this adds to it.
          if (request != null && request.addsToAccount) ...[
            InfoNote(icon: Icons.person_add_alt_1_outlined, text: AppStrings.addingToAccount(request.role!)),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          CodeBoxes(
            controller: _code,
            focusNode: _codeFocus,
            length: AppConstants.otpLength,
            semanticLabel: AppStrings.enterCode,
            hasError: _error != null,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onCompleted: (_) => _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FormError(_error!),
          ],
          const SizedBox(height: 28),
          PrimaryButton(label: AppStrings.verify, isLoading: _verifying, onPressed: _verify),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _secondsLeft > 0 ? null : _resend,
            child: Text(
              _secondsLeft > 0 ? AppStrings.resendIn(_secondsLeft) : AppStrings.resendCode,
            ),
          ),
        ],
      ),
    );
  }
}
