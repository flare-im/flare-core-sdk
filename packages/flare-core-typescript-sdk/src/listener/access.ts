/** GENERATED. Do not edit by hand. */
import type { EventCallback } from './common';
import type { AccessChangedEvent, AccessSwitchedEvent } from '../model';

/** Access listener callbacks. */
export interface AccessEventListener {
  /** The IM connection moved to another access point (access://switched). */
  onAccessSwitched?(event: AccessSwitchedEvent): void;
  /** A new access manifest was accepted (access://changed). */
  onAccessChanged?(event: AccessChangedEvent): void;
}
