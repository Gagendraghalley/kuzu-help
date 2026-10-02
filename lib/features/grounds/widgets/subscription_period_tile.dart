import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_utils.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/widgets/icon_tile.dart';

/// One period of a ground's billing history: its free month, free time or a
/// month paid for, with its dates, how it was paid and its invoice. In
/// Billing (admins), headed by the ground's name ([venueName]). [trailing]
/// replaces the chevron [onTap] shows.
class SubscriptionPeriodTile extends StatelessWidget {
  final SubscriptionPeriod period;
  final String? venueName;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SubscriptionPeriodTile({super.key, required this.period, this.venueName, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = period;
    final paid = p.kind == SubscriptionKind.paid;
    final what =
        [AppStrings.subscriptionKindLabel(p.kind), if (p.amountNu case final amount?) PriceUtils.nu(amount)].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: IconTile(
        icon: paid ? Icons.payments_outlined : Icons.card_giftcard_outlined,
        color: paid ? AppColors.verified : AppColors.primaryDeep,
      ),
      title: Text(venueName ?? what, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        if (venueName != null) what,
        AppStrings.periodDates(p.firstDay, p.lastDay),
        [
          if (p.paymentMethod case final method?) AppStrings.billingMethodLabel(method),
          if (p.paymentReference case final reference?) AppStrings.journalNo(reference),
          if (p.note case final note?) note,
        ].join(' · '),
        if (p.invoiceNumber case final invoice?) AppStrings.invoiceLabel(invoice, emailed: p.invoiceSentAt != null),
      ].where((line) => line.isNotEmpty).join('\n')),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.muted)),
    );
  }
}
