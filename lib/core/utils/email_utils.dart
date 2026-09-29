class EmailUtils {
  /// A quick shape check (name@domain.tld); Supabase does the real check.
  static bool isValid(String input) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.trim());
}
