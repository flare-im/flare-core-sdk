// GENERATED. Do not edit by hand.

/** Payload of notification.clear: remove these notifications of the app. */
export interface NotificationClearEvent {
  /** wire: `all`. Remove every notification of the app (the session ended); collapseIds is then empty. */
  all: boolean;
  /** wire: `collapseIds`. Collapse ids of the notifications to remove. */
  collapseIds: Array<string>;
}
