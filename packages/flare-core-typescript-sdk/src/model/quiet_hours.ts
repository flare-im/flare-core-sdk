/** GENERATED. Do not edit by hand. */

/** Do-not-disturb hours, in the device's local time. */
export interface QuietHours {
  /** wire: `allowMentions`. Whether messages that mention the user still ring inside the window. */
  allowMentions: boolean;
  /** wire: `endMinute`. End, minute of the day (0..1439), exclusive. Equal to the start: all day. Smaller than the start: the window crosses midnight. */
  endMinute: number;
  /** wire: `startMinute`. Start, minute of the day (0..1439), inclusive. */
  startMinute: number;
  /** wire: `weekdays`. Days the window starts on: bit0 Monday .. bit6 Sunday; 0 means every day. */
  weekdays: number;
}
