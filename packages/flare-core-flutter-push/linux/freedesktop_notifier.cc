#include "freedesktop_notifier.h"

#include <memory>
#include <utility>

namespace flare_push {

namespace {

constexpr char kService[] = "org.freedesktop.Notifications";
constexpr char kPath[] = "/org/freedesktop/Notifications";
constexpr char kInterface[] = "org.freedesktop.Notifications";
constexpr char kDefaultAction[] = "default";

// 紧急度（规范里的 byte）：低、普通、紧急。
constexpr guint8 kUrgencyLow = 0;
constexpr guint8 kUrgencyNormal = 1;
constexpr guint8 kUrgencyCritical = 2;

// 通知上显示的应用名。
const gchar* AppName() {
  const gchar* name = g_get_application_name();
  if (name == nullptr) name = g_get_prgname();
  return name != nullptr ? name : "";
}

// 应用的 desktop 文件名（不带后缀）：通知服务据此找图标与应用名，用户的通知设置也按它分。
const gchar* DesktopEntry() {
  GApplication* application = g_application_get_default();
  const gchar* id =
      application != nullptr ? g_application_get_application_id(application)
                             : nullptr;
  return id != nullptr ? id : g_get_prgname();
}

}  // namespace

FreedesktopNotifier::FreedesktopNotifier(TapHandler on_tap)
    : on_tap_(std::move(on_tap)) {}

FreedesktopNotifier::~FreedesktopNotifier() {
  if (cancellable_ != nullptr) {
    // 在途的调用随之以「已取消」结束，回调里不再碰这个对象。
    g_cancellable_cancel(cancellable_);
    g_object_unref(cancellable_);
  }
  if (connection_ != nullptr) {
    if (action_subscription_ != 0) {
      g_dbus_connection_signal_unsubscribe(connection_, action_subscription_);
    }
    if (closed_subscription_ != 0) {
      g_dbus_connection_signal_unsubscribe(connection_, closed_subscription_);
    }
    g_object_unref(connection_);
  }
}

bool FreedesktopNotifier::Available() { return Connect(); }

bool FreedesktopNotifier::Connect() {
  if (connection_ != nullptr) return true;
  if (connect_tried_) return false;
  connect_tried_ = true;
  g_autoptr(GError) error = nullptr;
  // GTK 应用启动时已经连上会话总线，这里拿到的是同一个连接，不会卡住主线程。
  connection_ = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (connection_ == nullptr) return false;
  cancellable_ = g_cancellable_new();
  // 不按发送方过滤：信号来自通知服务的唯一名；标识是通知服务全局分的，只认自己记着的。
  action_subscription_ = g_dbus_connection_signal_subscribe(
      connection_, nullptr, kInterface, "ActionInvoked", kPath, nullptr,
      G_DBUS_SIGNAL_FLAGS_NONE, SignalReceived, this, nullptr);
  closed_subscription_ = g_dbus_connection_signal_subscribe(
      connection_, nullptr, kInterface, "NotificationClosed", kPath, nullptr,
      G_DBUS_SIGNAL_FLAGS_NONE, SignalReceived, this, nullptr);
  g_dbus_connection_call(connection_, kService, kPath, kInterface,
                         "GetCapabilities", nullptr, G_VARIANT_TYPE("(as)"),
                         G_DBUS_CALL_FLAGS_NONE, -1, cancellable_,
                         CapabilitiesDone, this);
  return true;
}

void FreedesktopNotifier::Present(const Presentation& presentation) {
  if (presentation.collapse_id.empty() || !Connect()) return;
  Entry& entry = entries_[presentation.collapse_id];
  entry.close_after = false;
  if (entry.in_flight) {
    // 上一条的标识还没回来：现在发就替换不了它。
    entry.queued = presentation;
    return;
  }
  Send(entry, presentation);
}

void FreedesktopNotifier::Send(Entry& entry, const Presentation& presentation) {
  entry.in_flight = true;
  entry.shown = presentation;

  GVariantBuilder actions;
  g_variant_builder_init(&actions, G_VARIANT_TYPE("as"));
  // 默认动作：点通知本身。标签不显示，留空。
  g_variant_builder_add(&actions, "s", kDefaultAction);
  g_variant_builder_add(&actions, "s", "");

  GVariantBuilder hints;
  g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
  guint8 urgency = kUrgencyNormal;
  if (presentation.passive()) {
    urgency = kUrgencyLow;
  } else if (presentation.channel == "urgent") {
    urgency = kUrgencyCritical;
  }
  g_variant_builder_add(&hints, "{sv}", "urgency", g_variant_new_byte(urgency));
  g_variant_builder_add(&hints, "{sv}", "category",
                        g_variant_new_string("im.received"));
  const gchar* desktop_entry = DesktopEntry();
  if (desktop_entry != nullptr && desktop_entry[0] != '\0') {
    g_variant_builder_add(&hints, "{sv}", "desktop-entry",
                          g_variant_new_string(desktop_entry));
  }
  if (presentation.passive()) {
    g_variant_builder_add(&hints, "{sv}", "suppress-sound",
                          g_variant_new_boolean(TRUE));
  } else {
    g_variant_builder_add(&hints, "{sv}", "sound-name",
                          g_variant_new_string("message-new-instant"));
  }

  // 标题不能空：多数通知服务不显示没有标题的通知。
  const std::string title =
      presentation.title.empty() ? std::string(AppName()) : presentation.title;
  g_autofree gchar* escaped =
      body_markup_ ? g_markup_escape_text(presentation.body.c_str(), -1)
                   : nullptr;
  const gchar* body = escaped != nullptr ? escaped : presentation.body.c_str();

  GVariant* parameters = g_variant_new(
      "(susssasa{sv}i)", AppName(), entry.id, "", title.c_str(), body,
      &actions, &hints, -1);
  auto* context = new CallContext{this, presentation.collapse_id};
  g_dbus_connection_call(connection_, kService, kPath, kInterface, "Notify",
                         parameters, G_VARIANT_TYPE("(u)"),
                         G_DBUS_CALL_FLAGS_NONE, -1, cancellable_, NotifyDone,
                         context);
}

void FreedesktopNotifier::NotifyDone(GObject* source, GAsyncResult* result,
                                     gpointer data) {
  std::unique_ptr<CallContext> context(static_cast<CallContext*>(data));
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) reply = g_dbus_connection_call_finish(
      G_DBUS_CONNECTION(source), result, &error);
  // 取消只发生在析构时：对象已经不在了。
  if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED)) return;
  context->notifier->OnNotified(context->collapse_id, reply);
}

