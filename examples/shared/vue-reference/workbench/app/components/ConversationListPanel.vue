<script lang="ts">
// Product composition of the reference workbench: header + filters + search + status + the kit list.
// Lives with the app because the copy, filters and status semantics are product decisions, not kit API.
import type { FlareTone } from "@flare-im/vue-ui/contracts";

export interface ConversationPanelStatus {
  show: boolean;
  title: string;
  detail?: string;
  tone?: FlareTone;
  busy?: boolean;
}
</script>

<script setup lang="ts">
import { computed } from "vue";
import { AddOutline, CloseOutline, EllipsisHorizontalOutline, SearchOutline } from "@flare-im/vue-ui/icon-glyphs";
import type {
  FlareConversationAction,
  FlareConversationListSection,
  FlareConversationRowModel,
} from "@flare-im/vue-ui/contracts";
import {
  FlareConversationList,
  FlareConversationListContainer,
  FlareConversationRow,
  FlareEmptyState,
  FlareFilterTabs,
  type FlareFilterTabOption,
  FlareIconButton,
  FlareScreenHeader,
  FlareSearchBar,
  FlareStatusBanner,
} from "@flare-im/vue-ui/components";

const props = withDefaults(defineProps<{
  items: FlareConversationRowModel[];
  activeId?: string;
  title: string;
  eyebrow?: string;
  meta?: string;
  label?: string;
  filterOptions?: FlareFilterTabOption[];
  activeFilter?: string;
  filterLabel?: string;
  searchOpen?: boolean;
  searchQuery?: string;
  searchPlaceholder?: string;
  searchLabel: string;
  closeSearchLabel: string;
  createLabel: string;
  moreLabel: string;
  /** Something new behind the More button, nothing to count. */
  moreDot?: boolean;
  loading?: boolean;
  status?: ConversationPanelStatus;
  loadingTitle: string;
  loadingDescription?: string;
  emptyTitle: string;
  emptyDescription?: string;
  emptyActionLabel?: string;
  noResultsTitle: string;
  noResultsDescription?: string;
  pinnedSectionLabel?: string;
  allSectionLabel?: string;
}>(), {
  items: () => [],
  filterOptions: () => [],
  activeFilter: "",
  filterLabel: "Filters",
  searchOpen: false,
  searchQuery: "",
  moreDot: false,
  loading: false,
  eyebrow: "",
  meta: "",
  label: "",
  loadingDescription: "",
  emptyDescription: "",
  emptyActionLabel: "",
  noResultsDescription: "",
  pinnedSectionLabel: "",
  allSectionLabel: "",
});

const emit = defineEmits<{
  (event: "update:searchOpen", value: boolean): void;
  (event: "update:searchQuery", value: string): void;
  (event: "filterChange", value: string): void;
  (event: "select", id: string): void;
  (event: "action", action: FlareConversationAction, id: string): void;
  (event: "create"): void;
  (event: "more"): void;
}>();

const sections = computed<FlareConversationListSection[]>(() => {
  const pinned = props.items.filter((item) => item.pinned);
  const rest = props.items.filter((item) => !item.pinned);
  if (!pinned.length) return [{ id: "all", items: rest }];
  return [
    { id: "pinned", label: props.pinnedSectionLabel, items: pinned },
    { id: "all", label: rest.length ? props.allSectionLabel : "", items: rest },
  ];
});
const statusText = computed(() => {
  if (!props.status) return "";
  return props.status.detail ? `${props.status.title} · ${props.status.detail}` : props.status.title;
});
const showInitialLoading = computed(() => props.loading && !props.items.length);
const showEmpty = computed(() => !props.loading && !props.items.length);
const emptyTitleText = computed(() => props.searchQuery ? props.noResultsTitle : props.emptyTitle);
const emptyDescriptionText = computed(() => props.searchQuery ? props.noResultsDescription : props.emptyDescription);
</script>

<template>
  <FlareConversationListContainer class="reference-conversation-panel" :label="label || title">
    <template #header>
      <FlareScreenHeader :title="title" :eyebrow="eyebrow" :meta="meta">
        <template #actions>
          <FlareIconButton
            :icon="searchOpen ? CloseOutline : SearchOutline"
            :ariaLabel="searchOpen ? closeSearchLabel : searchLabel"
            variant="tinted"
            :active="searchOpen"
            toggle
            @click="emit('update:searchOpen', !searchOpen)"
          />
          <FlareIconButton :icon="AddOutline" :ariaLabel="createLabel" variant="solid" @click="emit('create')" />
          <FlareIconButton :icon="EllipsisHorizontalOutline" :ariaLabel="moreLabel" :dot="moreDot" @click="emit('more')" />
        </template>
      </FlareScreenHeader>
    </template>

    <template v-if="filterOptions.length" #filters>
      <div class="reference-conversation-panel__filters">
        <FlareFilterTabs
          :model-value="activeFilter"
          :options="filterOptions"
          :aria-label="filterLabel"
          layout="grid"
          :columns="4"
          @change="emit('filterChange', $event)"
        />
      </div>
    </template>

    <template v-if="searchOpen" #search>
      <div class="reference-conversation-panel__search">
        <FlareSearchBar
          :model-value="searchQuery"
          :placeholder="searchPlaceholder"
          autofocus
          @update:model-value="emit('update:searchQuery', $event)"
        />
      </div>
    </template>

    <template v-if="status?.show" #status>
      <div class="reference-conversation-panel__status">
        <FlareStatusBanner :text="statusText" :tone="status.tone" :pulse="status.busy" />
      </div>
    </template>

    <FlareEmptyState
      v-if="showInitialLoading"
      class="reference-conversation-panel__empty"
      loading
      :title="loadingTitle"
      :description="loadingDescription"
    />
    <FlareEmptyState
      v-else-if="showEmpty"
      class="reference-conversation-panel__empty"
      icon="chats"
      :title="emptyTitleText"
      :description="emptyDescriptionText"
      :action-text="searchQuery ? undefined : emptyActionLabel"
      @action="emit('create')"
    />
    <FlareConversationList
      v-else
      class="reference-conversation-panel__list"
      :sections="sections"
      :active-id="activeId"
    >
      <template #item="{ item, active }">
        <FlareConversationRow
          :item="item"
          :active="active"
          :draft-preview="item.draft"
          @select="emit('select', $event)"
          @action="emit('action', $event, item.id)"
        />
      </template>
    </FlareConversationList>
  </FlareConversationListContainer>
</template>

<style scoped>
.reference-conversation-panel {
  height: 100%;
  min-width: 0;
  min-height: 0;
}

.reference-conversation-panel__filters,
.reference-conversation-panel__search,
.reference-conversation-panel__status {
  padding: 0 16px 12px;
}

.reference-conversation-panel__search {
  padding-top: 2px;
}

.reference-conversation-panel__list {
  height: 100%;
  padding: 8px 10px 18px;
  background: transparent;
}

.reference-conversation-panel__empty {
  min-height: 260px;
  justify-content: center;
}

@media (max-width: 599px) {
  .reference-conversation-panel__filters,
  .reference-conversation-panel__search,
  .reference-conversation-panel__status {
    padding-inline: 14px;
  }

  .reference-conversation-panel__list {
    padding-inline: 8px;
  }
}
</style>
