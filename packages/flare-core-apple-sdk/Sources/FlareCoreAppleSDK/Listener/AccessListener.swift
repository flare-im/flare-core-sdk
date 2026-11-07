import Foundation

/// GENERATED. Do not edit by hand.
/// Access listener callbacks.
public protocol AccessEventListener: AnyObject {
    /// The IM connection moved to another access point (access://switched).
    func onAccessSwitched(_ event: AccessSwitchedEvent)
    /// A new access manifest was accepted (access://changed).
    func onAccessChanged(_ event: AccessChangedEvent)
}

public extension AccessEventListener {
    func onAccessSwitched(_ event: AccessSwitchedEvent) {}
    func onAccessChanged(_ event: AccessChangedEvent) {}
}
