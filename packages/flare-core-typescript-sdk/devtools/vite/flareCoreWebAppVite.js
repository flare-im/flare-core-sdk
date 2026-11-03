import crypto from "node:crypto";
import fs from "node:fs";
import { promises as fsPromises } from "node:fs";
import path from "node:path";
const wasmBindingPublicPath = "/flare-core-wasm/";
const wasmBindingFiles = /* @__PURE__ */ new Set(["flare_im_core_sdk.js", "flare_im_core_sdk_bg.wasm"]);
const vueImUiAssetPublicPath = "/flare-im-ui-assets/";
const devMediaApiProxyPrefix = "/__flare-media-api";
const devStorageProxyPrefix = "/__flare-storage";
const defaultMediaApiTarget = "http://127.0.0.1:50050";
const defaultStorageProxyTargets = [
  "http://127.0.0.1:29000",
  "http://localhost:29000",
  "http://127.0.0.1:9000",
  "http://localhost:9000"
];
function pickEnv(env, key, fallback) {
  const value = env[key];
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}
function pickEnvList(env, key, fallback) {
  const value = env[key];
  if (typeof value !== "string" || !value.trim()) return [...fallback];
  return value.split(",").map((item) => item.trim()).filter(Boolean);
}
function createMediaProxyTable(env) {
  const apiPrefix = pickEnv(env, "VITE_MEDIA_API_PROXY_PREFIX", devMediaApiProxyPrefix).replace(/\/$/, "");
  const storagePrefix = pickEnv(env, "VITE_STORAGE_PROXY_PREFIX", devStorageProxyPrefix).replace(/\/$/, "");
  const storageTargets = pickEnvList(env, "VITE_STORAGE_PROXY_TARGETS", defaultStorageProxyTargets);
  return {
    [apiPrefix]: {
      target: pickEnv(env, "VITE_MEDIA_API_PROXY_TARGET", defaultMediaApiTarget),
      changeOrigin: true,
      rewrite: (requestPath) => requestPath.slice(apiPrefix.length) || "/"
    },
    [storagePrefix]: {
      target: storageTargets[0] ?? defaultStorageProxyTargets[0],
      changeOrigin: true,
      rewrite: (requestPath) => requestPath.slice(storagePrefix.length) || "/"
    }
  };
}
// WASM 产物两个文件都不带内容哈希名，而生产 nginx 给 *.wasm 打了一年 immutable：
// 发新 WASM 后浏览器继续用旧 .wasm 配新胶水 JS，表现为
// "wasm.__wasm_bindgen_func_elem_NNNN is not a function"（生产实测）。
// 这里按两个文件的内容算一个构建 id 注入 import.meta.env.VITE_FLARE_WASM_BUILD_ID，
// 加载端把它挂进查询串，缓存键随内容变，旧缓存自然失效。
function wasmBindingBuildId(wasmBindingRoot) {
  const hash = crypto.createHash("sha1");
  for (const fileName of Array.from(wasmBindingFiles).sort()) {
    const filePath = path.join(wasmBindingRoot, fileName);
    if (!fs.existsSync(filePath)) return "";
    hash.update(fileName);
    hash.update(fs.readFileSync(filePath));
  }
  return hash.digest("hex").slice(0, 12);
}
function flareWasmBindingAssets(wasmBindingRoot, appDir) {
  return {
    name: "flare-wasm-binding-assets",
    configureServer(server) {
      server.middlewares.use((request, response, next) => {
        const requestPath = request.url?.split("?")[0] ?? "";
        if (!requestPath.startsWith(wasmBindingPublicPath)) {
          next();
          return;
        }
        const fileName = decodeURIComponent(requestPath.slice(wasmBindingPublicPath.length));
        if (!wasmBindingFiles.has(fileName)) {
          response.statusCode = 404;
          response.end("Unknown Flare WASM binding asset");
          return;
        }
        const filePath = path.join(wasmBindingRoot, fileName);
        response.setHeader(
          "Content-Type",
          fileName.endsWith(".wasm") ? "application/wasm" : "text/javascript; charset=utf-8"
        );
        response.setHeader("Cache-Control", "no-cache");
        fs.createReadStream(filePath).on("error", (error) => {
          response.statusCode = error.code === "ENOENT" ? 404 : 500;
          response.end(`Unable to read Flare WASM binding asset ${fileName}: ${error.message}`);
        }).pipe(response);
      });
    },
    async writeBundle(options) {
      const outputDir = options.dir ? path.resolve(options.dir) : path.resolve(appDir, "dist");
      const targetDir = path.join(outputDir, wasmBindingPublicPath.replace(/^\/|\/$/g, ""));
      await fsPromises.mkdir(targetDir, { recursive: true });
      await Promise.all(
        Array.from(
          wasmBindingFiles,
          (fileName) => fsPromises.copyFile(path.join(wasmBindingRoot, fileName), path.join(targetDir, fileName))
        )
      );
    }
  };
}
function contentTypeForAsset(filePath) {
  if (filePath.endsWith(".webp")) return "image/webp";
  if (filePath.endsWith(".json")) return "application/json; charset=utf-8";
  return "application/octet-stream";
}
function resolveSafeAssetPath(root, requestPath) {
  const relativePath = decodeURIComponent(requestPath).replace(/^\/+/, "");
  const resolved = path.resolve(root, relativePath);
  const normalizedRoot = path.resolve(root);
  if (resolved !== normalizedRoot && !resolved.startsWith(`${normalizedRoot}${path.sep}`)) {
    return null;
  }
  return resolved;
}
function flareVueImUiAssets(vueImUiAssetRoot, appDir) {
  return {
    name: "flare-vue-im-ui-assets",
    configureServer(server) {
      server.middlewares.use((request, response, next) => {
        const requestPath = request.url?.split("?")[0] ?? "";
        if (!requestPath.startsWith(vueImUiAssetPublicPath)) {
          next();
          return;
        }
        const assetPath = resolveSafeAssetPath(
          vueImUiAssetRoot,
          requestPath.slice(vueImUiAssetPublicPath.length)
        );
        if (!assetPath) {
          response.statusCode = 400;
          response.end("Invalid Flare UI asset path");
          return;
        }
        response.setHeader("Content-Type", contentTypeForAsset(assetPath));
        response.setHeader("Cache-Control", "public, max-age=31536000, immutable");
        fs.createReadStream(assetPath).on("error", (error) => {
          response.statusCode = error.code === "ENOENT" ? 404 : 500;
          response.end(`Unable to read Flare UI asset: ${error.message}`);
        }).pipe(response);
      });
    },
    async writeBundle(options) {
      const outputDir = options.dir ? path.resolve(options.dir) : path.resolve(appDir, "dist");
      const targetDir = path.join(outputDir, vueImUiAssetPublicPath.replace(/^\/|\/$/g, ""));
      await fsPromises.rm(targetDir, { force: true, recursive: true });
      await fsPromises.cp(vueImUiAssetRoot, targetDir, { recursive: true });
    }
  };
}
function normalizedBuildId(id) {
  return id.replace(/\\/g, "/");
}
function flareVueImUiChunk(id) {
  const normalized = normalizedBuildId(id);
  // 既认包名也认解析后的目录名：本地开发用 file: 依赖 / alias 指向源码目录，
  // Vite 解析出来的 id 是真实路径（.../flare-im-design/vue-im-ui/...），里面
  // 根本没有 "@flare-im/vue-ui" 这一段。只匹配包名的话，这里的所有分包规则
  // 都静默失效，整个 UI 库落进 vendor —— 表现是构建过体积门禁不过，而不是报错。
  if (!normalized.includes("@flare-im/vue-ui") && !normalized.includes("/vue-im-ui/")) {
    return void 0;
  }
  if (normalized.includes("/app/components/FlareSdkLabPanel") || normalized.includes("/app/message-enhancements/")) {
    return "flare-im-app";
  }
  if (normalized.includes("/components/message-preview/") || normalized.includes("/app/infrastructure/media/")) {
    return "flare-im-app";
  }
  if (normalized.includes("/components/shell/FlareDiagnosticsConsole")) {
    return "flare-im-app";
  }
  if (normalized.includes("/components/messages/") || normalized.includes("/components/composer/") || normalized.includes("/app/components/FlareChatWorkspace")) {
    return "flare-im-app";
  }
  if (normalized.includes("/app/components/") || normalized.includes("/components/shell/")) {
    return "flare-im-app";
  }
  return void 0;
}
// 未被下面任何显式规则认领的第三方包，按**包名**兜底分组。
//
// 原先它们全部落进 Vite 默认的单个 vendor chunk：规则枚举得再细，只要漏掉一个
// 大包（比如图标库从 @vicons 换到 lucide 之后），vendor 就会重新胀回去，而症状
// 是"体积门禁不过"，指不到是哪个包。按包名分组让新增依赖天然分散，也让超标时
// 一眼看得出是谁。
function fallbackVendorChunk(normalized) {
  const m = normalized.match(/node_modules\/((?:@[^/]+\/)?[^/]+)/);
  return m ? `vendor-${m[1].replace(/[@/]/g, "-")}` : void 0;
}

