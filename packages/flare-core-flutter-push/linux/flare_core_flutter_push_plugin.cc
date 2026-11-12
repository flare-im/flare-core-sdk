#include "include/flare_core_flutter_push/flare_core_flutter_push_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "freedesktop_notifier.h"

// 桌面系统通知的 Flutter 桥（Linux）。展示、替换、撤除与点击都在 FreedesktopNotifier；这里只接通道。
//
// - 方法通道 im.flare.push/presenter：Dart 调 attach（答 {attached, backend}）、detach、present（引擎
//   NotificationPresentation 的形状）、clear（{collapseIds}）、clearAll、setBadge（没有通用的桌面角标接口，
//   什么也不做）、permissionStatus 与 requestPermission（没有授权这一步，答 granted）。
// - 事件通道 im.flare.push/presenter/taps：点击去向 {conversationId, messageId?, seq?}；没人监听时留着最近一条。
//
// 插件随引擎一直活到进程结束：状态不释放。

namespace {

constexpr char kMethodChannel[] = "im.flare.push/presenter";
constexpr char kTapsChannel[] = "im.flare.push/presenter/taps";

struct PluginState {
  FlMethodChannel* methods = nullptr;
  FlEventChannel* taps = nullptr;
  // 弱引用：视图没了自动置空。
  FlView* view = nullptr;
  bool listening = false;
  std::optional<flare_push::TapRoute> pending;
  std::unique_ptr<flare_push::FreedesktopNotifier> notifier;
};

FlValue* Lookup(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(map, key);
}

std::string StringArg(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? std::string(fl_value_get_string(value))
             : std::string();
}

int64_t IntArg(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT
             ? fl_value_get_int(value)
             : 0;
}

bool BoolArg(FlValue* map, const char* key) {
  FlValue* value = Lookup(map, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}

std::vector<std::string> StringListArg(FlValue* map, const char* key) {
  std::vector<std::string> items;
  FlValue* value = Lookup(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_LIST) {
    return items;
  }
  for (size_t i = 0; i < fl_value_get_length(value); i++) {
    FlValue* item = fl_value_get_list_value(value, i);
    if (fl_value_get_type(item) == FL_VALUE_TYPE_STRING) {
      items.emplace_back(fl_value_get_string(item));
    }
  }
  return items;
}

flare_push::Presentation PresentationOf(FlValue* args) {
  flare_push::Presentation presentation;
  presentation.collapse_id = StringArg(args, "collapseId");
  presentation.thread_id = StringArg(args, "threadId");
  presentation.conversation_id = StringArg(args, "conversationId");
  presentation.message_id = StringArg(args, "messageId");
  presentation.seq = IntArg(args, "seq");
  presentation.title = StringArg(args, "title");
  presentation.body = StringArg(args, "body");
  presentation.sound = BoolArg(args, "sound");
  presentation.channel = StringArg(args, "channel");
  return presentation;
}

FlValue* RouteValue(const flare_push::TapRoute& route) {
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(value, "conversationId",
                           fl_value_new_string(route.conversation_id.c_str()));
  if (!route.message_id.empty()) {
    fl_value_set_string_take(value, "messageId",
                             fl_value_new_string(route.message_id.c_str()));
  }
  if (route.seq > 0) {
    fl_value_set_string_take(value, "seq", fl_value_new_int(route.seq));
  }
  return value;
}

void SendRoute(PluginState* state, const flare_push::TapRoute& route) {
  g_autoptr(FlValue) value = RouteValue(route);
  fl_event_channel_send(state->taps, value, nullptr, nullptr);
}

// 点击：把窗口带到前面；属于某个会话的交给 Dart，没人监听时留着最近一条。
void OnTap(PluginState* state, const flare_push::TapRoute& route) {
  if (state->view != nullptr) {
    GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(state->view));
    if (GTK_IS_WINDOW(toplevel)) gtk_window_present(GTK_WINDOW(toplevel));
  }
  if (route.conversation_id.empty()) return;
  if (!state->listening) {
    state->pending = route;
    return;
  }
  SendRoute(state, route);
}

FlMethodErrorResponse* TapsListen(FlEventChannel* channel, FlValue* args,
                                  gpointer data) {
  auto* state = static_cast<PluginState*>(data);
  state->listening = true;
  if (state->pending.has_value()) {
    flare_push::TapRoute route = *state->pending;
    state->pending.reset();
    SendRoute(state, route);
  }
  return nullptr;
}

FlMethodErrorResponse* TapsCancel(FlEventChannel* channel, FlValue* args,
                                  gpointer data) {
  static_cast<PluginState*>(data)->listening = false;
  return nullptr;
}

void HandleMethodCall(FlMethodChannel* channel, FlMethodCall* call,
                      gpointer data) {
  auto* state = static_cast<PluginState*>(data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "attach") == 0) {
    const bool available = state->notifier->Available();
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "attached", fl_value_new_bool(available));
    fl_value_set_string_take(
        result, "backend",
        fl_value_new_string(available ? "freedesktop" : "none"));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "present") == 0) {
    state->notifier->Present(PresentationOf(args));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "clear") == 0) {
    state->notifier->Clear(StringListArg(args, "collapseIds"));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "clearAll") == 0) {
    state->notifier->ClearAll();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "detach") == 0 ||
             strcmp(method, "setBadge") == 0) {
    // detach：已经出的通知留着，登出时 Dart 另调 clearAll。setBadge：没有通用的桌面角标接口。
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "permissionStatus") == 0 ||
             strcmp(method, "requestPermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_string("granted");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

void flare_core_flutter_push_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  auto* state = new PluginState();
  state->notifier = std::make_unique<flare_push::FreedesktopNotifier>(
      [state](const flare_push::TapRoute& route) { OnTap(state, route); });
  FlView* view = fl_plugin_registrar_get_view(registrar);
  if (view != nullptr) {
    state->view = view;
    g_object_add_weak_pointer(G_OBJECT(view),
                              reinterpret_cast<gpointer*>(&state->view));
  }
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  state->methods =
      fl_method_channel_new(messenger, kMethodChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(state->methods, HandleMethodCall,
                                            state, nullptr);
  state->taps =
      fl_event_channel_new(messenger, kTapsChannel, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(state->taps, TapsListen, TapsCancel,
                                       state, nullptr);
}
