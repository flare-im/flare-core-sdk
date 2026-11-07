// GENERATED. Do not edit by hand.
import { AccessEndpoint } from './access_endpoint';

/** Payload of access://switched: the IM connection moved to another access point (sent once, when the new connection is ready). */
export interface AccessSwitchedEvent {
  /** wire: `from`. Where the connection was. */
  from: AccessEndpoint;
  /** wire: `to`. Where the connection is now. */
  to: AccessEndpoint;
  /** wire: `reason`. Why: failure, drain, failback, manual or manifest. */
  reason: string;
}
