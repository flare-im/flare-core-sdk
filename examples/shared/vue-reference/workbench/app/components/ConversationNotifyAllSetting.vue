<script setup lang="ts">
/**
 * "Notify me of all messages" for a group of more than 1000 members, which otherwise alerts only on mentions. The
 * switch moves at once and the core saves it; when the save fails the switch goes back to the core's value and a toast
 * says so. Other conversations draw nothing.
 */
import { computed, ref } from "vue";
import type { Conversation } from "@flare-im/sdk/web";
import { FlareSettingsList } from "@flare-im/vue-ui/components";
import type { FlareSettingsItem, FlareSettingsSection } from "@flare-im/vue-ui/contracts";
import { describeSdkError } from "../../shared/errors/describeSdkError";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareI18n } from "../shared/i18n";
import { useToast } from "../ui/toast";

/** Groups above this many members alert only on mentions unless the member turns this on. */
const LARGE_GROUP_MEMBERS = 1000;
const NOTIFY_ALL_ROW = "notifyAll";

const props = defineProps<{ conversation?: Readonly<Conversation> | null }>();

const sdk = useFlareSdk();
const toast = useToast();
const { t } = useFlareI18n();

/** The choice on its way to the core, shown until the core answers. */
const pending = ref<{ conversationId: string; enabled: boolean } | null>(null);

const largeGroup = computed(() => {
  const conversation = props.conversation;
  return conversation?.conversationType === "group" && Number(conversation.membersCount ?? 0) > LARGE_GROUP_MEMBERS;
});

const enabled = computed(() => {
  const conversation = props.conversation;
  if (!conversation) return false;
  const choice = pending.value;
  return choice?.conversationId === conversation.conversationId ? choice.enabled : Boolean(conversation.notifyAll);
});

const sections = computed<FlareSettingsSection[]>(() => [{
  items: [{ key: NOTIFY_ALL_ROW, label: t("workbench.notifyAll"), kind: "toggle", value: enabled.value }],
  footer: t("workbench.notifyAllHint"),
}]);

async function toggle(item: FlareSettingsItem, on: boolean): Promise<void> {
  const conversationId = props.conversation?.conversationId;
  if (item.key !== NOTIFY_ALL_ROW || !conversationId) return;
  const choice = { conversationId, enabled: on };
  pending.value = choice;
  try {
    await sdk.setConversationNotifyAll(conversationId, on);
  } catch (error) {
    toast.error(describeSdkError(error, t("workbench.notifyAllFailed")));
  } finally {
    // A newer flip of the same switch keeps showing until its own answer.
    if (pending.value === choice) pending.value = null;
  }
}
</script>

<template>
  <FlareSettingsList v-if="largeGroup" class="conversation-notify-all" :sections="sections" @toggle="toggle" />
</template>

<style scoped>
.conversation-notify-all {
  min-width: 0;
}
</style>
