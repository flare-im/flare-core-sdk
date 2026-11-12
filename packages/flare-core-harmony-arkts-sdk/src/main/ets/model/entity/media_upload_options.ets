// GENERATED. Do not edit by hand.
import { MediaUploadPurpose } from './media_upload_purpose';

/** Optional upload options. Omitted chunkSize defaults to 256 KiB; omitted purpose defaults to general. options may contain purpose alone. No arbitrary Public access flag exists. */
export interface MediaUploadOptions {
  /** wire: `chunkSize`. Optional positive part size, in bytes; absent preserves the existing default. */
  chunkSize?: number;
  /** wire: `purpose`. Explicit avatar publication intent. General uploads stay private. Avatar returns stable unsigned url/cdnUrl after real image validation. */
  purpose?: MediaUploadPurpose;
}
