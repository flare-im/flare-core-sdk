<script setup lang="ts">
import { computed, ref } from "vue";
import { ArrowBackOutline, CheckmarkCircleOutline, FlashOutline, RefreshOutline, TerminalOutline } from "@flare-im/vue-ui/icon-glyphs";
import { FlareButton, FlareFilterTabs, FlareInput, FlareSelect } from "@flare-im/vue-ui/components";
import AppIcon from "./AppIcon.vue";
import { useRouter } from "vue-router";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareI18n } from "../shared/i18n";

const sdk = useFlareSdk();
const router = useRouter();
const { t } = useFlareI18n();

const diagnosticsText = computed(() => JSON.stringify(sdk.diagnostics.value, null, 2));
const labResultText = computed(() => JSON.stringify(sdk.labResult.value, null, 2));
const buildCatalogText = computed(() => JSON.stringify(sdk.messageBuildCatalog.value, null, 2));
const latestEvent = computed(() => sdk.events.value[0]);
const tabOptions = computed(() => [{ value: "diagnostics", label: t('sdkLab.diagnostics') }, { value: "connection-session", label: t('sdklab.tabConnSession') }, { value: "builder", label: t('sdkLab.builder') }, { value: "message-dispatch", label: t('sdklab.tabMessageOps') }, { value: "sync-presence", label: t('sdklab.tabSyncPresence') }, { value: "capability", label: t('sdklab.tabCapability') }, { value: "media", label: t('sdklab.tabMedia') }, { value: "events", label: t('sdklab.tabEvents') }]);
const activeTab = ref("diagnostics");

const activeRuntimeTone = computed(() => {
  const phase = sdk.connectionPhase.value;
  if (phase === "online") return "success";
  return phase === "idle" ? "default" : "warning";
});

const runtimeCards = computed(() => {
  const diagnostics = sdk.diagnostics.value as Record<string, unknown>;
  const sdkVersion = (diagnostics.sdkVersion ?? {}) as Record<string, unknown>;
  const ffi = (diagnostics.ffi ?? {}) as Record<string, unknown>;
  const dataRoot = (diagnostics.dataRoot ?? {}) as Record<string, unknown>;
  const runtimeHealth = (diagnostics.runtimeHealth ?? {}) as Record<string, unknown>;
  const wasmBinding = (sdkVersion.wasmBinding ?? {}) as Record<string, unknown>;
  return [
    {
      label: "Runtime",
      value: String(sdkVersion.runtime ?? sdk.sdkRuntimeStatus.value),
      detail: String(sdkVersion.adapterBoundary ?? "TypeScript SDK + host IMClient"),
    },
    {
      label: "Core Contract",
      value: String(ffi.version ?? "flare-im-ffi/v1"),
      detail: String(sdkVersion.coreSdk ?? "flare-im-core-sdk"),
    },
    {
      label: "Storage",
      value: String((dataRoot.storage as Record<string, unknown> | undefined)?.kind ?? "indexeddb"),
      detail: String(dataRoot.dataUrl ?? sdk.form.dataUrl),
    },
    {
      label: "Native Binding",
      value: String(wasmBinding.status ?? sdk.sdkRuntimeStatus.value),
      detail: String(wasmBinding.source ?? "flare-core-sdk-engine/bindings/wasm"),
    },
    {
      label: "Runtime Health",
      value: String(runtimeHealth.state ?? sdk.connectionPhase.value),
      detail: `drops=${String(runtimeHealth.rawSubscriberDroppedTotal ?? 0)} metrics=${String(runtimeHealth.metricsEnabled ?? false)}`,
    },
  ];
});

function back(): void {
  void router.push({ name: "conversations" });
}
</script>

