// GENERATED. Do not edit by hand.

/// CoreEndpoints
final class CoreEndpoints {
  /// wire: `baseUrl`. Core API base URL, including any deployment path prefix.
  final String baseUrl;
  /// wire: `mediaBaseUrl`. Optional media API base. Defaults to the Core API base.
  final String? mediaBaseUrl;
  /// wire: `quicUrl`. Optional native QUIC gateway; WebSocket remains available.
  final String? quicUrl;
  /// wire: `websocketUrl`. Fully qualified WebSocket gateway URL.
  final String websocketUrl;

  const CoreEndpoints({
    this.baseUrl = '',
    this.mediaBaseUrl,
    this.quicUrl,
    this.websocketUrl = '',
  });
}
