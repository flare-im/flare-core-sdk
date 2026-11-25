import Foundation

/// GENERATED. Do not edit by hand.
/// 
public struct MediaUploadRecovery: Codable, Sendable {
    /// wire: `sameSession`. 
    public let sameSession: Bool
    /// wire: `afterRestart`. 
    public let afterRestart: Bool
    /// wire: `requiresSourceReselection`. 
    public let requiresSourceReselection: Bool

    public init(sameSession: Bool = false, afterRestart: Bool = false, requiresSourceReselection: Bool = false) {
        self.sameSession = sameSession
        self.afterRestart = afterRestart
        self.requiresSourceReselection = requiresSourceReselection
    }
}
