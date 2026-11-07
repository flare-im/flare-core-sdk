// GENERATED. Do not edit by hand.

/// A prompt really appeared.
final class UpdateMarkPromptedRequest {
  /// wire: `build`. Build the prompt is about; absent when a forced update has no release yet.
  final int? build;
  /// wire: `form`. sheet, modal or fullscreen.
  final String form;

  const UpdateMarkPromptedRequest({
    this.build,
    this.form = '',
  });
}
