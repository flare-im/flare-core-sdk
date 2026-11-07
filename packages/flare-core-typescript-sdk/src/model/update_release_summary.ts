/** GENERATED. Do not edit by hand. */

/** The release on offer. */
export interface UpdateReleaseSummary {
  /** wire: `releaseId`. Release id. */
  releaseId: string;
  /** wire: `version`. Display version. */
  version: string;
  /** wire: `build`. Build number. */
  build: number;
  /** wire: `notes`. Release notes, already in the chosen language. */
  notes: string[];
  /** wire: `sizeBytes`. Size to download; absent for a store. */
  sizeBytes?: number;
  /** wire: `mandatory`. Forced update. */
  mandatory: boolean;
  /** wire: `recommended`. Recommended update. */
  recommended: boolean;
  /** wire: `kind`. store, package, webBundle or desktop. */
  kind: string;
}
