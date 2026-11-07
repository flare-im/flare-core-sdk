/** GENERATED. Do not edit by hand. */

/** What a newly accepted access manifest changed. */
export interface AccessChanges {
  /** wire: `accessPointsAdded`. Access points that appeared. */
  accessPointsAdded: string[];
  /** wire: `accessPointsRemoved`. Access points that disappeared. */
  accessPointsRemoved: string[];
  /** wire: `policyChanged`. Whether the client link policy changed. */
  policyChanged: boolean;
}
