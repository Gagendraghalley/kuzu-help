import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/price_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../../grounds/data/subscription_repository.dart';
import '../../grounds/providers/subscription_providers.dart';

/// Admins (Billing, or Sports grounds -> Billing settings): opens
/// [BillingSettingsSheet] once the settings are in, or says what went wrong.
Future<void> openBillingSettings(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final settings = await ref.read(subscriptionSettingsProvider.future);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BillingSettingsSheet(settings: settings),
    );
  } catch (e) {
    ref.invalidate(subscriptionSettingsProvider); // try again next time
    messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
  }
}

/// Admins: the monthly fee new grounds get after their free month, and how
/// managers pay Kuzu Help, shown on every ground's Subscription page
/// (subscription_settings).
class BillingSettingsSheet extends ConsumerStatefulWidget {
  final SubscriptionSettings settings;

  const BillingSettingsSheet({super.key, required this.settings});

  @override
  ConsumerState<BillingSettingsSheet> createState() => _BillingSettingsSheetState();
}

class _BillingSettingsSheetState extends ConsumerState<BillingSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _fee = TextEditingController(text: widget.settings.defaultFeeNu?.toString() ?? '');
  late final _howToPay = TextEditingController(text: widget.settings.paymentInfo ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fee.dispose();
    _howToPay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(subscriptionRepositoryProvider).saveSettings(SubscriptionSettings(
            defaultFeeNu: int.tryParse(_fee.text.trim()),
            paymentInfo: _howToPay.text.orNull,
          ));
      ref.invalidate(subscriptionSettingsProvider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.billingSettingsSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(AppStrings.billingSettings),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fee,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: AppStrings.defaultFee,
                  prefixText: '${PriceUtils.currency} ',
                  helperText: AppStrings.defaultFeeHint,
                  helperMaxLines: 3,
                ),
                // Empty: none. Otherwise 1 to 1,000,000, as the database takes it.
                validator: (v) => switch ((v ?? '').trim()) {
                  '' => null,
                  final text => switch (int.tryParse(text)) {
                      final n? when n >= 1 && n <= 1000000 => null,
                      _ => AppStrings.enterAmount,
                    },
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _howToPay,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.howManagersPay,
                  hintText: AppStrings.howManagersPayHint,
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FormError(_error!),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: AppStrings.save, isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
