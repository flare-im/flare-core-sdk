import Foundation

/// GENERATED. Do not edit by hand.
/// Update listener callbacks.
public protocol UpdateEventListener: AnyObject {
    /// The update center state changed (update://state). Delivered with a session; before sign-in read update.getState.
    func onUpdateState(_ event: UpdateStatus)
}

public extension UpdateEventListener {
    func onUpdateState(_ event: UpdateStatus) {}
}
