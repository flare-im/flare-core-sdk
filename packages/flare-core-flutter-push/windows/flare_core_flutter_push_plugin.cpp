#include "flare_core_flutter_push_plugin.h"

#include <windows.h>

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <string>
#include <utility>
#include <vector>

#include "toast_notifier.h"
#include "tray_notifier.h"

namespace flare_push {

namespace {

constexpr char kMethodChannel[] = "im.flare.push/presenter";
constexpr char kTapsChannel[] = "im.flare.push/presenter/taps";

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableValue* Find(const EncodableMap* map, const char* key) {
  if (map == nullptr) return nullptr;
  auto found = map->find(EncodableValue(key));
  return found == map->end() ? nullptr : &found->second;
}

std::string StringArg(const EncodableMap* map, const char* key) {
  const EncodableValue* value = Find(map, key);
  const auto* text = value != nullptr ? std::get_if<std::string>(value) : nullptr;
  return text != nullptr ? *text : std::string();
}

int64_t IntArg(const EncodableMap* map, const char* key) {
  const EncodableValue* value = Find(map, key);
  if (value == nullptr) return 0;
  if (const auto* small = std::get_if<int32_t>(value)) return *small;
  if (const auto* large = std::get_if<int64_t>(value)) return *large;
  return 0;
}

bool BoolArg(const EncodableMap* map, const char* key) {
  const EncodableValue* value = Find(map, key);
  const auto* flag = value != nullptr ? std::get_if<bool>(value) : nullptr;
  return flag != nullptr && *flag;
}

std::vector<std::string> StringListArg(const EncodableMap* map,
                                       const char* key) {
  std::vector<std::string> items;
  const EncodableValue* value = Find(map, key);
  const auto* list = value != nullptr ? std::get_if<EncodableList>(value) : nullptr;
  if (list == nullptr) return items;
  for (const auto& item : *list) {
    if (const auto* text = std::get_if<std::string>(&item)) {
      items.push_back(*text);
    }
  }
  return items;
}

Presentation PresentationOf(const EncodableMap* map) {
  Presentation presentation;
  presentation.collapse_id = StringArg(map, "collapseId");
  presentation.thread_id = StringArg(map, "threadId");
  presentation.conversation_id = StringArg(map, "conversationId");
  presentation.message_id = StringArg(map, "messageId");
  presentation.seq = IntArg(map, "seq");
  presentation.title = StringArg(map, "title");
  presentation.body = StringArg(map, "body");
  presentation.sound = BoolArg(map, "sound");
  presentation.channel = StringArg(map, "channel");
  return presentation;
}

EncodableValue RouteValue(const TapRoute& route) {
  EncodableMap map;
  map[EncodableValue("conversationId")] = EncodableValue(route.conversation_id);
  if (!route.message_id.empty()) {
    map[EncodableValue("messageId")] = EncodableValue(route.message_id);
  }
  if (route.seq > 0) map[EncodableValue("seq")] = EncodableValue(route.seq);
  return EncodableValue(map);
}

}  // namespace

void FlareCoreFlutterPushPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<FlareCoreFlutterPushPlugin>(registrar));
}

FlareCoreFlutterPushPlugin::FlareCoreFlutterPushPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar), mailbox_(std::make_shared<TapMailbox>()) {
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), kMethodChannel,
      &flutter::StandardMethodCodec::GetInstance());
  methods_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  taps_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      registrar->messenger(), kTapsChannel,
      &flutter::StandardMethodCodec::GetInstance());
  taps_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [this](const EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            (void)arguments;
            sink_ = std::move(events);
            if (pending_.has_value()) {
              const TapRoute route = *pending_;
              pending_.reset();
              sink_->Success(RouteValue(route));
            }
            return nullptr;
          },
          [this](const EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            (void)arguments;
            sink_.reset();
            return nullptr;
          }));

  window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowMessage(window, message, wparam, lparam);
      });
}

FlareCoreFlutterPushPlugin::~FlareCoreFlutterPushPlugin() {
  // 还在路上的 toast 点击不再投给窗口。
  mailbox_->SetWindow(nullptr);
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  backend_.reset();
}

void FlareCoreFlutterPushPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  const std::string& method = call.method_name();
  if (method == "attach") {
    Attach(arguments);
    EncodableMap answer;
    answer[EncodableValue("attached")] = EncodableValue(backend_ != nullptr);
    answer[EncodableValue("backend")] =
        EncodableValue(std::string(backend_ != nullptr ? backend_->name() : "none"));
    result->Success(EncodableValue(answer));
  } else if (method == "present") {
    if (backend_ != nullptr && arguments != nullptr) {
      backend_->Present(PresentationOf(arguments));
    }
    result->Success();
  } else if (method == "clear") {
    if (backend_ != nullptr) {
      backend_->Clear(StringListArg(arguments, "collapseIds"));
    }
    result->Success();
  } else if (method == "clearAll") {
    if (backend_ != nullptr) backend_->ClearAll();
    result->Success();
  } else if (method == "detach" || method == "setBadge") {
    // detach：已经出的通知留着，登出时 Dart 另调 clearAll。setBadge：没有接任务栏角标。
    result->Success();
  } else if (method == "permissionStatus" || method == "requestPermission") {
    const bool allowed = backend_ == nullptr || backend_->Allowed();
    result->Success(EncodableValue(std::string(allowed ? "granted" : "denied")));
  } else {
    result->NotImplemented();
  }
}

void FlareCoreFlutterPushPlugin::Attach(const EncodableMap* arguments) {
  const HWND window = TopLevelWindow();
  mailbox_->SetWindow(window);
  // 再接一次沿用已经选好的那种：出过的通知还归它管。
  if (backend_ != nullptr) return;
  backend_ = ToastNotifier::Create(
      Utf16(StringArg(arguments, "windowsAppUserModelId")), mailbox_);
  if (backend_ == nullptr && window != nullptr) {
    backend_ = std::make_unique<TrayNotifier>(
        window, [this](const TapRoute& route) { OnTap(route); });
  }
}

std::optional<LRESULT> FlareCoreFlutterPushPlugin::HandleWindowMessage(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  (void)window;
  if (message == kTapMessage) {
    for (const auto& route : mailbox_->Take()) OnTap(route);
    return 0;
  }
  if (backend_ != nullptr &&
      backend_->HandleWindowMessage(message, wparam, lparam)) {
    return 0;
  }
  return std::nullopt;
}

void FlareCoreFlutterPushPlugin::OnTap(const TapRoute& route) {
  BringToFront();
  // 摘要通知不属于哪个会话：只把窗口带到前面。
  if (route.conversation_id.empty()) return;
  if (sink_ != nullptr) {
    sink_->Success(RouteValue(route));
  } else {
    pending_ = route;
  }
}

void FlareCoreFlutterPushPlugin::BringToFront() const {
  const HWND window = TopLevelWindow();
  if (window == nullptr) return;
  ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window);
}

HWND FlareCoreFlutterPushPlugin::TopLevelWindow() const {
  flutter::FlutterView* view = registrar_->GetView();
  if (view == nullptr) return nullptr;
  const HWND child = view->GetNativeWindow();
  return child != nullptr ? GetAncestor(child, GA_ROOT) : nullptr;
}

}  // namespace flare_push
