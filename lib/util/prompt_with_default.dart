// prompt_with_default.dart — a prompt with an inline, pre-fillable default
//
// Shared by teardown.dart and setup.dart (or any command with an injected
// `String? Function(String, {bool optional}) prompt_` seam) so both render
// the same one-line `Question [default]` shape instead of each hand-rolling
// its own default-hint formatting.

/// Asks [question], showing [defaultValue] inline (`Question [default]`) when
/// one exists — press enter to accept it, or type to override. Falls back to
/// a bare [question] with no hint when [defaultValue] is null.
String? promptWithDefault(
  String? Function(String, {bool optional}) prompt_,
  String question,
  String? defaultValue, {
  bool optional = false,
}) {
  if (defaultValue != null) {
    return prompt_('$question [$defaultValue]', optional: true) ?? defaultValue;
  }
  return prompt_(question, optional: optional);
}