<template>
  <section class="flutter-page sdk-lab-route">
    <header class="sdk-lab-header">
      <FlareButton circle quaternary class="page-nav-back" @click="back" :icon="ArrowBackOutline"></FlareButton>
      <div class="sdk-lab-title">
        <span>Diagnostics Workbench</span>
        <h1>{{ t("sdkLab.title") }}</h1>
      </div>
      <FlareButton circle quaternary :loading="sdk.labBusy.value" @click="sdk.runSessionDiagnostics" :icon="RefreshOutline"></FlareButton>
    </header>

    <section class="sdk-lab-hero">
      <div class="sdk-lab-hero__status">
        <span class="lab-chip" :data-tone="activeRuntimeTone">{{ sdk.connectionPhase.value }}</span>
        <span class="lab-chip" :data-tone="sdk.sessionActive.value ? 'success' : 'default'">
          {{ sdk.sessionActive.value ? t("login.sessionActive") : t("login.sessionInactive") }}
        </span>
      </div>
      <div class="sdk-lab-hero__copy">
        <strong>{{ sdk.currentUserId.value || sdk.form.userId || "anonymous" }}</strong>
        <span>{{ latestEvent ? `${latestEvent.label} · ${latestEvent.detail}` : "No runtime events captured yet" }}</span>
      </div>
      <div class="sdk-lab-hero__actions">
        <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionDiagnostics" :icon="TerminalOutline">Session
        </FlareButton>
        <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runEventOperation" :icon="FlashOutline">Events
        </FlareButton>
        <FlareButton :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('messages')" :icon="CheckmarkCircleOutline">Sync
        </FlareButton>
      </div>
    </section>

    <FlareFilterTabs v-model="activeTab" class="sdk-lab-tabs" layout="scroll" :options="tabOptions" :aria-label="t('sdkLab.diagnostics')" />
    <div class="sdk-lab-panes">
      <section v-show="activeTab === 'diagnostics'" class="sdk-lab-pane">
        <div class="runtime-card-grid">
          <section v-for="card in runtimeCards" :key="card.label" class="runtime-card">
            <span>{{ card.label }}</span>
            <strong>{{ card.value }}</strong>
            <small>{{ card.detail }}</small>
          </section>
        </div>
        <pre class="drawer-json">{{ diagnosticsText }}</pre>
      </section>
      <section v-show="activeTab === 'connection-session'" class="sdk-lab-pane">
        <div class="lab-field">
          <span>Connection status</span>
          <div class="lab-grid">
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('status')">Get status</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('reconnect_now')">Reconnect now</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('disconnect')">Disconnect</FlareButton>
          </div>
        </div>
        <div class="lab-field">
          <span>Access</span>
          <div class="lab-grid">
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('access_status')">Access status</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('access_points')">Access points</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('access_diagnostics')">Export diagnostics</FlareButton>
          </div>
        </div>
        <div class="lab-field">
          <span>Session lifecycle</span>
          <div class="lab-grid">
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('current_user')">Current user</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('session_active')">Session active</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('runtime_health')">Runtime health</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('prepare')">Prepare</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('send_no_oss')">Send (no OSS)</FlareButton>
            <FlareButton variant="secondary" type="warning" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('uninit')">Uninit</FlareButton>
            <FlareButton variant="secondary" type="error" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('hard_reset')">Hard reset</FlareButton>
          </div>
        </div>
        <div class="lab-field">
          <span>Heartbeat / token</span>
          <FlareInput
            :model-value="String(sdk.sdkLab.heartbeatNatTimeoutSecs ?? '')"
            inputmode="numeric"
            aria-label="heartbeatNatTimeoutSecs"
            @update:model-value="sdk.sdkLab.heartbeatNatTimeoutSecs = Number(($event || '').replace(/[^0-9]/g, '')) || 0"
          />
          <FlareInput
            :model-value="String(sdk.sdkLab.tokenTtlSecs ?? '')"
            inputmode="numeric"
            aria-label="tokenTtlSecs"
            @update:model-value="sdk.sdkLab.tokenTtlSecs = Number(($event || '').replace(/[^0-9]/g, '')) || 0"
          />
          <div class="lab-grid">
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('heartbeat_interval')">Effective interval</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('heartbeat_nat_timeout')">Set NAT timeout</FlareButton>
            <FlareButton :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('update_access_token')">Refresh token</FlareButton>
          </div>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </section>
      <section v-show="activeTab === 'builder'" class="sdk-lab-pane">
        <div class="lab-field">
          <span>Builder catalog</span>
          <FlareSelect v-model="sdk.sdkLab.buildOp" :options="sdk.messageBuildOptions.value" filterable />
          <FlareInput v-model="sdk.sdkLab.messageText" :placeholder="t('sdklab.messagePlaceholder')" />
          <FlareInput
            v-model="sdk.sdkLab.jsonParams"
            multiline
            :placeholder="t('sdklab.jsonPlaceholder')"
            :autosize="{ minRows: 3, maxRows: 8 }"
          />
          <div class="lab-grid">
            <FlareButton :loading="sdk.labBusy.value" @click="sdk.buildAndSendMessage()">{{ t("sdkLab.buildSend") }}</FlareButton>
            <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSessionDiagnostics">{{ t("sdkLab.refreshCatalog") }}</FlareButton>
          </div>
        </div>
        <pre class="drawer-json">{{ buildCatalogText }}</pre>
      </section>
      <section v-show="activeTab === 'message-dispatch'" class="sdk-lab-pane">
        <div class="lab-field">
          <span>Message dispatch</span>
          <FlareSelect v-model="sdk.sdkLab.dispatchOp" :options="sdk.messageDispatchOptions" filterable />
          <FlareInput v-model="sdk.sdkLab.messageId" :placeholder="t('sdklab.messageIdPlaceholder')" />
          <FlareInput v-model="sdk.sdkLab.query" :placeholder="t('sdklab.searchKeyword')" />
          <FlareInput v-model="sdk.sdkLab.reaction" placeholder="reaction / mark color" />
          <FlareButton :loading="sdk.labBusy.value" @click="sdk.runDispatch()">Dispatch</FlareButton>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </section>
      <section v-show="activeTab === 'sync-presence'" class="sdk-lab-pane">
        <div class="lab-field">
          <span>Presence users</span>
          <FlareInput v-model="sdk.sdkLab.userIds" :placeholder="t('sdklab.userIdsPlaceholder')" />
        </div>
        <div class="lab-grid">
          <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('conversation')">Sync conversation</FlareButton>
          <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('messages')">Sync messages</FlareButton>
          <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('read')">Mark read</FlareButton>
          <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runPresenceOperation('get')">Presence single</FlareButton>
          <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runPresenceOperation('batch')">Presence batch</FlareButton>
          <FlareButton variant="secondary" :loading="sdk.labBusy.value" @click="sdk.runPresenceOperation('subscribe')">Subscribe presence</FlareButton>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </section>
      <section v-show="activeTab === 'capability'" class="sdk-lab-pane">
        <div class="lab-field">
          <span>Capability dispatch</span>
          <FlareInput v-model="sdk.sdkLab.capability" placeholder="plugin capability id" />
          <FlareInput
            v-model="sdk.sdkLab.jsonParams"
            multiline
            :placeholder="t('sdklab.capabilityPlaceholder')"
            :autosize="{ minRows: 3, maxRows: 8 }"
          />
        </div>
        <div class="lab-grid">
          <FlareButton variant="secondary" @click="sdk.runCapabilityOperation('list')">Global capabilities</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runCapabilityOperation('dispatch')">Dispatch</FlareButton>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </section>
      <section v-show="activeTab === 'media'" class="sdk-lab-pane">
        <div class="lab-field">
          <span>Media inputs</span>
          <FlareInput v-model="sdk.sdkLab.fileId" placeholder="file id / object key" />
          <FlareInput v-model="sdk.sdkLab.downloadKey" placeholder="download key" />
          <FlareInput v-model="sdk.sdkLab.displayFileName" placeholder="display file name" />
          <FlareInput v-model="sdk.sdkLab.sourcePath" placeholder="source path" />
          <FlareInput v-model="sdk.sdkLab.sourceUrl" placeholder="source http url" />
          <FlareInput v-model="sdk.sdkLab.remoteFileId" placeholder="remote file id" />
          <FlareInput v-model="sdk.sdkLab.mediaUrl" placeholder="remote media url" />
          <FlareInput v-model="sdk.sdkLab.mediaCacheRoot" placeholder="cache root" />
          <FlareInput
            :model-value="String(sdk.sdkLab.mediaCacheMaxBytes ?? '')"
            inputmode="numeric"
            aria-label="mediaCacheMaxBytes"
            @update:model-value="sdk.sdkLab.mediaCacheMaxBytes = Number(($event || '').replace(/[^0-9]/g, '')) || 0"
          />
          <FlareInput v-model="sdk.sdkLab.downloadSubfolder" placeholder="download subfolder" />
        </div>
        <div class="lab-grid">
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('stats')">Media cache</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('upload_file')">Upload file</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('upload_image')">Upload image</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('upload_video')">Upload video</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('upload_bytes')">Upload bytes</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('delete_file')">Delete file</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('url')">Access URL</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('temp_url')">Temp URL</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('resolve')">Resolve</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('display_url')">Display URL</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('cache_remote')">Cache remote</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('set_root')">Set cache root</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('set_max')">Set cache max</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('download_subfolder')">Download folder</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('download_file')">Download file</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('cancel_download')">Cancel download</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('saved_path')">Saved path</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('delete_download')">Delete record</FlareButton>
          <FlareButton variant="secondary" @click="sdk.runMediaOperation('clear')">{{ t('sdklab.clearMediaCache') }}</FlareButton>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </section>
      <section v-show="activeTab === 'events'" class="sdk-lab-pane">
        <div class="lab-grid">
          <FlareButton :loading="sdk.labBusy.value" @click="sdk.runEventOperation()">
            Subscribe events
          </FlareButton>
        </div>
        <div class="event-contracts">
          <span class="lab-chip"
            v-for="name in [
              'onInitializing',
              'onInitialized',
              'onConnecting',
              'onConnectReady',
              'onDisconnected',
              'onMessageReceived',
              'onMessageSendAck',
              'onMessageReactionChanged',
              'onInputStatusChanged',
              'onNewConversation',
              'onConversationChanged',
              'onSyncProgress',
              'onUploadProgress',
              'onDownloadProgress',
              'onPluginRealtime',
              'onPluginCatalogChanged',
            ]"
            :key="name"
            >
            {{ name }}
          </span>
        </div>
        <ul class="lab-events">
          <li v-for="event in sdk.events.value" :key="event.id">
            <strong>{{ event.label }}</strong> · {{ event.detail }}
          </li>
        </ul>
      </section>
    </div>
  </section>
</template>
