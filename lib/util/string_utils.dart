/// String utilities.
extension StringBlank on String {
  /// Returns true if a string is empty or starts with placeholder text.
  bool get isBlank => isEmpty || startsWith('_Not') || startsWith('_Nothing');
}
