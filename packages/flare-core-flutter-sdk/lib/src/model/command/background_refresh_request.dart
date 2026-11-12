// GENERATED. Do not edit by hand.

/// One background refresh the platform granted the app (iOS BGAppRefreshTask).
final class BackgroundRefreshRequest {
  /// wire: `budgetMs`. Time the platform grants, in milliseconds; the engine uses at most 25000 of it.
  final int budgetMs;

  const BackgroundRefreshRequest({
    this.budgetMs = 0,
  });
}
