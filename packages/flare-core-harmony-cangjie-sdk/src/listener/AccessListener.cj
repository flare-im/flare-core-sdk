package flare_core_harmony_cangjie_sdk.listener

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Access listener callbacks.
public interface AccessEventListener {
    // The IM connection moved to another access point (access://switched).
    func onAccessSwitched(event: AccessSwitchedEvent): Unit
    // A new access manifest was accepted (access://changed).
    func onAccessChanged(event: AccessChangedEvent): Unit
}
