/** GENERATED. Do not edit by hand. */

/** What the platform package did with the install plan. */
export interface UpdateReportInstallRequest {
  /** wire: `outcome`. started, completed, cancelled or failed. */
  outcome: string;
  /** wire: `code`. update.* code when outcome is failed. */
  code?: string;
}
