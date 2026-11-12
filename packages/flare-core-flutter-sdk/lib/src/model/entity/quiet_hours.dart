// GENERATED. Do not edit by hand.

/// Do-not-disturb hours, in the device's local time.
final class QuietHours {
  /// wire: `allowMentions`. Whether messages that mention the user still ring inside the window.
  final bool allowMentions;
  /// wire: `endMinute`. End, minute of the day (0..1439), exclusive. Equal to the start: all day. Smaller than the start: the window crosses midnight.
  final int endMinute;
  /// wire: `startMinute`. Start, minute of the day (0..1439), inclusive.
  final int startMinute;
  /// wire: `weekdays`. Days the window starts on: bit0 Monday .. bit6 Sunday; 0 means every day.
  final int weekdays;

  const QuietHours({
    this.allowMentions = false,
    this.endMinute = 0,
    this.startMinute = 0,
    this.weekdays = 0,
  });
}
