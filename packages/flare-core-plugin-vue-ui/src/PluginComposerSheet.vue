<script setup lang="ts">
// 通用插件入口:「+」面板里没有原生处理器的插件项。Kit 底部面板里画这个 composer-action 贡献
// (标题、字段、块、动作都来自贡献的文档),动作经 Core 带会话 ID 调用。贡献带输入时,收集表单的
// 那个动作(创建)直接在面板里用 Kit PluginForm 收集,不再弹第二层面板;Core 校验不过时把
// formErrors 交回表单。卡片由平台以用户名义代发:结果带 data.posted 时把它交给宿主定位,卡片本身
// 随会话推送进时间线,这里从不发消息。
import { computed, inject, onBeforeUnmount, ref, shallowRef, watch } from "vue";
import {
  FlareBottomSheet, FlareDangerConfirm, FlarePluginForm, FlarePluginView, useFlareI18n,
  type FlarePluginAction, type FlarePluginActionPayload, type FlarePluginFormError, type FlarePluginInput,
  type FlarePluginMember, type FlarePluginResolveUser, type FlarePluginViewModel,
} from "@flare-im/vue-ui";
import type { PluginMessageEnvelope } from "@flare-im/sdk/plugin-ui";
import { pluginUiDirectoryKey, pluginUiErrorTextKey, pluginUiSessionKey } from "./context";
import { type ComposerPluginItem, type PluginPostedCard } from "./composerMenu";
import { pluginPagePostedCard } from "./pluginPage";

const props = defineProps<{
  /** The tapped plugin item; the sheet is open while there is one. */
  item: ComposerPluginItem | null;
  conversationId: string;
  /** Overrides the provided directory's conversation members (members inputs). */
  members?: FlarePluginMember[];
  /** Overrides the provided directory's resolver. */
  resolveUser?: FlarePluginResolveUser;
}>();
const emit = defineEmits<{
  close: [];
  /** The action created something whose card Core posted; the card arrives with the conversation's next push. */
  posted: [card: PluginPostedCard];
}>();

const { t } = useFlareI18n();
const session = inject(pluginUiSessionKey, ref(null));
const directory = inject(pluginUiDirectoryKey, {});
const errorText = inject(pluginUiErrorTextKey, () => undefined);
const members = computed(() => props.members ?? directory.members?.() ?? []);
const resolver = computed(() => props.resolveUser ?? directory.resolveUser);
const view = shallowRef<FlarePluginViewModel>({ available: false, title: "", fields: [], actions: [] });
const busyActionId = ref<string>();
const error = ref("");
const formErrors = shallowRef<FlarePluginFormError[]>([]);
/** Moved once per finished action, after its error and formErrors are set (kit settleToken). */
const settleToken = ref(0);
const confirming = shallowRef<{ action: FlarePluginAction; payload: FlarePluginActionPayload } | null>(null);
let generation = 0;
onBeforeUnmount(() => { generation++; });

/** The contribution's own document, rendered for this conversation. */
function message(item: ComposerPluginItem): PluginMessageEnvelope {
  return { pluginId: item.pluginId, contributionId: item.contributionId, schemaVersion: 1, summary: item.label,
    payload: { conversationId: props.conversationId } };
}

/**
 * The action that collects the contribution's inputs (its create action): the primary one when
 * several do. The sheet is then that action's form; without one the view is drawn as it is.
 */
const formAction = computed<FlarePluginAction | undefined>(() => {
  if (!view.value.available || !view.value.inputs?.length) return undefined;
  const collecting = view.value.actions.filter((action) => action.form?.length);
  return collecting.find((action) => action.style === "primary") ?? collecting[0];
});
const formInputs = computed<FlarePluginInput[]>(() => (formAction.value?.form ?? [])
  .map((id) => view.value.inputs?.find((input) => input.id === id))
  .filter((input): input is FlarePluginInput => Boolean(input)));
