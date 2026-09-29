import 'package:bhutan_services/core/utils/email_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts normal addresses, ignoring spaces around them', () {
    expect(EmailUtils.isValid('pema@example.com'), isTrue);
    expect(EmailUtils.isValid(' karma.wangdi@druknet.bt '), isTrue);
  });

  test('rejects obvious mistakes', () {
    for (final bad in ['', 'pema', 'pema@', 'pema@example', 'pe ma@example.com', '@example.com']) {
      expect(EmailUtils.isValid(bad), isFalse, reason: bad);
    }
  });
}
