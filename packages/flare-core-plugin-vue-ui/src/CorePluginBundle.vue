<script setup lang="ts">
/**
 * A contribution's web bundle variant (design 8.3, 8.9) in the kit's FlarePluginBundleHost: a page, a card's detail or a
 * "+" form. It opens the page through the engine (`plugin_bundle_open`), hands the frame a bridge over the session and
 * ends the session when it goes away. Whenever the bundle cannot show, `fallback` asks the container to draw the
 * declarative variant: the engine offers no bundle (none selected, no runtime, unavailable, refused), the bridge closed
 * the page (withdrawn, suspended, disabled, replaced, evicted, signed out), or the frame failed three times this session.
 */
import { onBeforeUnmount, shallowRef, watch } from "vue";
import { FlarePluginBundleHost, useFlareI18n, type FlarePluginBundleBridge } from "@flare-im/vue-ui";
import { openPluginBundle, type PluginBundleOpened, type PluginBundlePresentation, type PluginBundleSession } from "@flare-im/sdk/plugin-ui";
import type { CorePluginBundleHost } from "./context";
import { corePluginBundleFailed, corePluginBundleGaveUp } from "./pluginBundle";

const props = withDefaults(defineProps<{
  host: CorePluginBundleHost;
  pluginId: string;
  contributionId: string;
  presentation?: PluginBundlePresentation;
  /** A route inside the bundle (`ui.navigate` with `bundleRoute`); the contribution's own route otherwise. */
  route?: string;
  args?: Record<string, unknown>;
  conversation?: { id: string; type: string };
  title?: string;
  back?: boolean;
}>(), { presentation: "page", route: undefined, args: undefined, conversation: undefined, title: "", back: false });
const emit = defineEmits<{
  /** Draw the declarative variant instead. */
  fallback: [];
  back: [];
  close: [result?: unknown];
  navigate: [target: { page?: string; arguments?: Record<string, unknown>; bundleRoute?: string }];
  title: [title: string];
  resize: [height: number];
}>();

const { t, locale } = useFlareI18n();
const bridge = shallowRef<FlarePluginBundleBridge | null>(null);
const files = shallowRef("");
const entry = shallowRef("index.html");
const error = shallowRef<string>();
const theme = shallowRef(props.host.theme());
let session: PluginBundleSession | null = null;
let opened: PluginBundleOpened | null = null;
let generation = 0;

const key = (root: string) => `${props.pluginId}\u0000${props.contributionId}\u0000${root}`;

function release(): void {
  const current = session, page = opened;
  session = null;
  opened = null;
  bridge.value = null;
  current?.close();
  if (page) props.host.released?.(page);
}

async function open(): Promise<void> {
  const mine = ++generation;
  release();
  error.value = undefined;
  theme.value = props.host.theme();
  let next: PluginBundleSession | null;
  try {
    const hostOrigin = props.host.hostOrigin?.();
    next = await openPluginBundle(props.host.port, {
      pluginId: props.pluginId,
      contributionId: props.contributionId,
      ...(props.route ? { route: props.route } : {}),
      ...(props.args ? { arguments: props.args } : {}),
      presentation: props.presentation,
      ...(props.conversation ? { conversation: props.conversation } : {}),
      locale: locale.value,
      theme: { mode: theme.value.mode, tokens: theme.value.tokens ?? {} },
      ...(hostOrigin ? { hostOrigin } : {}),
    }, props.host.events);
  } catch {
    if (mine === generation) error.value = t("pluginBundle.failed");
    return;
  }
  if (mine !== generation) { next?.close(); return; }
  if (!next) { emit("fallback"); return; }
  if (corePluginBundleGaveUp(key(next.opened.root))) { next.close(); emit("fallback"); return; }
  let base: string;
  try {
    base = await (props.host.files?.(next.opened) ?? next.opened.root);
  } catch {
    next.close();
    if (mine === generation) error.value = t("pluginBundle.failed");
    return;
  }
  if (mine !== generation) { next.close(); props.host.released?.(next.opened); return; }
  session = next;
  opened = next.opened;
  files.value = base;
  entry.value = next.opened.entry || "index.html";
  const live = next;
  bridge.value = {
    request: (envelope, context) => live.request(envelope as Record<string, unknown>, context),
    hostResult: (id, outcome) => live.hostResult(id, outcome),
    hostEvent: (event, payload) => live.hostEvent(event, payload),
    subscribe: (listener) => live.subscribe(listener),
    // Only this page's own session: a newer one opened meanwhile is not this bridge's to end.
    close: () => { if (session === live) release(); else live.close(); },
  };
}

function closed(): void {
  release();
  emit("fallback");
}
function failed(): void {
  if (opened && corePluginBundleFailed(key(opened.root))) { release(); emit("fallback"); }
}

watch([
  () => props.pluginId,
  () => props.contributionId,
  () => props.route,
  () => JSON.stringify(props.args ?? null),
  () => props.presentation,
  () => props.conversation?.id,
  () => props.conversation?.type,
], () => {
  void open();
}, { immediate: true });
watch(() => props.host.theme(), (value) => { theme.value = value; }, { deep: true });
onBeforeUnmount(() => { generation++; release(); });
</script>

<template>
  <FlarePluginBundleHost
    :files="files"
    :entry="entry"
    :bridge="bridge"
    :theme="theme"
    :locale="locale"
    :presentation="presentation"
    :title="title"
    :back="back"
    :error="error"
    :open-external="host.openExternal"
    @back="emit('back')"
    @close="(result) => emit('close', result)"
    @navigate="(target) => emit('navigate', target)"
    @title="(value) => emit('title', value)"
    @resize="(value) => emit('resize', value)"
    @closed="closed"
    @failed="failed"
    @retry="open"
  />
</template>
