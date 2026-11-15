#ifndef FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// 桌面系统通知（Windows）：引擎的系统展示面落成 toast（没有注册 AppUserModelID 时退回托盘气泡），点击回到 Dart。
FLUTTER_PLUGIN_EXPORT void FlareCoreFlutterPushPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_C_API_H_
