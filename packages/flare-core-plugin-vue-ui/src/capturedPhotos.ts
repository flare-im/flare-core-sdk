/**
 * A captured ID photo handed from the capture panel (CorePluginCapabilityHost) to the plugin page that asked for it,
 * so its document slot can show the photo (§6.3). Memory only, by plugin and document side, taken once: the page makes
 * its own object URL from it and revokes that on remove, replace or close. Never stored anywhere else.
 */
const photos = new Map<string, Blob>();
const watchers = new Map<string, Set<() => void>>();
const key = (pluginId: string, side: string) => `${pluginId}\u0000${side}`;

export function offerCapturedPhoto(pluginId: string, side: string, photo: Blob): void {
  photos.set(key(pluginId, side), photo);
  for (const handedOver of [...(watchers.get(key(pluginId, side)) ?? [])]) handedOver();
}

/** Call `handedOver` each time the capture panel hands over a photo for this plugin and side; returns the unsubscribe. */
export function watchCapturedPhoto(pluginId: string, side: string, handedOver: () => void): () => void {
  const at = key(pluginId, side);
  const set = watchers.get(at) ?? new Set<() => void>();
  set.add(handedOver);
  watchers.set(at, set);
  return () => { set.delete(handedOver); if (!set.size && watchers.get(at) === set) watchers.delete(at); };
}

export function takeCapturedPhoto(pluginId: string, side: string): Blob | undefined {
  const at = key(pluginId, side);
  const photo = photos.get(at);
  photos.delete(at);
  return photo;
}
