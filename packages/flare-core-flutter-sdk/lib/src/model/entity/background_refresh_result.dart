// GENERATED. Do not edit by hand.

/// How a background refresh ended.
final class BackgroundRefreshResult {
  /// wire: `completed`. The link came up and the incremental sync finished within the budget. False when the budget ran out or no session could connect.
  final bool completed;

  const BackgroundRefreshResult({
    this.completed = false,
  });
}
