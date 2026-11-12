#include "tray_notifier.h"

#include <wchar.h>

#include <utility>

namespace flare_push {

namespace {

// 本插件的托盘图标在这个窗口下的编号。
constexpr UINT kIconId = 0x4650;

}  // namespace

TrayNotifier::TrayNotifier(HWND window, TapHandler on_tap)
    : window_(window),
      on_tap_(std::move(on_tap)),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {}

TrayNotifier::~TrayNotifier() { RemoveIcon(); }

NOTIFYICONDATAW TrayNotifier::Base() const {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  return data;
}

// 应用窗口的图标（Flutter 的 runner 在窗口类上设了应用图标）；没有时用系统的应用图标。
HICON TrayNotifier::Icon() const {
  HICON icon = reinterpret_cast<HICON>(GetClassLongPtrW(window_, GCLP_HICONSM));
  if (icon == nullptr) {
    icon = reinterpret_cast<HICON>(GetClassLongPtrW(window_, GCLP_HICON));
  }
  return icon != nullptr ? icon : LoadIcon(nullptr, IDI_APPLICATION);
}

bool TrayNotifier::EnsureIcon() {
  if (added_) return true;
  if (window_ == nullptr) return false;
  NOTIFYICONDATAW data = Base();
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = kTrayMessage;
  data.hIcon = Icon();
  GetWindowTextW(window_, data.szTip, static_cast<int>(ARRAYSIZE(data.szTip)));
  if (!Shell_NotifyIconW(NIM_ADD, &data)) return false;
  data.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &data);
  added_ = true;
  return true;
}

void TrayNotifier::RemoveIcon() {
  if (!added_) return;
  NOTIFYICONDATAW data = Base();
  Shell_NotifyIconW(NIM_DELETE, &data);
  added_ = false;
}

void TrayNotifier::HideBalloon() {
  if (!added_) return;
  // 正文为空的 NIF_INFO 收走当前气泡。
  NOTIFYICONDATAW data = Base();
  data.uFlags = NIF_INFO;
  data.szInfo[0] = L'\0';
  Shell_NotifyIconW(NIM_MODIFY, &data);
}

void TrayNotifier::Present(const Presentation& presentation) {
  if (!EnsureIcon()) return;
  std::wstring title = Utf16(presentation.title);
  std::wstring body = Utf16(presentation.body);
  if (title.empty()) title.swap(body);
  // 正文为空的气泡不会出现。
  if (body.empty()) body = L" ";
  NOTIFYICONDATAW data = Base();
  data.uFlags = NIF_INFO;
  // 系统的上限：标题 63 个字符，正文 255 个字符，超出截断。
  wcsncpy_s(data.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(data.szInfo, body.c_str(), _TRUNCATE);
  data.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON | NIIF_RESPECT_QUIET_TIME;
  if (presentation.passive()) data.dwInfoFlags |= NIIF_NOSOUND;
  data.hBalloonIcon = Icon();
  if (Shell_NotifyIconW(NIM_MODIFY, &data)) current_ = presentation;
}

void TrayNotifier::Clear(const std::vector<std::string>& collapse_ids) {
  if (!current_.has_value()) return;
  for (const auto& collapse_id : collapse_ids) {
    if (collapse_id == current_->collapse_id) {
      HideBalloon();
      current_.reset();
      return;
    }
  }
}

void TrayNotifier::ClearAll() {
  current_.reset();
  RemoveIcon();
}

bool TrayNotifier::HandleWindowMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam) {
  (void)wparam;
  if (taskbar_created_ != 0 && message == taskbar_created_) {
    // 资源管理器重启，托盘清空了：图标重新加上。别人也要看这条消息。
    if (added_) {
      added_ = false;
      EnsureIcon();
    }
    return false;
  }
  if (message != kTrayMessage) return false;
  // NOTIFYICON_VERSION_4：低位是事件，高位是图标编号。
  switch (LOWORD(lparam)) {
    case NIN_BALLOONUSERCLICK: {
      TapRoute route;
      if (current_.has_value()) {
        route.conversation_id = current_->conversation_id;
        route.message_id = current_->message_id;
        route.seq = current_->seq;
      }
      if (on_tap_) on_tap_(route);
      break;
    }
    case NIN_SELECT:
    case NIN_KEYSELECT:
      // 点托盘图标：只把窗口带到前面。
      if (on_tap_) on_tap_(TapRoute{});
      break;
    default:
      break;
  }
  return true;
}

}  // namespace flare_push
