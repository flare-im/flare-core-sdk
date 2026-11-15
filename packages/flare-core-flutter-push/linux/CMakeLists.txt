cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flare_core_flutter_push")
project(${PROJECT_NAME} LANGUAGES CXX)

# 生成的注册代码按 <项目名>_plugin 链接这个库。
set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

add_library(${PLUGIN_NAME} SHARED
  "flare_core_flutter_push_plugin.cc"
  "freedesktop_notifier.cc"
)

apply_standard_settings(${PLUGIN_NAME})
# std::optional：宿主的标准设置只要求 C++14。
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)

set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
# GDBus 在 GIO 里，随 GTK 一起来。
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# 没有要随应用打包的预编译库。
set(flare_core_flutter_push_bundled_libraries
  ""
  PARENT_SCOPE
)
