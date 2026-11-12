// GENERATED. Do not edit by hand.

/** The host's answer to a plugin.capability_request event. */
export interface PluginCapabilityCompletion {
  /** wire: `requestId`. The event's requestId. */
  requestId: number;
  /** wire: `result`. consent: {decision: once, always or deny} (only always is kept); captureDocument and pickFile: {file: {fileName, contentType, bytes: [0..255]}} (a document photo compressed, without EXIF); confirmPayment: {confirmation: {...}} (the proof the order's operation takes, at most 4 KiB); locateOnce: {location: {latitude, longitude, accuracyM?}}. Any of them may instead be {cancelled: true} (the viewer backed out) or {unavailable: true} (the host could not); absent counts as unavailable. */
  result?: Record<string, Object>;
}
