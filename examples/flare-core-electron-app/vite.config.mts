import path from "node:path";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { createFlareCoreWebAppViteConfig } from "@flare-im/sdk/devtools/vite";
import { defineConfig, loadEnv } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default createFlareCoreWebAppViteConfig({
  appDir: __dirname,
  // The renderer is the web build; tell the core it runs inside the Electron shell so CONNECT carries it.
  appDistribution: "electron",
  serverPort: 1433,
  defineConfig,
  loadEnv,
  vuePlugin: vue,
});
