// GENERATED. Do not edit by hand.
import 'media_upload_purpose.dart';

/// Optional upload options. Omitted chunkSize defaults to 256 KiB; omitted purpose defaults to general. options may contain purpose alone. No arbitrary Public access flag exists.
final class MediaUploadOptions {
  /// wire: `chunkSize`. Optional positive part size, in bytes; absent preserves the existing default.
  final int? chunkSize;
  /// wire: `purpose`. Explicit avatar publication intent. General uploads stay private. Avatar returns stable unsigned url/cdnUrl after real image validation.
  final MediaUploadPurpose? purpose;

  const MediaUploadOptions({
    this.chunkSize,
    this.purpose,
  });
}
