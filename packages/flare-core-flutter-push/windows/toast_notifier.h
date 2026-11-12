#ifndef FLARE_CORE_FLUTTER_PUSH_TOAST_NOTIFIER_H_
#define FLARE_CORE_FLUTTER_PUSH_TOAST_NOTIFIER_H_

#include <windows.h>

// WinRT 的 ABI 头在宿主的 /W4 /WX 下会报出与本插件无关的告警。
#pragma warning(push, 0)
#include <windows.ui.notifications.h>
#include <wrl/client.h>
#pragma warning(pop)

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "notification_backend.h"

namespace flare_push {

// toast 通知（Windows 10 起）：一个会话一条，tag 取合并键、group 固定，同一会话的新 toast 替换通知中心里的旧的；
// 不响铃的不弹出（SuppressPopup）、不出声。撤除按 tag 与 group 从通知中心移除；全撤只撤本插件这一组。
//
// 只用 WRL 与 ABI 头，不用 C++/WinRT：宿主按 _HAS_EXCEPTIONS=0 编译。
//
// 点击（Activated）只在应用还在运行时回来：没有注册 COM 激活器，进程退出后点通知中心里的旧通知不会拉起应用。
class ToastNotifier : public NotificationBackend {
 public:
  // 能出 toast 时给出实例：打包（MSIX）的应用用包的身份；没打包的要有注册过的 AppUserModelID（[app_id]，
  // 空时用进程自己设的那个）。没有身份、身份没有注册（读不出通知设置）时为 nullptr，调用方退回托盘。
  static std::unique_ptr<ToastNotifier> Create(
      const std::wstring& app_id, std::shared_ptr<TapMailbox> mailbox);

  ~ToastNotifier() override;

  ToastNotifier(const ToastNotifier&) = delete;
  ToastNotifier& operator=(const ToastNotifier&) = delete;

  const char* name() const override { return "toast"; }
  bool Allowed() override;
  void Present(const Presentation& presentation) override;
  void Clear(const std::vector<std::string>& collapse_ids) override;
  void ClearAll() override;

 private:
  struct Shown {
    Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotification>
        toast;
    EventRegistrationToken activated{};
  };

  ToastNotifier(
      std::wstring app_id,
      Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotifier>
          notifier,
      Microsoft::WRL::ComPtr<
          ABI::Windows::UI::Notifications::IToastNotificationFactory>
          factory,
      Microsoft::WRL::ComPtr<
          ABI::Windows::UI::Notifications::IToastNotificationHistory>
          history,
      std::shared_ptr<TapMailbox> mailbox);

  // 把这条从屏幕上收走并解开它的点击。
  void Forget(Shown& shown);
  void RemoveFromHistory(const std::string& collapse_id);

  // 空：打包的应用，用包的身份。
  std::wstring app_id_;
  Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotifier>
      notifier_;
  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationFactory>
      factory_;
  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationHistory>
      history_;
  std::shared_ptr<TapMailbox> mailbox_;
  std::map<std::string, Shown> shown_;
};

}  // namespace flare_push

#endif  // FLARE_CORE_FLUTTER_PUSH_TOAST_NOTIFIER_H_
