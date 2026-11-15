import Foundation

/// GENERATED. Do not edit by hand.
/// Do-not-disturb hours, in the device's local time.
public struct QuietHours: Codable, Sendable {
    /// wire: `allowMentions`. Whether messages that mention the user still ring inside the window.
    public let allowMentions: Bool
    /// wire: `endMinute`. End, minute of the day (0..1439), exclusive. Equal to the start: all day. Smaller than the start: the window crosses midnight.
    public let endMinute: UInt32
    /// wire: `startMinute`. Start, minute of the day (0..1439), inclusive.
    public let startMinute: UInt32
    /// wire: `weekdays`. Days the window starts on: bit0 Monday .. bit6 Sunday; 0 means every day.
    public let weekdays: UInt32

    public init(allowMentions: Bool = false, endMinute: UInt32 = 0, startMinute: UInt32 = 0, weekdays: UInt32 = 0) {
        self.allowMentions = allowMentions
        self.endMinute = endMinute
        self.startMinute = startMinute
        self.weekdays = weekdays
    }
}
