class PriceUtils {
  static const currency = 'Nu';

  // Already says which money: Nu, Ngultrum, BTN, rupees and so on.
  static final _namesCurrency =
      RegExp(r'\b(nu|ngultrum|btn|rs|rupees?|inr|usd)\b|[₹$]', caseSensitive: false);

  // An amount at the start, perhaps after a word like 'from' or 'about'.
  static final _amount = RegExp(
    r'^((?:from|starting(?: at| from)?|starts at|around|about|approx\.?|approximately|'
    r'minimum|min\.?|up to|upto|only)\s+)?\d[\d,.]*',
    caseSensitive: false,
  );

  // A number that counts something else, as in '2 hours' or '3 days'.
  static final _count = RegExp(
    r'^\s*(hours?|hrs?|days?|weeks?|months?|years?|yrs?|minutes?|mins|people|persons?|workers?|rooms?|times)\b',
    caseSensitive: false,
  );

  /// A worker's price note as customers see it (B2, C2, C3, B5): 'Nu' goes
  /// in front of an amount given without a currency, so '1000' shows as
  /// 'Nu 1000' and 'From 300' as 'From Nu 300'. Anything else shows as
  /// typed, and the note is saved as typed. Null (no price given) stays null.
  static String? display(String? note) {
    if (note == null) return null;
    final text = note.trim();
    if (_namesCurrency.hasMatch(text)) return text;
    final match = _amount.firstMatch(text);
    if (match == null || _count.hasMatch(text.substring(match.end))) return text;
    final lead = match.group(1) ?? '';
    return '$lead$currency ${text.substring(lead.length)}';
  }
}
