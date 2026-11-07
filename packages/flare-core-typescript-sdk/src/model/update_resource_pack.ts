/** GENERATED. Do not edit by hand. */

/** One verified resource pack. Data only; the Kit and the host interpret it. */
export interface UpdateResourcePack {
  /** wire: `id`. Pack id. */
  id: string;
  /** wire: `kind`. strings, tokens, emoji or help. */
  kind: string;
  /** wire: `packVersion`. Pack version. */
  packVersion: number;
  /** wire: `contentJson`. The pack file as text, a flare.resource.v1 document. */
  contentJson: string;
}
