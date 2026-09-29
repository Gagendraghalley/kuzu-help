import 'package:bhutan_services/core/utils/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds +975 to local numbers', () {
    expect(PhoneUtils.toInternational('17123456'), '+97517123456');
  });

  test('accepts valid B-Mobile and TashiCell numbers', () {
    expect(PhoneUtils.isValidMobile('17123456'), isTrue);
    expect(PhoneUtils.isValidMobile('77123456'), isTrue);
    expect(PhoneUtils.isValidMobile('12345'), isFalse);
  });
}