void FreedesktopNotifier::OnNotified(const std::string& collapse_id,
                                     GVariant* reply) {
  auto found = entries_.find(collapse_id);
  if (found == entries_.end()) return;
  Entry& entry = found->second;
  entry.in_flight = false;
  if (reply != nullptr) {
    guint32 id = 0;
    g_variant_get(reply, "(u)", &id);
    if (entry.id != 0 && entry.id != id) {
      // 通知服务没有按 replaces_id 替换，另开了一条：旧的撤掉。
      CloseId(entry.id);
      ids_.erase(entry.id);
    }
    entry.id = id;
    if (id != 0) ids_[id] = collapse_id;
  }
  if (entry.close_after) {
    if (entry.id != 0) {
      CloseId(entry.id);
      ids_.erase(entry.id);
    }
    entries_.erase(found);
    return;
  }
  if (entry.queued.has_value()) {
    Presentation next = std::move(*entry.queued);
    entry.queued.reset();
    Send(entry, next);
    return;
  }
  // 没发出去（没有通知服务、调用出错），也没有要替换的：不留空条目。
  if (entry.id == 0) entries_.erase(found);
}

void FreedesktopNotifier::Clear(const std::vector<std::string>& collapse_ids) {
  for (const auto& collapse_id : collapse_ids) Close(collapse_id);
}

