import 'package:bhutan_services/core/utils/price_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds Nu to amounts given without a currency', () {
    expect(PriceUtils.display('1000'), 'Nu 1000');
    expect(PriceUtils.display(' 799 '), 'Nu 799');
    expect(PriceUtils.display('500 per visit'), 'Nu 500 per visit');
    expect(PriceUtils.display('1,000-1,500'), 'Nu 1,000-1,500');
    expect(PriceUtils.display('300/hour'), 'Nu 300/hour');
    expect(PriceUtils.display('From 300'), 'From Nu 300');
    expect(PriceUtils.display('about 2000 for a house'), 'about Nu 2000 for a house');
  });

  test('leaves notes that already name a currency', () {
    expect(PriceUtils.display('Nu 500 per visit'), 'Nu 500 per visit');
    expect(PriceUtils.display('Nu.500'), 'Nu.500');
    expect(PriceUtils.display('500 ngultrum'), '500 ngultrum');
    expect(PriceUtils.display('Rs 500'), 'Rs 500');
    expect(PriceUtils.display('₹500'), '₹500');
  });

  test('leaves notes without an amount, or starting with a count', () {
    expect(PriceUtils.display('Free quote'), 'Free quote');
    expect(PriceUtils.display('Depends on the work'), 'Depends on the work');
    expect(PriceUtils.display('2 hours for 500'), '2 hours for 500');
    expect(PriceUtils.display(null), isNull);
  });
}
