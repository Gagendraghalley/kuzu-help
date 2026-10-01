import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/email_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../shared/widgets/info_note.dart';

/// The venue manager's name, email and mobile number, and how their first
/// log-in works. In a Form: when an admin registers a venue, and when they
/// change its manager.
class ManagerFields extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;

  const ManagerFields({super.key, required this.name, required this.email, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoNote(icon: Icons.key_outlined, text: AppStrings.managerAccountHint),
        const SizedBox(height: 16),
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: AppStrings.managerName),
          validator: (v) => (v?.trim() ?? '').isEmpty ? AppStrings.enterManagerName : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: AppStrings.managerEmail),
          validator: (v) => EmailUtils.isValid(v ?? '') ? null : AppStrings.invalidEmail,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: AppStrings.managerPhone,
            hintText: AppStrings.mobileHint,
            prefixText: '${AppConstants.countryCode} ',
          ),
          validator: (v) => (v ?? '').trim().isEmpty || PhoneUtils.isValidMobile(v!) ? null : AppStrings.invalidMobile,
        ),
      ],
    );
  }
}
