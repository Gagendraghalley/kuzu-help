extension BlankToNull on String {
  /// The trimmed text, or null when there is none (optional database columns).
  String? get orNull {
    final text = trim();
    return text.isEmpty ? null : text;
  }
}
