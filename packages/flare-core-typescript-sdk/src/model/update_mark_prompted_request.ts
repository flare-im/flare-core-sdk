/** GENERATED. Do not edit by hand. */

/** A prompt really appeared. */
export interface UpdateMarkPromptedRequest {
  /** wire: `build`. Build the prompt is about; absent when a forced update has no release yet. */
  build?: number;
  /** wire: `form`. sheet, modal or fullscreen. */
  form: string;
}
