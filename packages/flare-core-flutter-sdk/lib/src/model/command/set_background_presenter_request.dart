// GENERATED. Do not edit by hand.

/// Whether the platform presents alerts itself while the app is in the background.
final class SetBackgroundPresenterRequest {
  /// wire: `attached`. The platform push module posts local notifications for the engine while the app is in the background.
  final bool attached;

  const SetBackgroundPresenterRequest({
    this.attached = false,
  });
}
