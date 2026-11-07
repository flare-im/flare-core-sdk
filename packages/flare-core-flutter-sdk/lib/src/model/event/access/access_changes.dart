// GENERATED. Do not edit by hand.

/// What a newly accepted access manifest changed.
final class AccessChanges {
  /// wire: `accessPointsAdded`. Access points that appeared.
  final List<String> accessPointsAdded;
  /// wire: `accessPointsRemoved`. Access points that disappeared.
  final List<String> accessPointsRemoved;
  /// wire: `policyChanged`. Whether the client link policy changed.
  final bool policyChanged;

  const AccessChanges({
    this.accessPointsAdded = const [],
    this.accessPointsRemoved = const [],
    this.policyChanged = false,
  });
}
