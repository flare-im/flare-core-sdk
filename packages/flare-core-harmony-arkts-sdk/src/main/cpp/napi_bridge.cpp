#include <stdint.h>
#include <stddef.h>

#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "flare_im_core_sdk_ffi.h"
#include "napi/native_api.h"

namespace {

std::string copy_flare_string(FlareString value) {
    if (value.ptr == nullptr || value.len == 0) {
        return {};
    }
    return std::string(value.ptr, value.len);
}

napi_value make_string(napi_env env, const std::string &value) {
    napi_value out = nullptr;
    napi_create_string_utf8(env, value.c_str(), value.size(), &out);
    return out;
}

napi_value make_number(napi_env env, double value) {
    napi_value out = nullptr;
    napi_create_double(env, value, &out);
    return out;
}

napi_value make_bool(napi_env env, bool value) {
    napi_value out = nullptr;
    napi_get_boolean(env, value, &out);
    return out;
}

napi_value make_undefined(napi_env env) {
    napi_value out = nullptr;
    napi_get_undefined(env, &out);
    return out;
}

uint64_t uint64_arg(napi_env env, napi_callback_info info, size_t index) {
    size_t argc = 8;
    napi_value argv[8] = {};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (index >= argc) {
        return 0;
    }
    double value = 0;
    napi_get_value_double(env, argv[index], &value);
    return static_cast<uint64_t>(value);
}

/** The JS argument at `index`, or null when the caller passed fewer. */
napi_value value_arg(napi_env env, napi_callback_info info, size_t index) {
    size_t argc = 8;
    napi_value argv[8] = {};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    return index < argc ? argv[index] : nullptr;
}

bool is_function(napi_env env, napi_value value) {
    if (value == nullptr) {
        return false;
    }
    napi_valuetype type = napi_undefined;
    return napi_typeof(env, value, &type) == napi_ok && type == napi_function;
}

/** A JS string argument as UTF-8; anything else reads as empty. */
std::string string_value(napi_env env, napi_value value) {
    if (value == nullptr) {
        return {};
    }
    napi_valuetype type = napi_undefined;
    if (napi_typeof(env, value, &type) != napi_ok || type != napi_string) {
        return {};
    }
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
        return {};
    }
    std::vector<char> buffer(length + 1, '\0');
    size_t written = 0;
    napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &written);
    return std::string(buffer.data(), written);
}

void *key_as_context(uint64_t key) {
    return reinterpret_cast<void *>(static_cast<uintptr_t>(key));
}

uint64_t context_as_key(void *context) {
    return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(context));
}

/**
 * A threadsafe function that runs `call_js` on the ArkTS thread calling this. It does not keep the
 * event loop alive on its own; the owner releases it.
 */
napi_threadsafe_function create_threadsafe_function(
    napi_env env,
    napi_value callback,
    const char *name,
    napi_threadsafe_function_call_js call_js
) {
    napi_threadsafe_function function = nullptr;
    if (napi_create_threadsafe_function(
            env, callback, nullptr, make_string(env, name), 0, 1, nullptr, nullptr, nullptr, call_js, &function
        ) != napi_ok) {
        return nullptr;
    }
    napi_unref_threadsafe_function(env, function);
    return function;
}

void release_threadsafe_function(napi_threadsafe_function function) {
    if (function != nullptr) {
        napi_release_threadsafe_function(function, napi_tsfn_release);
    }
}

napi_value create_rejected_promise(napi_env env, const char *message) {
    napi_value promise = nullptr;
    napi_deferred deferred = nullptr;
    napi_create_promise(env, &deferred, &promise);
    napi_value error_message = make_string(env, message);
    napi_value error = nullptr;
    napi_create_error(env, nullptr, error_message, &error);
    napi_reject_deferred(env, deferred, error);
    return promise;
}

// Events. The core calls back on its own threads; each subscription owns a threadsafe function
// that carries the event to the ArkTS thread that subscribed. The core is handed a key, never a
// pointer, so a callback racing an unsubscribe finds nothing instead of freed memory.

struct NativeEvent {
    int32_t event_type;
    std::string json;
};

std::mutex g_events_mutex;
uint64_t g_next_event_key = 1;
std::unordered_map<uint64_t, napi_threadsafe_function> g_event_functions;
std::unordered_map<FlareSubscriptionHandle, uint64_t> g_event_keys;

void call_js_event(napi_env env, napi_value js_callback, void * /*context*/, void *data) {
    auto *event = static_cast<NativeEvent *>(data);
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[2] = {make_number(env, event->event_type), make_string(env, event->json)};
        napi_call_function(env, make_undefined(env), js_callback, 2, argv, nullptr);
    }
    delete event;
}

