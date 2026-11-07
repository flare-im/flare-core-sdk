// GENERATED. Do not edit by hand.

/// Why the last update action did not go through.
final class UpdateErrorInfo {
  /// wire: `code`. update.* code.
  final String code;
  /// wire: `retryable`. Retrying can help.
  final bool retryable;
  /// wire: `fallbackUrl`. Page to send the user to; absent on the web.
  final String? fallbackUrl;

  const UpdateErrorInfo({
    this.code = '',
    this.retryable = false,
    this.fallbackUrl,
  });
}
