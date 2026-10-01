import 'package:bhutan_services/core/constants/dzongkhags.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/core/utils/geo_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const changlimithang = GeoPoint(27.4650, 89.6400);
  const paro = GeoPoint(27.4305, 89.4133);

  group('GeoPoint', () {
    test('straight-line distance in km', () {
      expect(changlimithang.distanceKm(changlimithang), 0);
      expect(changlimithang.distanceKm(paro), closeTo(22.7, 0.5));
      expect(paro.distanceKm(changlimithang), closeTo(changlimithang.distanceKm(paro), 1e-9));
    });

    test('knows roughly where Bhutan is', () {
      expect(changlimithang.isInBhutan, isTrue);
      expect(const GeoPoint(27.7172, 85.3240).isInBhutan, isFalse); // Kathmandu
      expect(const GeoPoint(37.3349, -122.0090).isInBhutan, isFalse); // the iOS simulator's default
    });

    test('opens Google Maps with directions there, or a pin', () {
      expect(changlimithang.directionsUrl.toString(),
          'https://www.google.com/maps/dir/?api=1&destination=27.465,89.64');
      expect(changlimithang.mapUrl.toString(), 'https://www.google.com/maps/search/?api=1&query=27.465,89.64');
      expect(changlimithang.label, '27.46500, 89.64000');
    });
  });

  group('MapsLink.parse', () {
    test('a place link: its own pin, not where the map was looking', () {
      expect(
        MapsLink.parse('https://www.google.com/maps/place/Changlimithang+Stadium/@27.4641,89.6380,17z/'
            'data=!3m1!4b1!4m6!3m5!1s0x39e1:0x2!8m2!3d27.465!4d89.64!16s%2Fm%2F0abc'),
        changlimithang,
      );
    });

    test('links with the coordinates in the query', () {
      expect(MapsLink.parse('https://maps.google.com/?q=27.465,89.64'), changlimithang);
      expect(MapsLink.parse('https://www.google.com/maps/search/?api=1&query=27.465%2C89.64'), changlimithang);
      expect(MapsLink.parse('https://www.google.com/maps/dir/?api=1&destination=27.465,89.64'), changlimithang);
    });

    test('a map view, and coordinates on their own', () {
      expect(MapsLink.parse('https://www.google.com/maps/@27.465,89.64,15z'), changlimithang);
      expect(MapsLink.parse('27.465, 89.64'), changlimithang);
      expect(MapsLink.parse('  27.465,89.64 '), changlimithang);
    });

    test('nothing to find', () {
      expect(MapsLink.parse('Changlimithang'), isNull);
      expect(MapsLink.parse('https://maps.app.goo.gl/AbC123xyz'), isNull); // followed by LocationService
      expect(MapsLink.parse('91.5, 200.0'), isNull);
    });

    test('short links are recognised, to be followed', () {
      expect(MapsLink.isShortLink('https://maps.app.goo.gl/AbC123xyz'), isTrue);
      expect(MapsLink.isShortLink('https://goo.gl/maps/AbC123'), isTrue);
      expect(MapsLink.isShortLink('https://www.google.com/maps/@27.465,89.64,15z'), isFalse);
    });

    test('a Google Maps page: the place in its preview image', () {
      const page = '<html><head><meta content="https://maps.google.com/maps/api/staticmap?'
          'center=27.465%2C89.64&amp;zoom=16&amp;size=900x900" property="og:image"></head></html>';
      expect(MapsLink.parsePage(page), changlimithang);
      expect(MapsLink.parsePage('<html>nothing here, 27.465, 89.64</html>'), isNull);
    });
  });

  group('dzongkhags', () {
    test('the one a place is in: that of the nearest main town', () {
      expect(dzongkhagAt(const GeoPoint(27.4728, 89.6390)), 'Thimphu');
      expect(dzongkhagAt(const GeoPoint(27.4400, 89.6600)), 'Thimphu'); // Lungtenphu
      expect(dzongkhagAt(const GeoPoint(26.8516, 89.3884)), 'Chhukha'); // Phuentsholing, nearer Samtse's town than Tsimasham
      expect(dzongkhagAt(const GeoPoint(26.8705, 90.4875)), 'Sarpang'); // Gelephu
      expect(dzongkhagAt(const GeoPoint(27.4797, 89.8932)), 'Wangdue Phodrang'); // Bajo
      expect(dzongkhagAt(const GeoPoint(27.5492, 90.7525)), 'Bumthang'); // Jakar
      expect(dzongkhagAt(const GeoPoint(37.7858, -122.4064)), isNull); // abroad
    });

    test('every dzongkhag has a main town, and is found by its towns and spellings', () {
      for (final d in kDzongkhags) {
        expect(kDzongkhagTowns.where((t) => t.dzongkhag == d), isNotEmpty, reason: d);
      }
      expect(kDzongkhagTowns.map((t) => t.dzongkhag).toSet().difference(kDzongkhags.toSet()), isEmpty);
      expect(dzongkhagSearchTerms('Chhukha'), containsAll(['Chhukha', 'Chukha', 'Phuentsholing']));
      expect(dzongkhagSearchTerms('Sarpang'), contains('Gelephu'));
      expect(dzongkhagSearchTerms('Thimphu'), ['Thimphu']); // its town has the same name
    });
  });

  test('distances read naturally', () {
    expect(AppStrings.distanceAway(0.01), '50 m away');
    expect(AppStrings.distanceAway(0.43), '450 m away');
    expect(AppStrings.distanceAway(0.99), '1.0 km away');
    expect(AppStrings.distanceAway(3.24), '3.2 km away');
    expect(AppStrings.distanceAway(22.7), '23 km away');
  });
}