void on_native_event(void *context, int32_t event_type, FlareString event_json) {
    auto *event = new NativeEvent{event_type, copy_flare_string(event_json)};
    flare_string_free(event_json);
    std::lock_guard<std::mutex> lock(g_events_mutex);
    auto found = g_event_functions.find(context_as_key(context));
    if (found == g_event_functions.end() ||
        napi_call_threadsafe_function(found->second, event, napi_tsfn_nonblocking) != napi_ok) {
        delete event;
    }
}

void drop_event_function(uint64_t key) {
    napi_threadsafe_function function = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_events_mutex);
        auto found = g_event_functions.find(key);
        if (found != g_event_functions.end()) {
            function = found->second;
            g_event_functions.erase(found);
        }
    }
    release_threadsafe_function(function);
}

void drop_all_event_functions() {
    std::unordered_map<uint64_t, napi_threadsafe_function> functions;
    {
        std::lock_guard<std::mutex> lock(g_events_mutex);
        functions.swap(g_event_functions);
        g_event_keys.clear();
    }
    for (auto &entry : functions) {
        release_threadsafe_function(entry.second);
    }
}

// Host-managed connect token refresh: one refresher per SDK handle. The request comes on an SDK
// thread and is carried to the ArkTS thread that installed the refresher; ArkTS answers through
// completeConnectTokenRefresh. The core is handed the handle as its context, never a pointer.

std::mutex g_refresh_mutex;
std::unordered_map<FlareHandle, napi_threadsafe_function> g_token_refreshers;

void call_js_token_refresh(napi_env env, napi_value js_callback, void * /*context*/, void *data) {
    auto *request_id = static_cast<uint64_t *>(data);
    if (env != nullptr && js_callback != nullptr) {
        napi_value argv[1] = {make_number(env, static_cast<double>(*request_id))};
        napi_call_function(env, make_undefined(env), js_callback, 1, argv, nullptr);
    }
    delete request_id;
}

void on_token_refresh_requested(void *context, uint64_t request_id) {
    auto *request = new uint64_t(request_id);
    std::lock_guard<std::mutex> lock(g_refresh_mutex);
    auto found = g_token_refreshers.find(static_cast<FlareHandle>(context_as_key(context)));
    if (found == g_token_refreshers.end() ||
        napi_call_threadsafe_function(found->second, request, napi_tsfn_nonblocking) != napi_ok) {
        // Nobody can answer; the core stops waiting after 20 s and counts it as no new token.
        delete request;
    }
}

void drop_token_refresher(FlareHandle handle) {
    napi_threadsafe_function function = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_refresh_mutex);
        auto found = g_token_refreshers.find(handle);
        if (found != g_token_refreshers.end()) {
            function = found->second;
            g_token_refreshers.erase(found);
        }
    }
    release_threadsafe_function(function);
}

void drop_all_token_refreshers() {
    std::unordered_map<FlareHandle, napi_threadsafe_function> functions;
    {
        std::lock_guard<std::mutex> lock(g_refresh_mutex);
        functions.swap(g_token_refreshers);
    }
    for (auto &entry : functions) {
        release_threadsafe_function(entry.second);
    }
}

// A unit C ABI call settled as a Promise: the result callback comes on an SDK thread and is carried
// to the ArkTS thread that made the call. A failure rejects with an Error carrying `nativeCode`
// (the FlareError code) and `detailsJson`, which the ArkTS bridge turns into its typed exception.

struct PendingUnit {
    napi_deferred deferred = nullptr;
    napi_threadsafe_function function = nullptr;
    int32_t code = FLARE_OK;
    std::string message;
    std::string details_json;
};

napi_value native_error(napi_env env, int32_t code, const std::string &message, const std::string &details_json) {
    napi_value error = nullptr;
    napi_create_error(env, nullptr, make_string(env, message.empty() ? "Flare C ABI call failed" : message), &error);
    napi_set_named_property(env, error, "nativeCode", make_number(env, code));
    napi_set_named_property(env, error, "detailsJson", make_string(env, details_json));
    return error;
}

void settle_pending_unit(napi_env env, PendingUnit *pending) {
    if (env != nullptr) {
        if (pending->code == FLARE_OK) {
            napi_resolve_deferred(env, pending->deferred, make_undefined(env));
        } else {
            napi_reject_deferred(env, pending->deferred, native_error(env, pending->code, pending->message, pending->details_json));
        }
    }
    release_threadsafe_function(pending->function);
    delete pending;
}

void call_js_settle(napi_env env, napi_value /*js_callback*/, void * /*context*/, void *data) {
    settle_pending_unit(env, static_cast<PendingUnit *>(data));
}

