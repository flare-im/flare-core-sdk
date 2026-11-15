cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "flare_core_flutter_push")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# 生成的注册代码按这个名字链接。
set(PLUGIN_NAME "flare_core_flutter_push_plugin")

list(APPEND PLUGIN_SOURCES
  "flare_core_flutter_push_plugin.cpp"
  "flare_core_flutter_push_plugin.h"
  "notification_backend.cpp"
  "notification_backend.h"
  "toast_notifier.cpp"
  "toast_notifier.h"
  "tray_notifier.cpp"
  "tray_notifier.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/flare_core_flutter_push/flare_core_flutter_push_plugin_c_api.h"
  "flare_core_flutter_push_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
# toast 走 WinRT 的 ABI（runtimeobject），托盘气泡与进程的 AppUserModelID 在 shell32。
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  runtimeobject
  shell32
)

# 没有要随应用打包的预编译库。
set(flare_core_flutter_push_bundled_libraries
  ""
  PARENT_SCOPE
)