/** What the document shows besides the form (fields, blocks), drawn above it without its keys. */
const preface = computed<FlarePluginViewModel | null>(() => (view.value.fields.length || view.value.blocks?.length
  ? { ...view.value, actions: [] } : null));

async function load(): Promise<void> {
  const mine = ++generation, host = session.value, item = props.item;
  busyActionId.value = undefined; error.value = ""; formErrors.value = []; confirming.value = null;
  view.value = { available: false, title: item?.label ?? "", fields: [], actions: [] };
  if (!host || !item) return;
  const result = await host.present(message(item), undefined, "composer-action");
  if (mine === generation) view.value = result;
}

async function invoke(id: string, payload: FlarePluginActionPayload): Promise<void> {
  const host = session.value, item = props.item, mine = generation;
  if (!host || !item || busyActionId.value || !view.value.available) return;
  busyActionId.value = id; error.value = ""; formErrors.value = [];
  let done = false;
  try {
    const outcome = await host.invokeAction(message(item), id, { conversationId: props.conversationId, userGesture: true,
      ...(payload.formValues ? { formValues: payload.formValues } : {}), ...(payload.selection ? { selection: payload.selection } : {}) });
    if (mine !== generation) return;
    if (outcome.kind === "formErrors") { formErrors.value = outcome.errors; return; }
    if (outcome.kind === "operation") {
      if (outcome.response.success === false) { error.value = t("pluginRuntime.rejected"); return; }
      const posted = outcome.response.success === true ? pluginPagePostedCard(outcome.response.data, props.conversationId) : null;
      if (!posted) return;
      emit("posted", posted);
    }
    done = mine === generation;
  } catch (failure) {
    if (mine === generation) error.value = errorText(failure) ?? t("pluginRuntime.unavailable");
  } finally {
    // The outcome is set: settle it, then let the keys go.
    if (mine === generation) { settleToken.value++; busyActionId.value = undefined; }
  }
  if (done) emit("close");
}

/** A key of the drawn view; the kit has already asked its confirmation and collected its form. */
function action(id: string, payload?: FlarePluginActionPayload): void {
  void invoke(id, payload ?? {});
}
/** The form's submit: confirmed first when the action asks to be. */
function submitForm(values: Record<string, unknown>): void {
  const target = formAction.value;
  if (!target || busyActionId.value) return;
  const payload = { formValues: values };
  if (target.confirm) confirming.value = { action: target, payload };
  else void invoke(target.id, payload);
}
function confirmed(): void {
  const next = confirming.value;
  confirming.value = null;
  if (next) void invoke(next.action.id, next.payload);
}
function close(): void {
  if (!busyActionId.value) emit("close");
}

watch(() => [props.item, props.conversationId, session.value], () => { void load(); }, { immediate: true });
</script>

<template>
  <FlareBottomSheet :open="Boolean(item)" :title="view.title || item?.label || ''" :dismissible="!busyActionId" @close="close">
    <template v-if="formAction">
      <FlarePluginView v-if="preface" :view="preface" embedded inset="sheetTop" :resolve-user="resolver" />
      <FlarePluginForm
        :inputs="formInputs"
        :errors="formErrors"
        :submit-label="formAction.label"
        :busy="Boolean(busyActionId)"
        :error="error || undefined"
        :members="members"
        @submit="submitForm"
        @cancel="close"
      />
      <FlareDangerConfirm
        v-if="confirming"
        :open="Boolean(confirming)"
        :title="confirming.action.label"
        :description="confirming.action.confirm ?? ''"
        target=""
        :confirm-text="confirming.action.label"
        @confirm="confirmed"
        @cancel="confirming = null"
      />
    </template>
    <FlarePluginView
      v-else
      :view="view"
      embedded
      inset="sheet"
      :busy-action-id="busyActionId"
      :error="error || undefined"
      :form-errors="formErrors"
      :settle-token="settleToken"
      :resolve-user="resolver"
      :members="members"
      @action="action"
    />
  </FlareBottomSheet>
</template>
