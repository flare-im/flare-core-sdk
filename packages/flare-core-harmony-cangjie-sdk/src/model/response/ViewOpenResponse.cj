package flare_core_harmony_cangjie_sdk.model.response

import flare_core_harmony_cangjie_sdk.model.entity.ViewSnapshot

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// Response returned when opening an observable view and by timelineSnapshot.
public class ViewOpenResponse {
    // wire: `viewId`. View id.
    public let viewId: String
    // wire: `revision`. Revision of this snapshot; every later view.updated event for the view carries the next revision.
    public let revision: UInt64
    // wire: `snapshot`. Snapshot of the view at that revision.
    public let snapshot: ViewSnapshot

    public init(viewId!: String, revision!: UInt64, snapshot!: ViewSnapshot) {
        this.viewId = viewId
        this.revision = revision
        this.snapshot = snapshot
    }
}
