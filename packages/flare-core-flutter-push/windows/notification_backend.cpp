#include "notification_backend.h"

#include <utility>

namespace flare_push {

namespace {

// 没人取走时只留最近几条：点击是用户一下一下点的，堆不起来。
constexpr size_t kMailboxLimit = 8;

}  // namespace

void TapMailbox::SetWindow(HWND window) {
  std::lock_guard<std::mutex> guard(lock_);
  window_ = window;
}

void TapMailbox::Post(const TapRoute& route) {
  HWND window = nullptr;
  {
    std::lock_guard<std::mutex> guard(lock_);
    routes_.push_back(route);
    if (routes_.size() > kMailboxLimit) routes_.erase(routes_.begin());
    window = window_;
  }
  if (window != nullptr) PostMessageW(window, kTapMessage, 0, 0);
}

std::vector<TapRoute> TapMailbox::Take() {
  std::lock_guard<std::mutex> guard(lock_);
  std::vector<TapRoute> routes;
  routes.swap(routes_);
  return routes;
}

std::wstring Utf16(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring text(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      text.data(), length);
  return text;
}

}  // namespace flare_push
