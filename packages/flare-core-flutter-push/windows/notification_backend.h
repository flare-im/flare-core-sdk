#ifndef FLARE_CORE_FLUTTER_PUSH_NOTIFICATION_BACKEND_H_
#define FLARE_CORE_FLUTTER_PUSH_NOTIFICATION_BACKEND_H_

#include <windows.h>

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace flare_push {

// 一条要展示的通知：引擎 NotificationPresentation 里本插件用到的字段。
struct Presentation {
  std::string collapse_id;
  std::string thread_id;
  std::string conversation_id;
  std::string message_id;
  int64_t seq = 0;
  std::string title;
  std::string body;
  bool sound = false;
  std::string channel;

  // 不响铃的（静默替换、quiet 渠道）不弹出、不出声，只进通知中心：一阵连发的消息只在第一条弹出。
  bool passive() const { return !sound || channel == "quiet"; }
};

// 点击要去的会话；摘要通知的 conversation_id 为空。
struct TapRoute {
  std::string conversation_id;
  std::string message_id;
  int64_t seq = 0;
};

// 投给顶层窗口的私有消息：toast 的点击（WinRT 线程上回来，经信箱转回平台线程）与托盘图标的回调。
constexpr UINT kTapMessage = WM_APP + 0x0F46;
constexpr UINT kTrayMessage = WM_APP + 0x0F47;

// toast 的点击在 WinRT 的线程池线程上回来：先放进信箱，再给顶层窗口投一条消息，平台线程上取出来交给 Dart。
class TapMailbox {
 public:
  // 顶层窗口；nullptr 时点击只留在信箱里。
  void SetWindow(HWND window);
  // 任意线程。
  void Post(const TapRoute& route);
  // 平台线程。
  std::vector<TapRoute> Take();

 private:
  std::mutex lock_;
  HWND window_ = nullptr;
  std::vector<TapRoute> routes_;
};

// 一种把通知落到屏幕上的方式：toast，或托盘气泡。都在平台线程上调。
class NotificationBackend {
 public:
  virtual ~NotificationBackend() = default;

  // 诊断用的名字：toast 或 tray。
  virtual const char* name() const = 0;
  // 用户在系统设置里有没有关掉本应用的通知。
  virtual bool Allowed() { return true; }
  virtual void Present(const Presentation& presentation) = 0;
  virtual void Clear(const std::vector<std::string>& collapse_ids) = 0;
  // 撤掉本插件出的全部通知。
  virtual void ClearAll() = 0;
  // 顶层窗口的消息；处理掉、别人不用再看时返回 true。
  virtual bool HandleWindowMessage(UINT message, WPARAM wparam, LPARAM lparam) {
    (void)message;
    (void)wparam;
    (void)lparam;
    return false;
  }
};

// UTF-8 转 UTF-16。
std::wstring Utf16(const std::string& utf8);

}  // namespace flare_push

#endif  // FLARE_CORE_FLUTTER_PUSH_NOTIFICATION_BACKEND_H_
