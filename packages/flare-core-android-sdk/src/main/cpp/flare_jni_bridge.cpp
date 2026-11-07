#include <jni.h>
#include <stddef.h>
#include <stdint.h>

#include <string>

extern "C" {
#include "flare_im_core_sdk_ffi.h"
}

namespace {

JavaVM *g_vm = nullptr;
jclass g_bridge_class = nullptr;
jmethodID g_complete_result = nullptr;
jmethodID g_emit_event = nullptr;
jmethodID g_request_connect_token = nullptr;

std::string to_std_string(JNIEnv *env, jstring value) {
    if (value == nullptr) {
        return {};
    }
    const char *chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) {
        return {};
    }
    std::string out(chars);
    env->ReleaseStringUTFChars(value, chars);
    return out;
}

jstring to_jstring(JNIEnv *env, const std::string &value) {
    return env->NewStringUTF(value.c_str());
}

std::string copy_flare_string(FlareString value) {
    if (value.ptr == nullptr || value.len == 0) {
        return {};
    }
    return std::string(value.ptr, value.len);
}

JNIEnv *attached_env(bool *did_attach) {
    *did_attach = false;
    JNIEnv *env = nullptr;
    if (g_vm == nullptr) {
        return nullptr;
    }
    if (g_vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) == JNI_OK) {
        return env;
    }
    if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
        return nullptr;
    }
    *did_attach = true;
    return env;
}

void detach_env(bool did_attach) {
    if (did_attach && g_vm != nullptr) {
        g_vm->DetachCurrentThread();
    }
}

void result_callback(void *context, const FlareError *error, FlareString result_json) {
    bool did_attach = false;
    JNIEnv *env = attached_env(&did_attach);
    if (env == nullptr || g_bridge_class == nullptr || g_complete_result == nullptr) {
        return;
    }

    const auto context_id = static_cast<jlong>(reinterpret_cast<intptr_t>(context));
    jint error_code = 0;
    std::string error_message;
    std::string error_details_json;
    if (error != nullptr) {
        error_code = static_cast<jint>(error->code);
        error_message = copy_flare_string(error->message);
        error_details_json = copy_flare_string(error->details_json);
    }
    std::string result = copy_flare_string(result_json);

    jstring j_error_message = to_jstring(env, error_message);
    jstring j_error_details = to_jstring(env, error_details_json);
    jstring j_result = to_jstring(env, result);
    env->CallStaticVoidMethod(
        g_bridge_class,
        g_complete_result,
        context_id,
        error_code,
        j_error_message,
        j_error_details,
        j_result
    );
    env->DeleteLocalRef(j_error_message);
    env->DeleteLocalRef(j_error_details);
    env->DeleteLocalRef(j_result);

    if (error != nullptr) {
        flare_error_heap_free(const_cast<FlareError *>(error));
    }
    flare_string_free(result_json);
    detach_env(did_attach);
}

void event_callback(void *context, int32_t event_type, FlareString event_json) {
    bool did_attach = false;
    JNIEnv *env = attached_env(&did_attach);
    if (env == nullptr || g_bridge_class == nullptr || g_emit_event == nullptr) {
        return;
    }

    auto handle = static_cast<jlong>(reinterpret_cast<intptr_t>(context));
    std::string event = copy_flare_string(event_json);
    jstring j_event = to_jstring(env, event);
    env->CallStaticVoidMethod(
        g_bridge_class,
        g_emit_event,
        handle,
        static_cast<jint>(event_type),
        j_event
    );
    env->DeleteLocalRef(j_event);

    flare_string_free(event_json);
    detach_env(did_attach);
}

// FlareTokenRefreshCallback: runs on an SDK thread. Hands the request to Kotlin, which answers later
// through flare_sdk_complete_connect_token_refresh; returns at once. The context is the handle.
void token_refresh_callback(void *context, uint64_t request_id) {
    if (g_bridge_class == nullptr || g_request_connect_token == nullptr) {
        return;
    }
    bool did_attach = false;
    JNIEnv *env = attached_env(&did_attach);
    if (env == nullptr) {
        return;
    }
    env->CallStaticVoidMethod(
        g_bridge_class,
        g_request_connect_token,
        static_cast<jlong>(reinterpret_cast<intptr_t>(context)),
        static_cast<jlong>(request_id)
    );
    // Never let a Java exception travel back into the SDK thread.
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    detach_env(did_attach);
}