function nodeModuleChunk(id) {
  const normalized = normalizedBuildId(id);
  if (!normalized.includes("node_modules")) {
    return void 0;
  }
  if (normalized.includes("node_modules/lucide-vue-next")) {
    return "icon-runtime";
  }
  if (normalized.includes("node_modules/protobufjs") || normalized.includes("node_modules/markdown-it")) {
    return "content-runtime";
  }
  if (normalized.includes("node_modules/@vicons")) {
    return "icon-runtime";
  }
  if (normalized.includes("node_modules/vue/") || normalized.includes("node_modules/@vue/") || normalized.includes("node_modules/vue-router")) {
    return "vue-runtime";
  }
  if (normalized.includes("node_modules/@css-render") || normalized.includes("node_modules/css-render") || normalized.includes("node_modules/vooks") || normalized.includes("node_modules/vueuc") || normalized.includes("node_modules/treemate") || normalized.includes("node_modules/seemly") || normalized.includes("node_modules/evtd") || normalized.includes("node_modules/vdirs") || normalized.includes("node_modules/async-validator") || normalized.includes("node_modules/date-fns") || normalized.includes("node_modules/lodash-es")) {
    return "naive-ui";
  }
  if (normalized.includes("node_modules/naive-ui")) {
    // naive-ui 的组件互相引用，按子路径拆 chunk 必然形成循环依赖，
    // 表现为运行时 "Cannot access 've' before initialization" —— 整页白屏。
    // 构建器会直接报 "Circular chunk"。整包一个 chunk 是唯一安全的切法。
    return "naive-ui";
  }
  return fallbackVendorChunk(normalized);
}
function createFlareCoreWebAppViteConfig(options) {
  const appDir = options.appDir;
  const repoRoot = path.resolve(appDir, "../../..");
  const wasmBindingRoot = path.resolve(repoRoot, "flare-core-sdk-engine/bindings/wasm/pkg");
  const typeScriptSdkRoot = path.resolve(appDir, "../../packages/flare-core-typescript-sdk/src");
  const vueImUiRoot = path.resolve(repoRoot, "flare-im-design/packages/vue-im-ui/src");
  // Emoji/sticker resources are centralized at the flare-im-design top level
  // (single cross-platform source), served here at /flare-im-ui-assets/.
  const vueImUiAssetRoot = path.resolve(repoRoot, "flare-im-design/assets/emoji-sticker");
  // kit 在**另一个仓**（flare-im-design）。单独 clone 本仓的 main 里它不存在，
  // 那时必须让 @flare-im/vue-ui 从 node_modules 的 npm 包解析 —— alias 到一个
  // 不存在的目录只会报「找不到模块」，看不出根因是依赖模式没切。
  //
  // 同级仓存在 → dev 语义（改 kit 立刻生效）；不存在 → published 语义。
  // 显式设了 FLARE_USE_PUBLISHED_KIT 则以它为准（用于在本工作区验证发布物）。
  //
  // @flare-im/sdk 不需要这套判定：它和示例 app 在同一个仓里，永远都在。
  const explicitKitMode = process.env.FLARE_USE_PUBLISHED_KIT;
  const usePublishedKit =
    explicitKitMode === "true" || (explicitKitMode !== "false" && !fs.existsSync(vueImUiRoot));
  const kitAliases = usePublishedKit
    ? []
    : [
      {
        find: "@flare-im/vue-ui/style.css",
        replacement: path.join(vueImUiRoot, "design-system/styles/index.css")
      },
      {
        find: "@flare-im/vue-ui/theme",
        replacement: path.join(vueImUiRoot, "design-system/theme/index.ts")
      },
      {
        find: "@flare-im/vue-ui/i18n",
        replacement: path.join(vueImUiRoot, "shared/i18n/index.ts")
      },
      {
        find: "@flare-im/vue-ui/components",
        replacement: path.join(vueImUiRoot, "components/index.ts")
      },
      {
        find: "@flare-im/vue-ui/utils",
        replacement: path.join(vueImUiRoot, "utils/index.ts")
      },
      // 更具体的子路径必须排在 `/composables` **前面**：字符串 find 是前缀匹配，
      // 否则 `/composables/sdk` 会先命中 `/composables` 被拼成
      // `composables/index.ts/sdk`，构建报 ENOTDIR。
      {
        find: "@flare-im/vue-ui/composables/sdk",
        replacement: path.join(vueImUiRoot, "composables/sdk.ts")
      },
      {
        find: "@flare-im/vue-ui/composables",
        replacement: path.join(vueImUiRoot, "composables/index.ts")
      },
      {
        find: "@flare-im/vue-ui/contracts",
        replacement: path.join(vueImUiRoot, "shared/contracts/index.ts")
      },
      {
        find: "@flare-im/vue-ui/icon-glyphs",
        replacement: path.join(vueImUiRoot, "shared/icon-glyphs.ts")
      },
      {
        find: "@flare-im/vue-ui",
        replacement: path.join(vueImUiRoot, "index.ts")
      },
      ];
  return options.defineConfig(({ mode }) => {
    const env = options.loadEnv(mode, appDir, "VITE_");
    return {
      plugins: [
        options.vuePlugin(),
        flareWasmBindingAssets(wasmBindingRoot, appDir),
        flareVueImUiAssets(vueImUiAssetRoot, appDir)
      ],
      define: {
        "import.meta.env.VITE_FLARE_WASM_BUILD_ID": JSON.stringify(wasmBindingBuildId(wasmBindingRoot)),
        ...(options.extraDefine ?? {})
      },
      resolve: {
        alias: [
          ...options.extraAliases ?? [],
          {
            find: "@flare-im/sdk/web",
            replacement: path.join(typeScriptSdkRoot, "adapters/web/index.ts")
          },
          {
            find: "@flare-im/sdk/tauri",
            replacement: path.join(typeScriptSdkRoot, "adapters/tauri/index.ts")
          },
          {
            find: "@flare-im/sdk/transport",
            replacement: path.join(typeScriptSdkRoot, "adapters/_shared/transportProfile.ts")
          },
          {
            find: /^@flare-im\/sdk\/(.+)$/,
            replacement: path.join(typeScriptSdkRoot, "$1")
          },
          ...kitAliases,
          {
            find: "@flare-im/sdk",
            replacement: path.join(typeScriptSdkRoot, "index.ts")
          }
        ],
        dedupe: ["vue", "vue-router", "naive-ui", "@vicons/ionicons5", "markdown-it", "protobufjs"]
      },
      server: {
        port: options.serverPort,
        strictPort: false,
        fs: {
          allow: [repoRoot]
        },
        proxy: createMediaProxyTable(env)
      },
      build: {
        rollupOptions: {
          output: {
            manualChunks(id) {
              const normalizedId = normalizedBuildId(id);
              const nodeChunk = nodeModuleChunk(normalizedId);
              if (nodeChunk) {
                return nodeChunk;
              }
              const vueImUiChunk = flareVueImUiChunk(normalizedId);
              if (vueImUiChunk) {
                return vueImUiChunk;
              }
              if (normalizedId.includes("/views/SdkLabView")) {
                return "sdk-lab";
              }
              if (
                normalizedId.includes("@flare-im/sdk") ||
                normalizedId.includes("/flare-core-typescript-sdk/") ||
                normalizedId.includes("flare-core-sdk-engine/bindings")
              ) {
                return "flare-sdk";
              }
              return void 0;
            }
          }
        }
      }
    };
  });
}
export {
  createFlareCoreWebAppViteConfig
};