void on_unit_result(void *context, const FlareError *error, FlareString result_json) {
    auto *pending = static_cast<PendingUnit *>(context);
    flare_string_free(result_json);
    if (error != nullptr) {
        pending->code = error->code;
        pending->message = copy_flare_string(error->message);
        pending->details_json = copy_flare_string(error->details_json);
        flare_error_heap_free(const_cast<FlareError *>(error));
    }
    // Fails only while the ArkTS environment is being torn down; nothing is left to settle then.
    napi_call_threadsafe_function(pending->function, pending, napi_tsfn_nonblocking);
}

/** A pending unit call, or null with `promise` already rejected when it could not be set up. */
PendingUnit *begin_pending_unit(napi_env env, napi_value *promise) {
    auto *pending = new PendingUnit();
    napi_create_promise(env, &pending->deferred, promise);
    pending->function = create_threadsafe_function(env, nullptr, "flareCoreResult", call_js_settle);
    if (pending->function == nullptr) {
        pending->code = FLARE_ERR_INTERNAL;
        pending->message = "could not create the ArkTS result channel";
        napi_reject_deferred(env, pending->deferred, native_error(env, pending->code, pending->message, ""));
        delete pending;
        return nullptr;
    }
    return pending;
}

/** The C call returned without taking the callback: settle now on this thread. */
void fail_pending_unit(napi_env env, PendingUnit *pending, int32_t code) {
    pending->code = code;
    pending->message = "Flare C ABI call was refused";
    settle_pending_unit(env, pending);
}

napi_value create(napi_env env, napi_callback_info /*info*/) {
    return make_number(env, static_cast<double>(flare_sdk_create()));
}

napi_value release(napi_env env, napi_callback_info info) {
    auto handle = static_cast<FlareHandle>(uint64_arg(env, info, 0));
    flare_sdk_release(handle);
    drop_token_refresher(handle);
    return make_undefined(env);
}

napi_value hard_reset(napi_env env, napi_callback_info /*info*/) {
    flare_sdk_hard_reset();
    drop_all_token_refreshers();
    drop_all_event_functions();
    return make_undefined(env);
}

napi_value is_connected(napi_env env, napi_callback_info info) {
    return make_bool(env, flare_sdk_is_connected(static_cast<FlareHandle>(uint64_arg(env, info, 0))));
}

napi_value session_active(napi_env env, napi_callback_info info) {
    return make_bool(env, flare_sdk_session_active(static_cast<FlareHandle>(uint64_arg(env, info, 0))));
}

napi_value sdk_version(napi_env env, napi_callback_info /*info*/) {
    FlareString value = flare_sdk_version();
    std::string text = copy_flare_string(value);
    flare_string_free(value);
    return make_string(env, text);
}

napi_value ffi_contract_version(napi_env env, napi_callback_info /*info*/) {
    FlareString value = flare_sdk_ffi_contract_version();
    std::string text = copy_flare_string(value);
    flare_string_free(value);
    return make_string(env, text);
}

/** subscribeEvents(handle, onEvent(eventType, eventJson)): the subscription, 0 when none was made. */
napi_value subscribe_events(napi_env env, napi_callback_info info) {
    auto handle = static_cast<FlareHandle>(uint64_arg(env, info, 0));
    napi_value callback = value_arg(env, info, 1);
    if (!is_function(env, callback)) {
        return make_number(env, 0);
    }
    napi_threadsafe_function function = create_threadsafe_function(env, callback, "flareCoreEvent", call_js_event);
    if (function == nullptr) {
        return make_number(env, 0);
    }
    uint64_t key = 0;
    {
        std::lock_guard<std::mutex> lock(g_events_mutex);
        key = g_next_event_key++;
        g_event_functions[key] = function;
    }
    auto subscription = flare_event_subscribe(handle, key_as_context(key), on_native_event);
    if (subscription == 0) {
        drop_event_function(key);
        return make_number(env, 0);
    }
    {
        std::lock_guard<std::mutex> lock(g_events_mutex);
        g_event_keys[subscription] = key;
    }
    return make_number(env, static_cast<double>(subscription));
}

void event_batch_callback(void * /*context*/, size_t /*event_count*/, FlareString events_json) {
    flare_string_free(events_json);
}

napi_value subscribe_events_batch(napi_env env, napi_callback_info info) {
    auto handle = static_cast<FlareHandle>(uint64_arg(env, info, 0));
    auto subscription = flare_event_subscribe_batch(handle, nullptr, event_batch_callback);
    return make_number(env, static_cast<double>(subscription));
}

