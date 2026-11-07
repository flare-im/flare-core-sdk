// GENERATED. Do not edit by hand.

/// What the platform package did with the install plan.
final class UpdateReportInstallRequest {
  /// wire: `outcome`. started, completed, cancelled or failed.
  final String outcome;
  /// wire: `code`. update.* code when outcome is failed.
  final String? code;

  const UpdateReportInstallRequest({
    this.outcome = '',
    this.code,
  });
}
