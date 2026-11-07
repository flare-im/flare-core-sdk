<script setup lang="ts">
// Reference-app authentication screen. Authentication flows are not kit API
// (PUBLIC_API.md); this screen composes public kit components only. It asks for
// the identity alone: where to connect is the build's access configuration, and
// the SDK issues the connect token.
import { useId } from "vue";
import { LogInOutline } from "@flare-im/vue-ui/icon-glyphs";
import { useFlareI18n } from "@flare-im/vue-ui/i18n";
import { FlareAuthShell, FlareButton, FlareFormField, FlareIcon, FlareInput } from "@flare-im/vue-ui/components";

const props = withDefaults(defineProps<{
  userId: string;
  loading?: boolean;
  /** Nothing to sign in to (the build has no access configuration); the host says why. */
  disabled?: boolean;
}>(), {
  loading: false,
  disabled: false,
});

const emit = defineEmits<{
  (event: "update:userId", value: string): void;
  (event: "login"): void;
}>();

const authId = useId();
const userHintId = `flare-auth-user-hint-${authId}`;
const { t } = useFlareI18n();

function submit(): void {
  if (!props.loading && !props.disabled && props.userId.trim()) emit("login");
}
</script>

<template>
  <FlareAuthShell
    class="auth-screen"
    :product="t('login.brandTitle')"
    :tagline="t('login.brandSubtitle')"
    :headline="t('login.brandHeadline')"
    :description="t('login.brandDescription')"
    :title="t('login.welcomeTitle')"
    :subtitle="t('login.welcomeHint')"
    :footer="t('login.securityNote')"
  >
    <form class="auth-panel__form" :aria-busy="loading || undefined" @submit.prevent="submit">
      <FlareFormField :label="t('login.userIdLabel')">
        <FlareInput
          size="lg"
          class="auth-user-input"
          :model-value="userId"
          :placeholder="t('login.userIdPlaceholder')"
          :aria-label="t('login.userIdLabel')"
          :aria-describedby="userHintId"
          :disabled="loading || disabled"
          autocomplete="username"
          name="userId"
          @update:model-value="emit('update:userId', $event)"
          @submit="submit"
        >
          <template #prefix><FlareIcon name="person" :size="18" /></template>
        </FlareInput>
      </FlareFormField>
      <p :id="userHintId" class="auth-hint">{{ t('login.userIdHint') }}</p>
      <FlareButton class="auth-login-btn" type="submit" size="lg" block :icon="LogInOutline" :loading="loading" :disabled="loading || disabled || !userId.trim()">
        {{ t('login.loginButton') }}
      </FlareButton>
    </form>
  </FlareAuthShell>
</template>
