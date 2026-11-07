package flare_core_harmony_cangjie_sdk.listener

import flare_core_harmony_cangjie_sdk.model.*

// GENERATED. Do not edit by hand.
// Update listener callbacks.
public interface UpdateEventListener {
    // The update center state changed (update://state). Delivered with a session; before sign-in read update.getState.
    func onUpdateState(event: UpdateStatus): Unit
}