void FreedesktopNotifier::ClearAll() {
  std::vector<std::string> collapse_ids;
  collapse_ids.reserve(entries_.size());
  for (const auto& entry : entries_) collapse_ids.push_back(entry.first);
  Clear(collapse_ids);
}

void FreedesktopNotifier::Close(const std::string& collapse_id) {
  auto found = entries_.find(collapse_id);
  if (found == entries_.end()) return;
  Entry& entry = found->second;
  if (entry.in_flight) {
    // 标识还没回来：答复到了再撤，排着的那条也不发了。
    entry.close_after = true;
    entry.queued.reset();
    return;
  }
  if (entry.id != 0) {
    CloseId(entry.id);
    ids_.erase(entry.id);
  }
  entries_.erase(found);
}

void FreedesktopNotifier::CloseId(guint32 id) {
  if (connection_ == nullptr || id == 0) return;
  g_dbus_connection_call(connection_, kService, kPath, kInterface,
                         "CloseNotification", g_variant_new("(u)", id),
                         nullptr, G_DBUS_CALL_FLAGS_NONE, -1, nullptr, nullptr,
                         nullptr);
}

void FreedesktopNotifier::CapabilitiesDone(GObject* source,
                                           GAsyncResult* result,
                                           gpointer data) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) reply = g_dbus_connection_call_finish(
      G_DBUS_CONNECTION(source), result, &error);
  if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED) ||
      reply == nullptr) {
    return;
  }
  auto* self = static_cast<FreedesktopNotifier*>(data);
  g_autoptr(GVariantIter) capabilities = nullptr;
  g_variant_get(reply, "(as)", &capabilities);
  bool markup = false;
  const gchar* capability = nullptr;
  while (g_variant_iter_loop(capabilities, "&s", &capability)) {
    if (g_strcmp0(capability, "body-markup") == 0) markup = true;
  }
  self->body_markup_ = markup;
}

void FreedesktopNotifier::SignalReceived(GDBusConnection* connection,
                                         const gchar* sender,
                                         const gchar* path,
                                         const gchar* interface_name,
                                         const gchar* signal,
                                         GVariant* parameters, gpointer data) {
  auto* self = static_cast<FreedesktopNotifier*>(data);
  if (g_strcmp0(signal, "ActionInvoked") == 0 &&
      g_variant_is_of_type(parameters, G_VARIANT_TYPE("(us)"))) {
    guint32 id = 0;
    const gchar* action = nullptr;
    g_variant_get(parameters, "(u&s)", &id, &action);
    self->OnActionInvoked(id, action);
  } else if (g_strcmp0(signal, "NotificationClosed") == 0 &&
             g_variant_is_of_type(parameters, G_VARIANT_TYPE("(uu)"))) {
    guint32 id = 0;
    guint32 reason = 0;
    g_variant_get(parameters, "(uu)", &id, &reason);
    self->OnClosed(id);
  }
}

void FreedesktopNotifier::OnActionInvoked(guint32 id, const gchar* action) {
  if (g_strcmp0(action, kDefaultAction) != 0) return;
  auto known = ids_.find(id);
  if (known == ids_.end()) return;
  auto found = entries_.find(known->second);
  if (found == entries_.end()) return;
  const Presentation& shown = found->second.shown;
  TapRoute route;
  route.conversation_id = shown.conversation_id;
  route.message_id = shown.message_id;
  route.seq = shown.seq;
  if (on_tap_) on_tap_(route);
}

void FreedesktopNotifier::OnClosed(guint32 id) {
  auto known = ids_.find(id);
  if (known == ids_.end()) return;
  const std::string collapse_id = known->second;
  ids_.erase(known);
  auto found = entries_.find(collapse_id);
  // 正在替换的那条不动：新标识回来时会重新记上。
  if (found == entries_.end() || found->second.in_flight ||
      found->second.id != id) {
    return;
  }
  entries_.erase(found);
}

}  // namespace flare_push
