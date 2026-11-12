#ifndef FLARE_CORE_FLUTTER_PUSH_TRAY_NOTIFIER_H_
#define FLARE_CORE_FLUTTER_PUSH_TRAY_NOTIFIER_H_

#include <windows.h>
#include <shellapi.h>

#include <functional>
#include <optional>
#include <string>
#include <vector>

#include "notification_backend.h"

namespace flare_push {

// 托盘气泡：应用没有注册 AppUserModelID、出不了 toast 时的退路（Shell_NotifyIconW）。
//
// 接上后在通知区放一个图标（应用窗口的图标），每条通知是这个图标的一个气泡。限制：同一时间只有一个气泡，新的
// 顶掉旧的，没有「一个会话一条」；撤除只能收走当前这个气泡，系统已经转进通知中心的收不回来；点击只认当前这个气泡；
// 全撤（登出）时去掉托盘图标。Windows 10 起系统把气泡显示成以本程序名义发的 toast。
class TrayNotifier : public NotificationBackend {
 public:
  using TapHandler = std::function<void(const TapRoute&)>;

  // [window] 是顶层窗口：托盘图标的回调消息投给它。
  TrayNotifier(HWND window, TapHandler on_tap);
  ~TrayNotifier() override;

  TrayNotifier(const TrayNotifier&) = delete;
  TrayNotifier& operator=(const TrayNotifier&) = delete;

  const char* name() const override { return "tray"; }
  void Present(const Presentation& presentation) override;
  void Clear(const std::vector<std::string>& collapse_ids) override;
  void ClearAll() override;
  bool HandleWindowMessage(UINT message, WPARAM wparam,
                           LPARAM lparam) override;

 private:
  NOTIFYICONDATAW Base() const;
  HICON Icon() const;
  bool EnsureIcon();
  void RemoveIcon();
  void HideBalloon();

  HWND window_;
  TapHandler on_tap_;
  // 资源管理器重启后托盘要重新加图标。
  UINT taskbar_created_;
  bool added_ = false;
  // 当前这个气泡。
  std::optional<Presentation> current_;
};

}  // namespace flare_push

#endif  // FLARE_CORE_FLUTTER_PUSH_TRAY_NOTIFIER_H_
