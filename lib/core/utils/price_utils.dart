class PriceUtils {
  /// The Ngultrum, written as in Bhutan: 'Nu. 1,500'.
  static const currency = 'Nu.';

  /// Whole Ngultrum, as grounds are priced: 1500 shows as 'Nu. 1,500'.
  static String nu(int amount) => '$currency ${amount < 0 ? '-' : ''}${_grouped(amount.abs())}';

  /// 1500 -> '1,500'.
  static String _grouped(int amount) =>
      amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /// Plain digits are grouped ('1000' -> '1,000'); anything else (commas
  /// already, a decimal point, a very long number) shows as typed.
  static String _tidy(String amount) =>
      RegExp(r'^\d{4,9}$').hasMatch(amount) ? _grouped(int.parse(amount)) : amount;

  // 'Nu 500', 'nu.500', 'Nu. 500': the usual currency, however it was typed.
  static final _nuAmount = RegExp(r'^nu\.?\s*(\d[\d,]*)', caseSensitive: false);

  // Already says which money: Nu, Ngultrum, BTN, rupees and so on.
  static final _namesCurrency =
      RegExp(r'\b(nu|ngultrum|btn|rs|rupees?|inr|usd)\b|[₹$]', caseSensitive: false);

  // An amount at the start, perhaps after a word like 'from' or 'about'.
  static final _amount = RegExp(
    r'^((?:from|starting(?: at| from)?|starts at|around|about|approx\.?|approximately|'
    r'minimum|min\.?|up to|upto|only)\s+)?(\d[\d,]*)',
    caseSensitive: false,
  );

  // A number that counts something else, as in '2 hours' or '3 days'.
  static final _count = RegExp(
    r'^\s*(hours?|hrs?|days?|weeks?|months?|years?|yrs?|minutes?|mins|people|persons?|workers?|rooms?|times)\b',
    caseSensitive: false,
  );

  /// A worker's price note as customers see it (B2, C2, C3, B5), with its
  /// amount written as the app writes amounts: 'Nu.' in front ('1000' shows
  /// as 'Nu. 1,000', 'From 300' as 'From Nu. 300', 'Nu 500' as 'Nu. 500').
  /// Other currencies and anything else show as typed, and the note is saved
  /// as typed. Null (no price given) stays null.
  static String? display(String? note) {
    if (note == null) return null;
    final text = note.trim();
    final nu = _nuAmount.firstMatch(text);
    if (nu != null) return '$currency ${_tidy(nu.group(1)!)}${text.substring(nu.end)}';
    if (_namesCurrency.hasMatch(text)) return text;
    final match = _amount.firstMatch(text);
    if (match == null || _count.hasMatch(text.substring(match.end))) return text;
    final lead = match.group(1) ?? '';
    return '$lead$currency ${_tidy(match.group(2)!)}${text.substring(match.end)}';
  }
}
