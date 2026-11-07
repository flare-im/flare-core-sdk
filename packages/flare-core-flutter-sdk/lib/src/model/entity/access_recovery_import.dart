// GENERATED. Do not edit by hand.

/// Result of importing a recovery link.
final class AccessRecoveryImport {
  /// wire: `outcome`. adopted, unchanged (this link was already imported) or rejected.
  final String outcome;
  /// wire: `code`. Why a link was rejected: a code of AccessRefreshAttempt.code or developmentMode. Commonly rollback (the link is older than this device's manifest) or badSignature.
  final String? code;
  /// wire: `serial`. Directory serial after the import.
  final int serial;

  const AccessRecoveryImport({
    this.outcome = '',
    this.code,
    this.serial = 0,
  });
}
