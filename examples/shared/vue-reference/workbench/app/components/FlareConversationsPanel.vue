<script setup lang="ts">
import { computed } from "vue";
import { useRouter } from "vue-router";
import type { FlareConversationAction } from "@flare-im/vue-ui/contracts";
import { useFlareWorkbenchUi } from "../../composables/useFlareWorkbenchUi";
import type { ConversationFilter } from "../../composables/sdk";
import { useFlareI18n } from "../shared/i18n";
import { useFlareUpdates } from "../state/update";
import { useConversationListModel } from "../state/useConversationListModel";
import { ConversationListPanel } from "../ui/components";

const router = useRouter();
const workbenchUi = useFlareWorkbenchUi();
const updates = useFlareUpdates();
const { t } = useFlareI18n();
const {
  sdk,
  conversationSearchOpen,
  conversationSearchQuery,
  filterOptions,
  activeFilter,
  conversationItems,
  runtimeStatus,
  applyFilter,
} = useConversationListModel();

const conversationStatusText = computed(() => t("workbench.convStats", {
  total: conversationItems.value.length,
  pinned: conversationItems.value.filter((item) => item.pinned).length,
  state: sdk.connectionPhase.value,
}));

async function selectConversation(id: string): Promise<void> {
  const selecting = sdk.selectConversation(id);
  await router.push({ name: "chat" });
  await selecting;
}

async function onFilterChange(filter: string): Promise<void> {
  await applyFilter(filter as ConversationFilter);
}

async function runConversationAction(action: FlareConversationAction, id: string): Promise<void> {
  await sdk.runConversationOperation(action, id);
  if (action === "delete" && sdk.activeConversationId.value === id) {
    await router.replace({ name: "conversations" });
  }
}
</script>

<template>
  <ConversationListPanel
    v-model:search-open="conversationSearchOpen"
    v-model:search-query="conversationSearchQuery"
    class="workbench-conversations-route"
    :items="conversationItems"
    :active-id="sdk.activeConversationId.value"
    eyebrow="Flare Core"
    :title="t('conversation.title')"
    :meta="conversationStatusText"
    :label="t('conversation.title')"
    :filter-options="filterOptions"
    :active-filter="activeFilter"
    :filter-label="t('conversation.filtersLabel')"
    :search-placeholder="t('conversation.searchPlaceholder')"
    :search-label="t('workbench.searchConv')"
    :close-search-label="t('workbench.closeConvSearch')"
    :create-label="t('workbench.newChat')"
    :more-label="t('workbench.moreConvActions')"
    :more-dot="updates.badge.value"
    :loading="sdk.conversationSyncing.value"
    :status="runtimeStatus"
    :loading-title="t('connection.syncConversations')"
    :loading-description="t('connection.syncDetail')"
    :empty-title="t('conversation.emptyTitle')"
    :empty-description="t('conversation.emptyHint')"
    :empty-action-label="t('conversation.startChat')"
    :no-results-title="t('conversation.emptySearchTitle')"
    :no-results-description="t('conversation.emptySearchHint')"
    :pinned-section-label="t('conversation.pinnedSection')"
    :all-section-label="t('conversation.allSection')"
    @filter-change="onFilterChange"
    @select="selectConversation"
    @action="runConversationAction"
    @create="workbenchUi.openStartChat()"
    @more="workbenchUi.openMore()"
  />
</template>
