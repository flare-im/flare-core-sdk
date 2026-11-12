import { contextBridge, ipcRenderer } from "electron";

type FlareDesktopInfo = {
  name: string;
  version: string;
  platform: NodeJS.Platform;
  arch: string;
  isPackaged: boolean;
};

contextBridge.exposeInMainWorld("flareNativeMediaActions", {
  revealDownloadedFile(filePath: string): Promise<boolean> {
    return ipcRenderer.invoke("flare:reveal-downloaded-file", filePath);
  },
});

contextBridge.exposeInMainWorld("flareDesktop", {
  runtime: "electron",
  platform: process.platform,
  versions: {
    electron: process.versions.electron,
    chrome: process.versions.chrome,
  },
  getAppInfo(): Promise<FlareDesktopInfo> {
    return ipcRenderer.invoke("flare:app-info");
  },
  setUnreadCount(count: number): Promise<boolean> {
    return ipcRenderer.invoke("flare:set-unread-count", count);
  },
});