void event_batch_callback(void * /*context*/, size_t /*event_count*/, FlareString events_json) {
    flare_string_free(events_json);
}

void *context_from_id(jlong context_id) {
    return reinterpret_cast<void *>(static_cast<intptr_t>(context_id));
}

}  // namespace

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void * /*reserved*/) {
    g_vm = vm;
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    jclass local_bridge = env->FindClass("com/flare/im/bridge/JniNativeBridge");
    if (local_bridge == nullptr) {
        return JNI_ERR;
    }
    g_bridge_class = static_cast<jclass>(env->NewGlobalRef(local_bridge));
    env->DeleteLocalRef(local_bridge);
    g_complete_result = env->GetStaticMethodID(
        g_bridge_class,
        "completeResult",
        "(JILjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V"
    );
    g_emit_event = env->GetStaticMethodID(
        g_bridge_class,
        "emitEvent",
        "(JILjava/lang/String;)V"
    );
    g_request_connect_token = env->GetStaticMethodID(
        g_bridge_class,
        "requestConnectToken",
        "(JJ)V"
    );
    if (g_complete_result == nullptr || g_emit_event == nullptr || g_request_connect_token == nullptr) {
        return JNI_ERR;
    }
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeCreate(JNIEnv * /*env*/, jobject /*self*/) {
    return static_cast<jlong>(flare_sdk_create());
}

extern "C" JNIEXPORT void JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeRelease(JNIEnv * /*env*/, jobject /*self*/, jlong handle) {
    flare_sdk_release(static_cast<FlareHandle>(handle));
}

extern "C" JNIEXPORT void JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeHardReset(JNIEnv * /*env*/, jobject /*self*/) {
    flare_sdk_hard_reset();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeIsConnected(JNIEnv * /*env*/, jobject /*self*/, jlong handle) {
    return flare_sdk_is_connected(static_cast<FlareHandle>(handle));
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSessionActive(JNIEnv * /*env*/, jobject /*self*/, jlong handle) {
    return flare_sdk_session_active(static_cast<FlareHandle>(handle));
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkVersion(JNIEnv *env, jobject /*self*/) {
    FlareString value = flare_sdk_version();
    std::string text = copy_flare_string(value);
    flare_string_free(value);
    return to_jstring(env, text);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeFfiContractVersion(JNIEnv *env, jobject /*self*/) {
    FlareString value = flare_sdk_ffi_contract_version();
    std::string text = copy_flare_string(value);
    flare_string_free(value);
    return to_jstring(env, text);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeMessageDispatchJson(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring op,
    jstring request_json,
    jlong context_id
) {
    std::string op_text = to_std_string(env, op);
    std::string request = to_std_string(env, request_json);
    return flare_message_dispatch_json(
        static_cast<FlareHandle>(handle),
        op_text.c_str(),
        request.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeCapabilityDispatchJson(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring op,
    jstring request_json,
    jlong context_id
) {
    std::string op_text = to_std_string(env, op);
    std::string request = to_std_string(env, request_json);
    return flare_capability_dispatch_json(
        static_cast<FlareHandle>(handle),
        op_text.c_str(),
        request.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkInvokeJson(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring api_id,
    jstring request_json,
    jlong context_id
) {
    std::string api = to_std_string(env, api_id);
    std::string request = to_std_string(env, request_json);
    return flare_sdk_invoke_json(
        static_cast<FlareHandle>(handle),
        api.c_str(),
        request.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeMessageBuildJson(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring request_json,
    jlong context_id
) {
    std::string request = to_std_string(env, request_json);
    return flare_message_build_json(
        static_cast<FlareHandle>(handle),
        request.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkInit(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring request_json,
    jlong context_id
) {
    std::string request = to_std_string(env, request_json);
    return flare_sdk_init(static_cast<FlareHandle>(handle), request.c_str(), context_from_id(context_id), result_callback);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkUninit(JNIEnv * /*env*/, jobject /*self*/, jlong handle, jlong context_id) {
    return flare_sdk_uninit(static_cast<FlareHandle>(handle), context_from_id(context_id), result_callback);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkLogin(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring user_id,
    jstring token,
    jstring store_config_json,
    jlong context_id
) {
    std::string user = to_std_string(env, user_id);
    std::string access_token = to_std_string(env, token);
    std::string store_config = to_std_string(env, store_config_json);
    return flare_sdk_login(
        static_cast<FlareHandle>(handle),
        user.c_str(),
        access_token.c_str(),
        store_config.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

// 登录拆成两半（热启动）：prepare 只开本地库、不连网；connect 再做网络握手与首次同步。
extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkPrepare(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring user_id,
    jstring store_config_json,
    jlong context_id
) {
    std::string user = to_std_string(env, user_id);
    std::string store_config = to_std_string(env, store_config_json);
    return flare_sdk_prepare(
        static_cast<FlareHandle>(handle),
        user.c_str(),
        store_config.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkConnect(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring user_id,
    jstring token,
    jlong context_id
) {
    std::string user = to_std_string(env, user_id);
    std::string access_token = to_std_string(env, token);
    return flare_sdk_connect(
        static_cast<FlareHandle>(handle),
        user.c_str(),
        access_token.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkLogout(JNIEnv * /*env*/, jobject /*self*/, jlong handle, jlong context_id) {
    return flare_sdk_logout(static_cast<FlareHandle>(handle), context_from_id(context_id), result_callback);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkUpdateAccessToken(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jstring access_token,
    jstring tenant_id,
    jlong context_id
) {
    std::string token = to_std_string(env, access_token);
    std::string tenant = to_std_string(env, tenant_id);
    return flare_sdk_update_access_token(
        static_cast<FlareHandle>(handle),
        token.c_str(),
        tenant.c_str(),
        context_from_id(context_id),
        result_callback
    );
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkCurrentUserId(JNIEnv * /*env*/, jobject /*self*/, jlong handle, jlong context_id) {
    return flare_sdk_current_user_id(static_cast<FlareHandle>(handle), context_from_id(context_id), result_callback);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkDisconnect(JNIEnv * /*env*/, jobject /*self*/, jlong handle, jlong context_id) {
    return flare_sdk_disconnect(static_cast<FlareHandle>(handle), context_from_id(context_id), result_callback);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSdkDataRoot(JNIEnv * /*env*/, jobject /*self*/, jlong handle, jlong context_id) {
    return flare_sdk_data_root(static_cast<FlareHandle>(handle), context_from_id(context_id), result_callback);
}

// Installs (enabled) or removes the connect token refresher. The core forgets it on release and
// hard reset; Kotlin keeps the refresher keyed by handle, so no Java object is held here.
extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSetConnectTokenRefresher(
    JNIEnv * /*env*/,
    jobject /*self*/,
    jlong handle,
    jboolean enabled,
    jlong context_id
) {
    return flare_sdk_set_connect_token_refresher(
        static_cast<FlareHandle>(handle),
        context_from_id(handle),
        enabled ? token_refresh_callback : nullptr,
        context_from_id(context_id),
        result_callback
    );
}

// A null token means none was obtained.
extern "C" JNIEXPORT jint JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeCompleteConnectTokenRefresh(
    JNIEnv *env,
    jobject /*self*/,
    jlong handle,
    jlong request_id,
    jstring token
) {
    if (token == nullptr) {
        return flare_sdk_complete_connect_token_refresh(
            static_cast<FlareHandle>(handle),
            static_cast<uint64_t>(request_id),
            nullptr
        );
    }
    std::string value = to_std_string(env, token);
    return flare_sdk_complete_connect_token_refresh(
        static_cast<FlareHandle>(handle),
        static_cast<uint64_t>(request_id),
        value.c_str()
    );
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSubscribeEvents(JNIEnv * /*env*/, jobject /*self*/, jlong handle) {
    return static_cast<jlong>(
        flare_event_subscribe(static_cast<FlareHandle>(handle), context_from_id(handle), event_callback)
    );
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeSubscribeEventsBatch(JNIEnv * /*env*/, jobject /*self*/, jlong handle) {
    return static_cast<jlong>(flare_event_subscribe_batch(static_cast<FlareHandle>(handle), nullptr, event_batch_callback));
}

extern "C" JNIEXPORT void JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeUnsubscribeEvents(JNIEnv * /*env*/, jobject /*self*/, jlong subscription) {
    flare_event_unsubscribe(static_cast<FlareSubscriptionHandle>(subscription));
}

extern "C" JNIEXPORT void JNICALL
Java_com_flare_im_bridge_JniNativeBridge_nativeUnsubscribeAllEvents(JNIEnv * /*env*/, jobject /*self*/) {
    flare_event_unsubscribe_all();
}
