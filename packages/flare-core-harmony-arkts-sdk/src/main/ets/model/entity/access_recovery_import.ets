// GENERATED. Do not edit by hand.

/** Result of importing a recovery link. */
export interface AccessRecoveryImport {
  /** wire: `outcome`. adopted, unchanged (this link was already imported) or rejected. */
  outcome: string;
  /** wire: `code`. Why a link was rejected: a code of AccessRefreshAttempt.code or developmentMode. Commonly rollback (the link is older than this device's manifest) or badSignature. */
  code?: string;
  /** wire: `serial`. Directory serial after the import. */
  serial: number;
}
