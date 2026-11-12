#ifndef FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_H_
#define FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

#include "notification_backend.h"

namespace flare_push {

// 桌面系统通知的 Flutter 桥（Windows）。通知落成 toast（ToastNotifier），出不了 toast 时退回托盘气泡
// （TrayNotifier）；这里只接通道、把点击带回平台线程、把窗口带到前面。
//
// - 方法通道 im.flare.push/presenter：Dart 调 attach（{windowsAppUserModelId?}，答 {attached, backend}）、detach、
//   present（引擎 NotificationPresentation 的形状）、clear（{collapseIds}）、clearAll、setBadge（没有接任务栏角标，
//   什么也不做）、permissionStatus 与 requestPermission（没有授权这一步：用户在系统设置里关掉了答 denied，否则 granted）。
// - 事件通道 im.flare.push/presenter/taps：点击去向 {conversationId, messageId?, seq?}；没人监听时留着最近一条。
class FlareCoreFlutterPushPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit FlareCoreFlutterPushPlugin(
      flutter::PluginRegistrarWindows* registrar);
  ~FlareCoreFlutterPushPlugin() override;

  FlareCoreFlutterPushPlugin(const FlareCoreFlutterPushPlugin&) = delete;
  FlareCoreFlutterPushPlugin& operator=(const FlareCoreFlutterPushPlugin&) =
      delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  std::optional<LRESULT> HandleWindowMessage(HWND window, UINT message,
                                             WPARAM wparam, LPARAM lparam);
  void Attach(const flutter::EncodableMap* arguments);
  void OnTap(const TapRoute& route);
  void BringToFront() const;
  // 顶层窗口。注册插件时 Flutter 的视图还没挂到顶层窗口下，用到时再找。
  HWND TopLevelWindow() const;

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> taps_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::optional<TapRoute> pending_;
  std::shared_ptr<TapMailbox> mailbox_;
  std::unique_ptr<NotificationBackend> backend_;
  int window_proc_id_ = -1;
};

}  // namespace flare_push

#endif  // FLUTTER_PLUGIN_FLARE_CORE_FLUTTER_PUSH_PLUGIN_H_
