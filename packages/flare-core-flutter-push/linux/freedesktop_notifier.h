#ifndef FLARE_CORE_FLUTTER_PUSH_FREEDESKTOP_NOTIFIER_H_
#define FLARE_CORE_FLUTTER_PUSH_FREEDESKTOP_NOTIFIER_H_

#include <gio/gio.h>

#include <cstdint>
#include <functional>
#include <map>
#include <optional>
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

  // 不响铃的（静默替换、quiet 渠道）按低紧急度、不出声发：一阵连发的消息只在第一条响。
  bool passive() const { return !sound || channel == "quiet"; }
};

// 点击要去的会话；摘要通知的 conversation_id 为空。
struct TapRoute {
  std::string conversation_id;
  std::string message_id;
  int64_t seq = 0;
};

// 桌面系统通知（Linux）：经会话总线上的 org.freedesktop.Notifications 弹出。
//
// 一个会话一条通知：按合并键记住通知服务给的标识，同一会话的新通知带着它作 replaces_id，替换而不是堆积；
// Notify 还在途时又来的那条排在后面，答复回来再发，免得两条都弹。撤除用 CloseNotification。点击是动作
// "default"（多数通知服务点通知正文就是它），经 ActionInvoked 信号回来。正文按通知服务是否支持 body-markup
// 转义。所有回调都在 GTK 主循环上，不跨线程。
class FreedesktopNotifier {
 public:
  using TapHandler = std::function<void(const TapRoute&)>;

  explicit FreedesktopNotifier(TapHandler on_tap);
  ~FreedesktopNotifier();

  FreedesktopNotifier(const FreedesktopNotifier&) = delete;
  FreedesktopNotifier& operator=(const FreedesktopNotifier&) = delete;

  // 连得上会话总线。第一次调用时连接；连不上以后不再试。
  bool Available();

  void Present(const Presentation& presentation);
  void Clear(const std::vector<std::string>& collapse_ids);
  // 撤掉本插件出的全部通知。
  void ClearAll();

 private:
  struct Entry {
    // 通知服务给的标识；0 是还没有。
    guint32 id = 0;
    // Notify 还没答复。
    bool in_flight = false;
    // 答复回来就撤。
    bool close_after = false;
    // 在途期间又来的那条。
    std::optional<Presentation> queued;
    Presentation shown;
  };

  struct CallContext {
    FreedesktopNotifier* notifier;
    std::string collapse_id;
  };

  bool Connect();
  void Send(Entry& entry, const Presentation& presentation);
  void Close(const std::string& collapse_id);
  void CloseId(guint32 id);
  void OnNotified(const std::string& collapse_id, GVariant* reply);
  void OnActionInvoked(guint32 id, const gchar* action);
  void OnClosed(guint32 id);

  static void NotifyDone(GObject* source, GAsyncResult* result, gpointer data);
  static void CapabilitiesDone(GObject* source, GAsyncResult* result,
                               gpointer data);
  static void SignalReceived(GDBusConnection* connection, const gchar* sender,
                             const gchar* path, const gchar* interface_name,
                             const gchar* signal, GVariant* parameters,
                             gpointer data);

  TapHandler on_tap_;
  GDBusConnection* connection_ = nullptr;
  GCancellable* cancellable_ = nullptr;
  guint action_subscription_ = 0;
  guint closed_subscription_ = 0;
  bool connect_tried_ = false;
  // 多数通知服务支持正文标记；GetCapabilities 答复之前按支持转义。
  bool body_markup_ = true;
  std::map<std::string, Entry> entries_;
  std::map<guint32, std::string> ids_;
};

}  // namespace flare_push

#endif  // FLARE_CORE_FLUTTER_PUSH_FREEDESKTOP_NOTIFIER_H_
