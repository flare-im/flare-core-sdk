// GENERATED. Do not edit by hand.

/// One verified resource pack. Data only; the Kit and the host interpret it.
final class UpdateResourcePack {
  /// wire: `id`. Pack id.
  final String id;
  /// wire: `kind`. strings, tokens, emoji or help.
  final String kind;
  /// wire: `packVersion`. Pack version.
  final int packVersion;
  /// wire: `contentJson`. The pack file as text, a flare.resource.v1 document.
  final String contentJson;

  const UpdateResourcePack({
    this.id = '',
    this.kind = '',
    this.packVersion = 0,
    this.contentJson = '',
  });
}
