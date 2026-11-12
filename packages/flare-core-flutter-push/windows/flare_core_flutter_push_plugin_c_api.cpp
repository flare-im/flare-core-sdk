#include "include/flare_core_flutter_push/flare_core_flutter_push_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flare_core_flutter_push_plugin.h"

void FlareCoreFlutterPushPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flare_push::FlareCoreFlutterPushPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
