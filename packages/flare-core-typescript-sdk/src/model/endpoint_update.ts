/** GENERATED. Do not edit by hand. */

/** Result of accepting a new set of addresses. Link readiness is reported separately through normal connection status. */
export interface EndpointUpdate {
  /** wire: `changed`.  */
  changed: boolean;
  /** wire: `revision`. Accepted endpoint generation for this initialized client. */
  revision: number;
}
