/** GENERATED. Do not edit by hand. */

/** A manual access point pin. */
export interface AccessPin {
  /** wire: `accessPointId`. The pinned access point. */
  accessPointId: string;
  /** wire: `expiresAtMs`. When the pin lapses, Unix milliseconds; an app restart also clears it. */
  expiresAtMs: number;
}
