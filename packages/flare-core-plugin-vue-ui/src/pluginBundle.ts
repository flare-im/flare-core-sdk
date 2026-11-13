/**
 * Design 8.8: a bundle whose frame fails three times in one app session is not opened again in that session; its
 * contribution draws the declarative variant. Counted per plugin and contribution, in memory only.
 */
export const CORE_PLUGIN_BUNDLE_MAX_FAILURES = 3;

const failures = new Map<string, number>();

/** Counts one failure of a bundle; whether it has now failed too often. */
export function corePluginBundleFailed(key: string): boolean {
  const count = (failures.get(key) ?? 0) + 1;
  failures.set(key, count);
  return count >= CORE_PLUGIN_BUNDLE_MAX_FAILURES;
}

/** Whether a bundle failed too often this session. */
export function corePluginBundleGaveUp(key: string): boolean {
  return (failures.get(key) ?? 0) >= CORE_PLUGIN_BUNDLE_MAX_FAILURES;
}

/** Forget the failures (signing out, tests). */
export function resetCorePluginBundleFailures(): void {
  failures.clear();
}

/** The posted card a bundle's "+" form closed with (`ui.close({result})`): the operation result's `data`, or the result itself. */
export function corePluginBundleResultData(result: unknown): unknown {
  const record = result as { data?: unknown; operationResult?: { data?: unknown } } | null;
  if (record && typeof record === "object") {
    if (record.operationResult && typeof record.operationResult === "object") return record.operationResult.data ?? record.operationResult;
    if ("data" in record) return record.data;
  }
  return result;
}
