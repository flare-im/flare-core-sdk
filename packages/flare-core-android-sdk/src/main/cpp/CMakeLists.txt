cmake_minimum_required(VERSION 3.22.1)

project(flare_core_android_sdk_jni LANGUAGES CXX)

set(FLARE_CLIENT_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../..")
set(FLARE_CORE_FFI_HEADER_DIR "${FLARE_CLIENT_SDK_ROOT}/native/abi")
if(NOT DEFINED FLARE_CORE_FFI_ROOT)
    set(FLARE_CORE_FFI_ROOT "${FLARE_CLIENT_SDK_ROOT}/native/artifacts/android")
endif()
set(FLARE_CORE_FFI_DIR "${FLARE_CORE_FFI_ROOT}/${ANDROID_ABI}")

add_library(flare_im_core_android_sdk_jni SHARED flare_jni_bridge.cpp)

target_include_directories(
    flare_im_core_android_sdk_jni
    PRIVATE "${FLARE_CORE_FFI_HEADER_DIR}"
)

# Link against the prebuilt FFI .so via -L/-l (NOT an IMPORTED target with an absolute
# IMPORTED_LOCATION). The .so carries no DT_SONAME, so linking by absolute path bakes that
# host path into the JNI shim's DT_NEEDED -> on-device `dlopen failed: library
# "/Users/.../libflare_im_core_sdk_ffi.so" not found`. The -l<name> form instead records
# DT_NEEDED as the plain `libflare_im_core_sdk_ffi.so` basename, which resolves against the
# copy the Kotlin loader (JniNativeBridge loads flare_im_core_sdk_ffi first) puts in-process.
target_link_directories(
    flare_im_core_android_sdk_jni
    PRIVATE "${FLARE_CORE_FFI_DIR}"
)

target_link_libraries(
    flare_im_core_android_sdk_jni
    PRIVATE
        flare_im_core_sdk_ffi
        log
)
