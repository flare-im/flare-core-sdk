<script setup lang="ts">
// Reference-app developer diagnostics console. Diagnostics routes are not kit
// API (PUBLIC_API.md).
import { FlareButton, FlareInput, FlareSelect } from "@flare-im/vue-ui/components";

defineProps<{
  diagnosticsText: string;
  labResultText: string;
  labBusy?: boolean;
  buildOptions: Array<{ label: string; value: string }>;
  dispatchOptions: Array<{ label: string; value: string }>;
  sdkLab: {
    buildOp: string;
    dispatchOp: string;
    messageText: string;
    messageId: string;
    query: string;
    peerUserId: string;
    userIds: string;
    fileId: string;
    reaction?: string;
    capability: string;
    mediaUrl?: string;
    mediaCacheRoot?: string;
    mediaCacheMaxBytes?: number;
    downloadSubfolder?: string;
    draft?: string;
    jsonParams: string;
  };
  events: readonly {
    id: number;
    label: string;
    detail: string;
  }[];
}>();

const emit = defineEmits<{
  (event: "session"): void;
  (event: "events"): void;
  (event: "open-peer"): void;
  (event: "build-send"): void;
  (event: "dispatch"): void;
  (event: "conversation", kind: string): void;
  (event: "sync", kind: string): void;
  (event: "presence", kind: string): void;
  (event: "media", kind: string): void;
  (event: "capability", kind: string): void;
}>();
</script>

<template>
  <section class="sdk-lab">
    <div class="pane-title">Developer diagnostics</div>
    <div class="lab-grid">
      <FlareButton size="sm" variant="secondary" :loading="labBusy" @click="emit('session')">Session</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('events')">Events</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('open-peer')">Open Peer</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('sync', 'conversation')">Sync Conv</FlareButton>
    </div>

    <div class="lab-field">
      <span>Message Build</span>
      <FlareSelect v-model="sdkLab.buildOp" size="sm" :options="buildOptions" />
      <FlareInput v-model="sdkLab.messageText" size="sm" placeholder="Message / title text" />
      <FlareInput v-model="sdkLab.jsonParams" size="sm" placeholder="JSON payload" />
      <FlareButton size="sm" block @click="emit('build-send')">Build + Send</FlareButton>
    </div>

    <div class="lab-field">
      <span>Message Dispatch</span>
      <FlareSelect v-model="sdkLab.dispatchOp" size="sm" :options="dispatchOptions" />
      <FlareInput v-model="sdkLab.messageId" size="sm" placeholder="message id, defaults to latest" />
      <FlareInput v-model="sdkLab.query" size="sm" placeholder="Search keyword" />
      <FlareInput v-model="sdkLab.reaction" size="sm" placeholder="reaction / mark color" />
      <FlareInput v-model="sdkLab.jsonParams" size="sm" placeholder="JSON payload" />
      <FlareButton size="sm" variant="secondary" block @click="emit('dispatch')">Dispatch</FlareButton>
    </div>

    <div class="lab-field">
      <span>Conversation</span>
      <FlareInput v-model="sdkLab.draft" size="sm" placeholder="draft text" />
      <div class="lab-grid">
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'mark_unread')">Unread</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'pin')">Pin</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'unpin')">Unpin</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'mute')">Mute</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'unmute')">Unmute</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'archive')">Archive</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'unarchive')">Unarchive</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'draft')">Save Draft</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'clear_history')">Clear History</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('conversation', 'list')">List</FlareButton>
      </div>
    </div>

    <div class="lab-grid">
      <FlareButton size="sm" variant="secondary" @click="emit('sync', 'messages')">Sync Msg</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('sync', 'read')">Mark Read</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('presence', 'get')">Presence One</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('presence', 'batch')">Presence</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('presence', 'subscribe')">Sub Presence</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'stats')">Media Stats</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'url')">Media URL</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'temp_url')">Temp URL</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'resolve')">Resolve</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'display_url')">Display URL</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'cache_remote')">Cache</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('media', 'clear')">Clear Media</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('capability', 'list')">Caps</FlareButton>
      <FlareButton size="sm" variant="secondary" @click="emit('capability', 'dispatch')">Cap Dispatch</FlareButton>
    </div>

    <div class="lab-field">
      <span>Media / Capability inputs</span>
      <FlareInput v-model="sdkLab.fileId" size="sm" placeholder="file id / object key" />
      <FlareInput v-model="sdkLab.mediaUrl" size="sm" placeholder="remote media url" />
      <FlareInput v-model="sdkLab.mediaCacheRoot" size="sm" placeholder="cache root" />
      <FlareInput
        :model-value="String(sdkLab.mediaCacheMaxBytes ?? '')"
        size="sm"
        inputmode="numeric"
        aria-label="media cache max bytes"
        @update:model-value="sdkLab.mediaCacheMaxBytes = Number(($event || '').replace(/[^0-9]/g, '')) || 0"
      />
      <FlareInput v-model="sdkLab.downloadSubfolder" size="sm" placeholder="download subfolder" />
      <div class="lab-grid">
        <FlareButton size="sm" variant="secondary" @click="emit('media', 'set_root')">Set Root</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('media', 'set_max')">Set Max</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('media', 'download_subfolder')">Download Folder</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('media', 'saved_path')">Saved Path</FlareButton>
        <FlareButton size="sm" variant="secondary" @click="emit('media', 'delete_download')">Delete Record</FlareButton>
      </div>
    </div>

    <pre>{{ labResultText }}</pre>

    <hr class="lab-divider" />

    <section>
      <div class="pane-title">Diagnostics</div>
      <pre>{{ diagnosticsText }}</pre>
    </section>

    <hr class="lab-divider" />

    <section>
      <div class="pane-title">Events</div>
      <div class="event-list">
        <div v-for="event in events" :key="event.id" class="event-item">
          <strong>{{ event.label }}</strong>
          <span>{{ event.detail }}</span>
        </div>
      </div>
    </section>
  </section>
</template>

<style scoped>
.lab-divider {
  margin: var(--flare-size-spacing-md) 0;
  border: 0;
  border-top: 1px solid var(--flare-color-border-primary);
}
</style>
