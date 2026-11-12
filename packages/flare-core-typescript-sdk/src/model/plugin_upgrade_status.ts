/** GENERATED. Do not edit by hand. */

/** Whether an update reaching a plugin's minimum build is offered to this device. */
export interface PluginUpgradeStatus {
  /** wire: `available`. A release at or above the floor is offered. */
  available: boolean;
  /** wire: `build`. That release's build, when available. */
  build?: number;
}