napi_value unsubscribe_events(napi_env env, napi_callback_info info) {
    auto subscription = static_cast<FlareSubscriptionHandle>(uint64_arg(env, info, 0));
    // The core waits for callbacks in flight, and they take g_events_mutex: never hold it here.
    flare_event_unsubscribe(subscription);
    uint64_t key = 0;
    {
        std::lock_guard<std::mutex> lock(g_events_mutex);
        auto found = g_event_keys.find(subscription);
        if (found != g_event_keys.end()) {
            key = found->second;
            g_event_keys.erase(found);
        }
    }
    if (key != 0) {
        drop_event_function(key);
    }
    return make_undefined(env);
}

napi_value unsubscribe_all_events(napi_env env, napi_callback_info /*info*/) {
    flare_event_unsubscribe_all();
    drop_all_event_functions();
    return make_undefined(env);
}

/**
 * setConnectTokenRefresher(handle, onRequest(requestId) | null): a Promise that settles when the
 * core has taken (or dropped) the refresher.
 */
napi_value set_connect_token_refresher(napi_env env, napi_callback_info info) {
    auto handle = static_cast<FlareHandle>(uint64_arg(env, info, 0));
    napi_value callback = value_arg(env, info, 1);
    napi_value promise = nullptr;
    PendingUnit *pending = begin_pending_unit(env, &promise);
    if (pending == nullptr) {
        return promise;
    }
    if (!is_function(env, callback)) {
        // Detach in the core first so no new request arrives, then drop the function.
        int32_t code = flare_sdk_set_connect_token_refresher(handle, nullptr, nullptr, pending, on_unit_result);
        drop_token_refresher(handle);
        if (code != FLARE_OK) {
            fail_pending_unit(env, pending, code);
        }
        return promise;
    }
    napi_threadsafe_function function =
        create_threadsafe_function(env, callback, "flareConnectTokenRefresh", call_js_token_refresh);
    if (function == nullptr) {
        fail_pending_unit(env, pending, FLARE_ERR_INTERNAL);
        return promise;
    }
    napi_threadsafe_function previous = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_refresh_mutex);
        auto found = g_token_refreshers.find(handle);
        if (found != g_token_refreshers.end()) {
            previous = found->second;
        }
        g_token_refreshers[handle] = function;
    }
    release_threadsafe_function(previous);
    int32_t code = flare_sdk_set_connect_token_refresher(
        handle, key_as_context(handle), on_token_refresh_requested, pending, on_unit_result
    );
    if (code != FLARE_OK) {
        drop_token_refresher(handle);
        fail_pending_unit(env, pending, code);
    }
    return promise;
}

/** completeConnectTokenRefresh(handle, requestId, token): the C result code; an empty token means none. */
napi_value complete_connect_token_refresh(napi_env env, napi_callback_info info) {
    auto handle = static_cast<FlareHandle>(uint64_arg(env, info, 0));
    uint64_t request_id = uint64_arg(env, info, 1);
    std::string token = string_value(env, value_arg(env, info, 2));
    int32_t code = flare_sdk_complete_connect_token_refresh(handle, request_id, token.empty() ? nullptr : token.c_str());
    return make_number(env, code);
}

napi_value unsupported_async(napi_env env, napi_callback_info /*info*/) {
    return create_rejected_promise(
        env,
        "HarmonyOS NAPI async C ABI callback bridge is not wired yet. Sync lifecycle symbols are linked."
    );
}

napi_value init(napi_env env, napi_value exports) {
    napi_property_descriptor descriptors[] = {
        {"create", nullptr, create, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, release, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"hardReset", nullptr, hard_reset, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isConnected", nullptr, is_connected, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sessionActive", nullptr, session_active, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkVersion", nullptr, sdk_version, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"ffiContractVersion", nullptr, ffi_contract_version, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"messageDispatchJson", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"capabilityDispatchJson", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkInvokeJson", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"messageBuildJson", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkInit", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkUninit", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkLogin", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkLogout", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkUpdateAccessToken", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkCurrentUserId", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkDisconnect", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sdkDataRoot", nullptr, unsupported_async, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"subscribeEvents", nullptr, subscribe_events, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"subscribeEventsBatch", nullptr, subscribe_events_batch, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"unsubscribeEvents", nullptr, unsubscribe_events, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"unsubscribeAllEvents", nullptr, unsubscribe_all_events, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setConnectTokenRefresher", nullptr, set_connect_token_refresher, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"completeConnectTokenRefresh", nullptr, complete_connect_token_refresh, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    return exports;
}

}  // namespace

static napi_module flare_core_harmony_arkts_sdk_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = init,
    .nm_modname = "flare_core_harmony_arkts_sdk",
    .nm_priv = nullptr,
    .reserved = {nullptr},
};

extern "C" __attribute__((constructor)) void RegisterFlareCoreHarmonyArktsSdkModule() {
    napi_module_register(&flare_core_harmony_arkts_sdk_module);
}
