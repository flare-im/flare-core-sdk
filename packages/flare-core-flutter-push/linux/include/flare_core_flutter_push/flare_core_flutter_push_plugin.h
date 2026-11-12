#ifndef FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_H_
#define FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

// 桌面系统通知（Linux）：引擎的系统展示面经 org.freedesktop.Notifications 弹出，点击回到 Dart。
FLUTTER_PLUGIN_EXPORT void flare_core_flutter_push_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_H_
