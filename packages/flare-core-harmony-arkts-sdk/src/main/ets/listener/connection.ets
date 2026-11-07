// GENERATED. Do not edit by hand.
import { ConnectionStatus } from '../model';

/** Connection listener callbacks. */
export interface ConnectionEventListener {
  /** The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged. */
  onConnectionStatusChanged?(event: ConnectionStatus): void;
}
