#include "toast_notifier.h"

#include <appmodel.h>
#include <roapi.h>
#include <shobjidl.h>

#pragma warning(push, 0)
#include <windows.data.xml.dom.h>
#include <wrl/event.h>
#include <wrl/wrappers/corewrappers.h>
#pragma warning(pop)

#include <utility>

namespace flare_push {

namespace {

using ABI::Windows::Data::Xml::Dom::IXmlDocument;
using ABI::Windows::Data::Xml::Dom::IXmlDocumentIO;
using ABI::Windows::Foundation::ITypedEventHandler;
using ABI::Windows::UI::Notifications::IToastNotification;
using ABI::Windows::UI::Notifications::IToastNotification2;
using ABI::Windows::UI::Notifications::IToastNotificationFactory;
using ABI::Windows::UI::Notifications::IToastNotificationHistory;
using ABI::Windows::UI::Notifications::IToastNotificationManagerStatics;
using ABI::Windows::UI::Notifications::IToastNotificationManagerStatics2;
using ABI::Windows::UI::Notifications::IToastNotifier;
using ABI::Windows::UI::Notifications::NotificationSetting;
using ABI::Windows::UI::Notifications::NotificationSetting_Enabled;
using ABI::Windows::UI::Notifications::ToastNotification;
using Microsoft::WRL::Callback;
using Microsoft::WRL::ClassicCom;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Implements;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::Wrappers::HStringReference;

using ActivatedHandler = ITypedEventHandler<ToastNotification*, IInspectable*>;

// 本插件的 toast 都在这一组里：全撤时只撤这一组，应用自己的通知不动。
constexpr wchar_t kGroup[] = L"flare";

// 进程在打包（MSIX）的身份下运行。
bool IsPackaged() {
  UINT32 length = 0;
  return GetCurrentPackageFullName(&length, nullptr) !=
         APPMODEL_ERROR_NO_PACKAGE;
}

// 进程自己设的 AppUserModelID（SetCurrentProcessExplicitAppUserModelID）；没有为空。
std::wstring ProcessAppId() {
  PWSTR id = nullptr;
  if (FAILED(GetCurrentProcessExplicitAppUserModelID(&id)) || id == nullptr) {
    return std::wstring();
  }
  std::wstring value(id);
  CoTaskMemFree(id);
  return value;
}

void AppendEscaped(std::wstring& xml, const std::wstring& text) {
  for (const wchar_t c : text) {
    switch (c) {
      case L'&':
        xml += L"&amp;";
        break;
      case L'<':
        xml += L"&lt;";
        break;
      case L'>':
        xml += L"&gt;";
        break;
      case L'"':
        xml += L"&quot;";
        break;
      case L'\'':
        xml += L"&apos;";
        break;
      default:
        // XML 不认的控制字符丢掉，免得整条 toast 解析失败。
        if (c >= 0x20 || c == L'\t' || c == L'\n' || c == L'\r') xml += c;
        break;
    }
  }
}

// 标题一行、正文一段；没有标题时正文当标题。不响铃的不出声。
std::wstring ToastXml(const Presentation& presentation) {
  std::wstring title = Utf16(presentation.title);
  std::wstring body = Utf16(presentation.body);
  if (title.empty()) title.swap(body);
  std::wstring xml =
      L"<toast><visual><binding template=\"ToastGeneric\">"
      L"<text hint-maxLines=\"1\">";
  AppendEscaped(xml, title);
  xml += L"</text>";
  if (!body.empty()) {
    xml += L"<text>";
    AppendEscaped(xml, body);
    xml += L"</text>";
  }
  xml += L"</binding></visual>";
  if (presentation.passive()) {
    xml += L"<audio silent=\"true\"/>";
  } else {
    xml += L"<audio src=\"ms-winsoundevent:Notification.IM\"/>";
  }
  xml += L"</toast>";
  return xml;
}

}  // namespace

std::unique_ptr<ToastNotifier> ToastNotifier::Create(
    const std::wstring& app_id, std::shared_ptr<TapMailbox> mailbox) {
  ComPtr<IToastNotificationManagerStatics> manager;
  if (FAILED(RoGetActivationFactory(
          HStringReference(
              RuntimeClass_Windows_UI_Notifications_ToastNotificationManager)
              .Get(),
          IID_PPV_ARGS(&manager)))) {
    return nullptr;
  }
  const bool packaged = IsPackaged();
  std::wstring id;
  if (!packaged) {
    id = app_id.empty() ? ProcessAppId() : app_id;
    if (id.empty()) return nullptr;
  }
  ComPtr<IToastNotifier> notifier;
  const HRESULT created =
      packaged ? manager->CreateToastNotifier(&notifier)
               : manager->CreateToastNotifierWithId(
                     HStringReference(id.c_str(),
                                      static_cast<unsigned int>(id.size()))
                         .Get(),
                     &notifier);
  if (FAILED(created) || notifier == nullptr) return nullptr;
  // 没有注册过的 AppUserModelID 读不出通知设置：toast 发出去也不会显示，退回托盘。用户关掉通知时读得出来，
  // 照用 toast（尊重用户的选择，不改走托盘）。
  NotificationSetting setting = NotificationSetting_Enabled;
  if (FAILED(notifier->get_Setting(&setting))) return nullptr;
  ComPtr<IToastNotificationFactory> factory;
  if (FAILED(RoGetActivationFactory(
          HStringReference(
              RuntimeClass_Windows_UI_Notifications_ToastNotification)
              .Get(),
          IID_PPV_ARGS(&factory)))) {
    return nullptr;
  }
  ComPtr<IToastNotificationHistory> history;
  ComPtr<IToastNotificationManagerStatics2> manager2;
  if (SUCCEEDED(manager.As(&manager2))) manager2->get_History(&history);
  return std::unique_ptr<ToastNotifier>(
      new ToastNotifier(std::move(id), std::move(notifier), std::move(factory),
                        std::move(history), std::move(mailbox)));
}

ToastNotifier::ToastNotifier(std::wstring app_id,
                             ComPtr<IToastNotifier> notifier,
                             ComPtr<IToastNotificationFactory> factory,
                             ComPtr<IToastNotificationHistory> history,
                             std::shared_ptr<TapMailbox> mailbox)
    : app_id_(std::move(app_id)),
      notifier_(std::move(notifier)),
      factory_(std::move(factory)),
      history_(std::move(history)),
      mailbox_(std::move(mailbox)) {}

ToastNotifier::~ToastNotifier() {
  // 已经出的 toast 留在通知中心；只解开点击。
  for (auto& entry : shown_) {
    if (entry.second.toast != nullptr) {
      entry.second.toast->remove_Activated(entry.second.activated);
    }
  }
}

bool ToastNotifier::Allowed() {
  NotificationSetting setting = NotificationSetting_Enabled;
  return SUCCEEDED(notifier_->get_Setting(&setting)) &&
         setting == NotificationSetting_Enabled;
}

void ToastNotifier::Present(const Presentation& presentation) {
  if (presentation.collapse_id.empty()) return;
  ComPtr<IInspectable> instance;
  if (FAILED(RoActivateInstance(
          HStringReference(RuntimeClass_Windows_Data_Xml_Dom_XmlDocument).Get(),
          &instance))) {
    return;
  }
  ComPtr<IXmlDocument> document;
  ComPtr<IXmlDocumentIO> loader;
  if (FAILED(instance.As(&document)) || FAILED(document.As(&loader))) return;
  const std::wstring xml = ToastXml(presentation);
  if (FAILED(loader->LoadXml(
          HStringReference(xml.c_str(), static_cast<unsigned int>(xml.size()))
              .Get()))) {
    return;
  }
  ComPtr<IToastNotification> toast;
  if (FAILED(factory_->CreateToastNotification(document.Get(), &toast))) {
    return;
  }
  const std::wstring tag = Utf16(presentation.collapse_id);
  ComPtr<IToastNotification2> tagged;
  if (SUCCEEDED(toast.As(&tagged))) {
    tagged->put_Tag(
        HStringReference(tag.c_str(), static_cast<unsigned int>(tag.size()))
            .Get());
    tagged->put_Group(HStringReference(kGroup).Get());
    tagged->put_SuppressPopup(static_cast<boolean>(presentation.passive()));
  }

  TapRoute route;
  route.conversation_id = presentation.conversation_id;
  route.message_id = presentation.message_id;
  route.seq = presentation.seq;
  std::weak_ptr<TapMailbox> mailbox = mailbox_;
  Shown shown;
  shown.toast = toast;
  // 点击在 WinRT 的线程池线程上回来：交给信箱，平台线程上再发给 Dart。
  auto handler =
      Callback<Implements<RuntimeClassFlags<ClassicCom>, ActivatedHandler>>(
          [mailbox, route](IToastNotification*, IInspectable*) -> HRESULT {
            if (auto target = mailbox.lock()) target->Post(route);
            return S_OK;
          });
  if (handler != nullptr) toast->add_Activated(handler.Get(), &shown.activated);

  auto previous = shown_.find(presentation.collapse_id);
  if (previous != shown_.end()) {
    // 新的按 tag 与 group 替换它：只解开旧的点击，不从通知中心移除。
    if (previous->second.toast != nullptr) {
      previous->second.toast->remove_Activated(previous->second.activated);
    }
    shown_.erase(previous);
  }
  if (FAILED(notifier_->Show(toast.Get()))) {
    toast->remove_Activated(shown.activated);
    return;
  }
  shown_[presentation.collapse_id] = std::move(shown);
}

void ToastNotifier::Clear(const std::vector<std::string>& collapse_ids) {
  for (const auto& collapse_id : collapse_ids) {
    auto found = shown_.find(collapse_id);
    if (found != shown_.end()) {
      Forget(found->second);
      shown_.erase(found);
    }
    // 也撤上一次运行留在通知中心里的同一会话。
    RemoveFromHistory(collapse_id);
  }
}

void ToastNotifier::ClearAll() {
  for (auto& entry : shown_) Forget(entry.second);
  shown_.clear();
  if (history_ == nullptr) return;
  if (app_id_.empty()) {
    history_->RemoveGroup(HStringReference(kGroup).Get());
  } else {
    history_->RemoveGroupWithId(
        HStringReference(kGroup).Get(),
        HStringReference(app_id_.c_str(),
                         static_cast<unsigned int>(app_id_.size()))
            .Get());
  }
}

void ToastNotifier::Forget(Shown& shown) {
  if (shown.toast == nullptr) return;
  shown.toast->remove_Activated(shown.activated);
  notifier_->Hide(shown.toast.Get());
}

void ToastNotifier::RemoveFromHistory(const std::string& collapse_id) {
  if (history_ == nullptr || collapse_id.empty()) return;
  const std::wstring tag = Utf16(collapse_id);
  if (app_id_.empty()) {
    history_->RemoveGroupedTag(
        HStringReference(tag.c_str(), static_cast<unsigned int>(tag.size()))
            .Get(),
        HStringReference(kGroup).Get());
  } else {
    history_->RemoveGroupedTagWithId(
        HStringReference(tag.c_str(), static_cast<unsigned int>(tag.size()))
            .Get(),
        HStringReference(kGroup).Get(),
        HStringReference(app_id_.c_str(),
                         static_cast<unsigned int>(app_id_.size()))
            .Get());
  }
}

}  // namespace flare_push
