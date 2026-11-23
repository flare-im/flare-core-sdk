import { fileURLToPath, URL } from "node:url";
import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vitest/config";

// The peers come from their sibling sources, as in the reference apps (see tsconfig.json).
const kit = (path: string) => fileURLToPath(new URL(`../../../flare-im-design/packages/vue-im-ui/src/${path}`, import.meta.url));

export default defineConfig({
  plugins: [vue()],
  resolve: {
    // One Vue (and one naive-ui) for this package, the kit sources and the kit's own dependencies.
    dedupe: ["vue", "naive-ui"],
    alias: [
      { find: "@lucide/vue", replacement: fileURLToPath(new URL("../../../flare-im-design/node_modules/@lucide/vue/dist/esm/lucide-vue.mjs", import.meta.url)) },
      { find: "@flare-im/sdk/plugin-ui", replacement: fileURLToPath(new URL("../flare-core-typescript-sdk/src/plugin-ui/index.ts", import.meta.url)) },
      { find: "@flare-im/vue-ui/i18n", replacement: kit("shared/i18n/index.ts") },
      { find: "@flare-im/vue-ui/composables", replacement: kit("composables/index.ts") },
      { find: /^@flare-im\/vue-ui$/, replacement: kit("index.ts") },
    ],
  },
  test: {
    include: ["test/**/*.test.ts"],
    environment: "happy-dom",
    // The kit's dependencies must use this package's Vue too; Node externalization would bypass dedupe.
    server: { deps: { inline: [/@lucide\/vue/, /naive-ui/, /vueuc/, /vooks/, /vdirs/, /@css-render\/vue3-ssr/] } },
  },
});
