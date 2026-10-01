import '../utils/geo_utils.dart';

/// C1/C2 search choice for every dzongkhag at once (never a real dzongkhag name).
const kAllDzongkhags = 'all';

/// All 20 dzongkhags of Bhutan, used in location dropdowns and filters.
const List<String> kDzongkhags = [
  'Bumthang',
  'Chhukha',
  'Dagana',
  'Gasa',
  'Haa',
  'Lhuentse',
  'Mongar',
  'Paro',
  'Pemagatshel',
  'Punakha',
  'Samdrup Jongkhar',
  'Samtse',
  'Sarpang',
  'Thimphu',
  'Trashigang',
  'Trashiyangtse',
  'Trongsa',
  'Tsirang',
  'Wangdue Phodrang',
  'Zhemgang',
];

/// Main towns, with where they are: typing one finds its dzongkhag, and the
/// nearest one tells which dzongkhag the phone is in (dzongkhagAt).
const List<({String dzongkhag, String town, double lat, double lng})> kDzongkhagTowns = [
  (dzongkhag: 'Bumthang', town: 'Jakar', lat: 27.5492, lng: 90.7525),
  (dzongkhag: 'Bumthang', town: 'Chumey', lat: 27.5300, lng: 90.7000),
  (dzongkhag: 'Chhukha', town: 'Phuentsholing', lat: 26.8516, lng: 89.3884),
  (dzongkhag: 'Chhukha', town: 'Tsimasham', lat: 27.0989, lng: 89.5363),
  (dzongkhag: 'Chhukha', town: 'Gedu', lat: 26.9250, lng: 89.5250),
  (dzongkhag: 'Dagana', town: 'Dagana', lat: 27.0703, lng: 89.8775),
  (dzongkhag: 'Gasa', town: 'Gasa', lat: 27.9068, lng: 89.7274),
  (dzongkhag: 'Haa', town: 'Haa', lat: 27.3833, lng: 89.2833),
  (dzongkhag: 'Lhuentse', town: 'Lhuentse', lat: 27.6678, lng: 91.1839),
  (dzongkhag: 'Mongar', town: 'Mongar', lat: 27.2747, lng: 91.2396),
  (dzongkhag: 'Paro', town: 'Paro', lat: 27.4305, lng: 89.4133),
  (dzongkhag: 'Pemagatshel', town: 'Pemagatshel', lat: 27.0380, lng: 91.4031),
  (dzongkhag: 'Pemagatshel', town: 'Nganglam', lat: 26.8000, lng: 91.2500),
  (dzongkhag: 'Punakha', town: 'Khuruthang', lat: 27.5700, lng: 89.8600),
  (dzongkhag: 'Punakha', town: 'Punakha', lat: 27.5823, lng: 89.8634),
  (dzongkhag: 'Samdrup Jongkhar', town: 'Samdrup Jongkhar', lat: 26.8007, lng: 91.5050),
  (dzongkhag: 'Samdrup Jongkhar', town: 'Dewathang', lat: 26.8600, lng: 91.4700),
  (dzongkhag: 'Samtse', town: 'Samtse', lat: 26.8996, lng: 89.0997),
  (dzongkhag: 'Sarpang', town: 'Gelephu', lat: 26.8705, lng: 90.4875),
  (dzongkhag: 'Sarpang', town: 'Sarpang', lat: 26.8645, lng: 90.2675),
  (dzongkhag: 'Thimphu', town: 'Thimphu', lat: 27.4728, lng: 89.6390),
  (dzongkhag: 'Trashigang', town: 'Trashigang', lat: 27.3330, lng: 91.5540),
  (dzongkhag: 'Trashigang', town: 'Kanglung', lat: 27.2800, lng: 91.5200),
  (dzongkhag: 'Trashiyangtse', town: 'Trashiyangtse', lat: 27.6116, lng: 91.4980),
  (dzongkhag: 'Trongsa', town: 'Trongsa', lat: 27.5023, lng: 90.5072),
  (dzongkhag: 'Tsirang', town: 'Damphu', lat: 27.0089, lng: 90.1224),
  (dzongkhag: 'Wangdue Phodrang', town: 'Bajo', lat: 27.4797, lng: 89.8932),
  (dzongkhag: 'Zhemgang', town: 'Zhemgang', lat: 27.2169, lng: 90.6578),
  (dzongkhag: 'Zhemgang', town: 'Panbang', lat: 26.8667, lng: 90.9667),
];

/// Other ways people spell them.
const Map<String, List<String>> _otherSpellings = {
  'Chhukha': ['Chukha'],
  'Lhuentse': ['Lhuntse'],
  'Mongar': ['Monggar'],
  'Trashigang': ['Tashigang'],
  'Trashiyangtse': ['Tashi Yangtse'],
  'Trongsa': ['Tongsa'],
  'Tsirang': ['Chirang'],
  'Wangdue Phodrang': ['Wangdi'],
  'Zhemgang': ['Shemgang'],
};

/// What typing in a dzongkhag picker finds [dzongkhag] by: its name, other
/// spellings and its main towns.
List<String> dzongkhagSearchTerms(String dzongkhag) => [
      dzongkhag,
      ...?_otherSpellings[dzongkhag],
      for (final t in kDzongkhagTowns)
        if (t.dzongkhag == dzongkhag && t.town != dzongkhag) t.town,
    ];

/// The dzongkhag [place] is in, roughly: that of the nearest main town.
/// Null outside Bhutan.
String? dzongkhagAt(GeoPoint place) {
  if (!place.isInBhutan) return null;
  String? nearest;
  var best = double.infinity;
  for (final t in kDzongkhagTowns) {
    final km = place.distanceKm(GeoPoint(t.lat, t.lng));
    if (km < best) {
      best = km;
      nearest = t.dzongkhag;
    }
  }
  return nearest;
}
