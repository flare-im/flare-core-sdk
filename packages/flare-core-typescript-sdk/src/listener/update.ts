/** GENERATED. Do not edit by hand. */
import type { EventCallback } from './common';
import type { UpdateStatus } from '../model';

/** Update listener callbacks. */
export interface UpdateEventListener {
  /** The update center state changed (update://state). Delivered with a session; before sign-in read update.getState. */
  onUpdateState?(event: UpdateStatus): void;
}
