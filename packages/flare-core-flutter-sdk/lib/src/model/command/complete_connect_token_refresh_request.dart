// GENERATED. Do not edit by hand.

/// Answer to one connect token refresh request.
final class CompleteConnectTokenRefreshRequest {
  /// wire: `requestId`. Request id the core asked with.
  final int requestId;
  /// wire: `token`. The new connect token; omitted or empty when none could be obtained.
  final String? token;

  const CompleteConnectTokenRefreshRequest({
    this.requestId = 0,
    this.token,
  });
}
