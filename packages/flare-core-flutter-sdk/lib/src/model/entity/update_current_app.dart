// GENERATED. Do not edit by hand.

/// The running app.
final class UpdateCurrentApp {
  /// wire: `version`. Display version.
  final String? version;
  /// wire: `build`. Build number.
  final int? build;
  /// wire: `channel`. Update channel.
  final String channel;
  /// wire: `distribution`. Distribution channel.
  final String? distribution;

  const UpdateCurrentApp({
    this.version,
    this.build,
    this.channel = '',
    this.distribution,
  });
}
