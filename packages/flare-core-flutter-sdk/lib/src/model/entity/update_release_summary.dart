// GENERATED. Do not edit by hand.

/// The release on offer.
final class UpdateReleaseSummary {
  /// wire: `releaseId`. Release id.
  final String releaseId;
  /// wire: `version`. Display version.
  final String version;
  /// wire: `build`. Build number.
  final int build;
  /// wire: `notes`. Release notes, already in the chosen language.
  final List<String> notes;
  /// wire: `sizeBytes`. Size to download; absent for a store.
  final int? sizeBytes;
  /// wire: `mandatory`. Forced update.
  final bool mandatory;
  /// wire: `recommended`. Recommended update.
  final bool recommended;
  /// wire: `kind`. store, package, webBundle or desktop.
  final String kind;

  const UpdateReleaseSummary({
    this.releaseId = '',
    this.version = '',
    this.build = 0,
    this.notes = const [],
    this.sizeBytes,
    this.mandatory = false,
    this.recommended = false,
    this.kind = '',
  });
}
