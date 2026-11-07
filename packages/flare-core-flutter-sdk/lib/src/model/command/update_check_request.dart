// GENERATED. Do not edit by hand.

/// Checks for an update.
final class UpdateCheckRequest {
  /// wire: `manual`. The user asked: no frequency limit, and a failure lands in UpdateStatus.error.
  final bool manual;

  const UpdateCheckRequest({
    this.manual = false,
  });
}
