package flare_core_harmony_cangjie_sdk.model.entity

// GENERATED. Do not edit by hand.
// Collection/map payloads are represented as raw JSON strings at the bridge boundary.
// 
public class MediaUploadRecovery {
    // wire: `sameSession`. 
    public let sameSession: Bool
    // wire: `afterRestart`. 
    public let afterRestart: Bool
    // wire: `requiresSourceReselection`. 
    public let requiresSourceReselection: Bool

    public init(sameSession!: Bool, afterRestart!: Bool, requiresSourceReselection!: Bool) {
        this.sameSession = sameSession
        this.afterRestart = afterRestart
        this.requiresSourceReselection = requiresSourceReselection
    }
}
