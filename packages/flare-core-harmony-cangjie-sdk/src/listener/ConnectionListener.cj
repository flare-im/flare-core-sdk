package flare_core_harmony_cangjie_sdk.listener

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Connection listener callbacks.
public interface ConnectionEventListener {
    // The connection status changed (connection://status). Replace the held status whole and hand it to the Kit ConnectionNotice unchanged.
    func onConnectionStatusChanged(event: ConnectionStatus): Unit
}
