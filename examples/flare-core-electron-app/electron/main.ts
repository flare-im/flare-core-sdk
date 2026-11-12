import { app, BrowserWindow, ipcMain, Menu, nativeImage, shell, Tray } from "electron";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";

type StaticServer = {
  origin: string;
  close: () => Promise<void>;
};

const devServerUrl = process.env.VITE_DEV_SERVER_URL?.trim();
let mainWindow: BrowserWindow | null = null;
let staticServer: StaticServer | null = null;
let tray: Tray | null = null;
let currentUnreadCount = 0;
const baseWindowTitle = "Flare Core";

function contentTypeFor(filePath: string): string {
  if (filePath.endsWith(".html")) return "text/html; charset=utf-8";
  if (filePath.endsWith(".js") || filePath.endsWith(".mjs")) return "text/javascript; charset=utf-8";
  if (filePath.endsWith(".css")) return "text/css; charset=utf-8";
  if (filePath.endsWith(".json")) return "application/json; charset=utf-8";
  if (filePath.endsWith(".wasm")) return "application/wasm";
  if (filePath.endsWith(".webp")) return "image/webp";
  if (filePath.endsWith(".png")) return "image/png";
  if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) return "image/jpeg";
  if (filePath.endsWith(".svg")) return "image/svg+xml; charset=utf-8";
  if (filePath.endsWith(".ico")) return "image/x-icon";
  return "application/octet-stream";
}

function safeResolve(root: string, requestPath: string): string | null {
  const relativePath = decodeURIComponent(requestPath).replace(/^\/+/, "") || "index.html";
  const resolved = path.resolve(root, relativePath);
  const normalizedRoot = path.resolve(root);
  if (resolved !== normalizedRoot && !resolved.startsWith(`${normalizedRoot}${path.sep}`)) {
    return null;
  }
  return resolved;
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    const stat = await fs.promises.stat(filePath);
    return stat.isFile();
  } catch {
    return false;
  }
}

async function resolveStaticFile(root: string, requestPath: string): Promise<string | null> {
  const resolved = safeResolve(root, requestPath);
  if (!resolved) return null;
  if (await fileExists(resolved)) return resolved;

  const hasExtension = path.extname(requestPath) !== "";
  if (hasExtension) return null;

  const indexPath = path.join(root, "index.html");
  return (await fileExists(indexPath)) ? indexPath : null;
}

async function startStaticServer(root: string): Promise<StaticServer> {
  const server = http.createServer(async (request, response) => {
    const requestUrl = new URL(request.url ?? "/", "http://127.0.0.1");
    const filePath = await resolveStaticFile(root, requestUrl.pathname);

    if (!filePath) {
      response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Not found");
      return;
    }

    response.setHeader("Content-Type", contentTypeFor(filePath));
    response.setHeader("Cache-Control", filePath.endsWith("index.html") ? "no-cache" : "public, max-age=31536000, immutable");

    if (request.method === "HEAD") {
      response.end();
      return;
    }

    fs.createReadStream(filePath)
      .on("error", (error) => {
        response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        response.end(`Unable to read static asset: ${error.message}`);
      })
      .pipe(response);
  });

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolve());
  });

  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Unable to bind Electron static server");
  }

  return {
    origin: `http://127.0.0.1:${address.port}`,
    close: () =>
      new Promise<void>((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      }),
  };
}

async function rendererOrigin(): Promise<string> {
  if (devServerUrl) return devServerUrl;
  if (!staticServer) {
    staticServer = await startStaticServer(path.join(app.getAppPath(), "dist"));
  }
  return staticServer.origin;
}

function isTrustedNavigation(url: string, origin: string): boolean {
  if (url === "about:blank") return true;
  try {
    return new URL(url).origin === new URL(origin).origin;
  } catch {
    return false;
  }
}

async function createWindow(): Promise<void> {
  const origin = await rendererOrigin();
  const window = new BrowserWindow({
    width: 1440,
    height: 920,
    minWidth: 1024,
    minHeight: 720,
    show: false,
    title: baseWindowTitle,
    backgroundColor: "#0f1117",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow = window;
  setUnreadCount(currentUnreadCount);

  window.once("ready-to-show", () => window.show());
  window.on("closed", () => {
    if (mainWindow === window) mainWindow = null;
  });

  window.webContents.setWindowOpenHandler(({ url }) => {
    void shell.openExternal(url);
    return { action: "deny" };
  });

  window.webContents.on("will-navigate", (event, url) => {
    if (isTrustedNavigation(url, origin)) return;
    event.preventDefault();
    void shell.openExternal(url);
  });

  await window.loadURL(origin);

  if (process.env.ELECTRON_OPEN_DEVTOOLS === "1") {
    window.webContents.openDevTools({ mode: "detach" });
  }
}

function createTray(): void {
  if (tray) return;
  const icon = nativeImage.createFromPath(path.join(app.getAppPath(), "assets", "icons", "icon.png"));
  const trayIcon = icon.isEmpty() ? nativeImage.createEmpty() : icon.resize({ width: 18, height: 18 });
  tray = new Tray(trayIcon);
  tray.setToolTip(baseWindowTitle);
  tray.setContextMenu(Menu.buildFromTemplate([
    {
      label: "打开 Flare Core",
      click: showMainWindow,
    },
    {
      label: "退出",
      click: () => app.quit(),
    },
  ]));
  tray.on("click", showMainWindow);
  updateTrayUnreadCount(currentUnreadCount);
}

function showMainWindow(): void {
  const window = mainWindow;
  if (!window) {
    void createWindow().then(createTray);
    return;
  }
  if (window.isMinimized()) window.restore();
  window.show();
  window.focus();
}

ipcMain.handle("flare:app-info", () => ({
  name: app.getName(),
  version: app.getVersion(),
  platform: process.platform,
  arch: process.arch,
  isPackaged: app.isPackaged,
}));

ipcMain.handle("flare:reveal-downloaded-file", async (_event, filePath: unknown) => {
  if (typeof filePath !== "string" || !filePath.trim()) return false;
  shell.showItemInFolder(path.resolve(filePath));
  return true;
});

ipcMain.handle("flare:set-unread-count", (_event, count: unknown) => {
  setUnreadCount(typeof count === "number" ? count : 0);
  return true;
});

/** The dock / taskbar badge, window title and tray title: the engine's unread total, sent by the renderer. */
function setUnreadCount(rawCount: number): void {
  const count = Math.max(0, Math.trunc(rawCount));
  currentUnreadCount = count;
  app.setBadgeCount(count);
  const window = mainWindow;
  if (window) {
    window.setTitle(count > 0 ? `${baseWindowTitle} (${count})` : baseWindowTitle);
  }
  updateTrayUnreadCount(count);
}

function updateTrayUnreadCount(count: number): void {
  const currentTray = tray;
  if (!currentTray) return;
  const label = badgeLabel(count);
  currentTray.setTitle(label);
  currentTray.setToolTip(label ? `${baseWindowTitle} - ${label} 条未读` : baseWindowTitle);
}

function badgeLabel(count: number): string {
  if (count <= 0) return "";
  return count > 99 ? "99+" : String(count);
}

app.setName(baseWindowTitle);

app.whenReady()
  .then(async () => {
    await createWindow();
    createTray();
  })
  .catch((error) => {
    console.error("Failed to start Flare Core Electron app", error);
    app.quit();
  });

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    void createWindow();
  }
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("before-quit", () => {
  const server = staticServer;
  staticServer = null;
  if (server) void server.close();
});
