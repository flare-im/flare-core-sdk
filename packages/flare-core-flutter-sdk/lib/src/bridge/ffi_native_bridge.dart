import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../adapter/codec/wire_codec.dart'
    show wireDecodeResponse, wireEncodeRequest;
import '../contract/bridge_contract.dart';
import 'contract_version_guard.dart';
import '../bridge/ffi_types.dart';
import '../flare_core_sdk.dart';
import '../bridge/native_library_loader.dart';

typedef _NativeResultCallback = Void Function(
  Pointer<Void>,
  Pointer<NativeFlareError>,
  NativeFlareString,
);
typedef _NativeEventCallback = Void Function(
  Pointer<Void>,
  Int32,
  NativeFlareString,
);
typedef _NativeEventBatchCallback = Void Function(
  Pointer<Void>,
  Size,
  NativeFlareString,
);

typedef _NativeTokenRefreshCallback = Void Function(Pointer<Void>, Uint64);

typedef NativeEventHandler = void Function(int eventType, Object? payload);

final NativeCallable<_NativeResultCallback> _resultCallback =
    NativeCallable<_NativeResultCallback>.listener(_handleResultCallback);
final NativeCallable<_NativeEventCallback> _eventCallback =
    NativeCallable<_NativeEventCallback>.listener(_handleEventCallback);
final NativeCallable<_NativeEventBatchCallback> _eventBatchCallback =
    NativeCallable<_NativeEventBatchCallback>.listener(
        _handleEventBatchCallback);
// The core calls this on one of its background threads; a listener callable
// posts the call to this isolate, which answers through the complete call.
final NativeCallable<_NativeTokenRefreshCallback> _tokenRefreshCallback =
    NativeCallable<_NativeTokenRefreshCallback>.listener(
        _handleTokenRefreshCallback);

final _pendingCalls = <int, _PendingCall>{};
final _eventSinks = <int, NativeEventHandler>{};
final _tokenRefreshers = <int, ConnectTokenRefresh>{};

/// FFI result codes the token refresh answer distinguishes.
const int _flareOk = 0;
int _nextContextId = 1;

/// Thin Dart bridge over the Flare Core C ABI.
final class FfiNativeBridge implements NativeBridge, ConnectTokenRefresherBridge {
  FfiNativeBridge({
    DynamicLibrary? library,
    String? libraryPath,
  }) : _bindings = _NativeBindings(
          library ?? loadFlareNativeLibrary(libraryPath: libraryPath),
        );

  final _NativeBindings _bindings;
  int _handle = 0;
  bool _released = false;
  bool _contractVersionChecked = false;
  int? _tokenRefreshContext;

  @override
  Future<T> invoke<T>(NativeCallDescriptor descriptor,
      [Object? request]) async {
    if (descriptor.operation != kFfiContractVersionOperation) {
      _ensureContractVersion();
    }
    final value = await _invoke(descriptor, request);
    return value as T;
  }

  Future<Object?> _invoke(NativeCallDescriptor descriptor, Object? request) {
    if (descriptor.transport == 'message-dispatch-json' &&
        descriptor.cApi == 'flare_message_dispatch_json') {
      final future = _dispatchJson(asMap(request), descriptor.dispatchOp);
      if (descriptor.returnMode == 'callback-unit') {
        return future.then((_) => null);
      }
      return future.then(asResponseMap);
    }
    if (descriptor.transport == 'capability-dispatch-json' &&
        descriptor.cApi == 'flare_capability_dispatch_json') {
      final future =
          _capabilityDispatchJson(asMap(request), descriptor.dispatchOp);
      if (descriptor.returnMode == 'callback-unit') {
        return future.then((_) => null);
      }
      return future.then(asResponseMap);
    }
    if (descriptor.transport == 'media-dispatch-json' &&
        descriptor.cApi == 'flare_media_dispatch_json') {
      final future = _mediaDispatchJson(asMap(request), descriptor.dispatchOp);
      if (descriptor.returnMode == 'callback-unit') {
        return future.then((_) => null);
      }
      return future.then(asResponseMap);
    }
    if (descriptor.transport == 'contract-invoke-json' &&
        descriptor.cApi == 'flare_sdk_invoke_json') {
      final future = _contractInvokeJson(descriptor.operation, request);
      if (descriptor.returnMode == 'callback-unit') {
        return future.then((_) => null);
      }
      return future.then(asResponseMap);
    }
    if (descriptor.transport == 'dispatch-json' &&
        descriptor.cApi == 'flare_message_build_json') {
      return _callBuildJson(request).then(asResponseMap);
    }
    if (descriptor.transport == 'dispatch-json' &&
        descriptor.cApi == 'flare_message_dispatch_json') {
      return _dispatchJson(asMap(request), descriptor.dispatchOp)
          .then(asResponseMap);
    }

    switch (descriptor.operation) {
      case 'sdk.create':
        return Future.value(_createHandle());
      case 'sdk.dispose':
        return _dispose();
      case 'sdk.hard_reset':
        _bindings.sdkHardReset();
        // A hard reset drops every handle's refresher in the core.
        _tokenRefreshers.clear();
        _tokenRefreshContext = null;
        _handle = 0;
        _released = true;
        return Future.value();
      case 'sdk.init':
        return _callWithJson(_bindings.sdkInit, request);
      case 'sdk.uninit':
        return _call0(_bindings.sdkUninit);
      case 'sdk.login':
        return _login(asMap(request));
      case 'sdk.prepare':
        return _prepare(asMap(request));
      case 'sdk.connect':
        return _connect(asMap(request));
      case 'sdk.update_access_token':
        return _updateAccessToken(asMap(request));
      case 'sdk.logout':
        return _call0(_bindings.sdkLogout);
      case 'sdk.current_user_id':
        return _call0(_bindings.sdkCurrentUserId).then(asResponseMap);
      case 'sdk.is_connected':
        return Future.value(_bindings.sdkIsConnected(_requireHandle()));
      case 'sdk.session_active':
        return Future.value(_bindings.sdkSessionActive(_requireHandle()));
      case 'connection.disconnect':
        return _call0(_bindings.sdkDisconnect);
      case 'message.create_text':
        return _createTextMessage(asMap(request)).then(asResponseMap);
      case 'message.send':
        return _callWithJson(
                _bindings.messageSend, messageForTypedSend(request))
            .then(asResponseMap);
      case 'message.list':
        return _listMessages(asMap(request)).then(asResponseMap);
      case 'message.recall':
        return _messageMutation(_bindings.messageRecall, asMap(request));
      case 'message.delete':
        return _messageMutation(_bindings.messageDelete, asMap(request));
      case 'sync.conversation':
        return _callWithString(
          _bindings.syncConversation,
          stringField(request, 'conversationId'),
        );
      case 'sync.messages':
        return _syncMessages(asMap(request));
      case 'presence.get':
        return _callWithString(
          _bindings.presenceGet,
          stringField(request, 'userId'),
        ).then(asResponseMap);
      case 'presence.batch_get':
        return _callWithJson(
          _bindings.presenceBatchGet,
          listField(request, 'userIds'),
        ).then(asResponseMap);
      case 'presence.subscribe':
        return _callWithJson(
          _bindings.presenceSubscribe,
          listField(request, 'userIds'),
        );
      case 'media.upload_file':
        return _mediaUploadPath(_bindings.mediaUploadFile, asMap(request))
            .then(asResponseMap);
      case 'media.upload_image':
        return _mediaUploadPath(_bindings.mediaUploadImage, asMap(request))
            .then(asResponseMap);
      case 'media.upload_video':
        return _mediaUploadPath(_bindings.mediaUploadVideo, asMap(request))
            .then(asResponseMap);
      case 'media.upload_bytes':
        return _mediaUploadBytes(asMap(request)).then(asResponseMap);
      case 'media.delete_file':
        return _mediaDeleteFile(asMap(request)).then(asResponseMap);
      case 'media.cancel_user_file_download':
        return _mediaCancelUserFileDownload(asMap(request));
      case 'media.download_file_to_downloads':
        return _callWithJson(_bindings.mediaDownloadFileToDownloads, request)
            .then(asResponseMap);
      case 'event.subscribe':
        return Future.value(_subscribeEvents(request));
      case 'event.subscribe_batch':
        return Future.value(_subscribeEventsBatch(request));
      case 'event.unsubscribe':
        _unsubscribe(asMap(request));
        return Future.value();
      case 'event.unsubscribe_all':
        _bindings.eventUnsubscribeAll();
        _eventSinks.clear();
        return Future.value();
      case 'diagnostics.sdk_version':
        return Future.value({'version': _takeString(_bindings.sdkVersion())});
      case 'diagnostics.ffi_contract_version':
        return Future.value(
            {'version': _takeString(_bindings.sdkFfiContractVersion())});
      case 'diagnostics.data_root':
        return _call0(_bindings.sdkDataRoot).then(asResponseMap);
      default:
        throw FlareSdkException(
          code: 'unsupported_operation',
          message: 'Unsupported Flutter FFI operation: ${descriptor.operation}',
          operation: descriptor.operation,
        );
    }
  }

  void _ensureContractVersion() {
    if (_contractVersionChecked) {
      return;
    }
    final version = _takeString(_bindings.sdkFfiContractVersion());
    assertFfiContractVersion(version);
    _contractVersionChecked = true;
  }

  Map<String, Object?> _createHandle() {
    if (_handle == 0 || _released) {
      _handle = _bindings.sdkCreate();
      _released = false;
    }
    if (_handle == 0) {
      throw const FlareSdkException(
        code: 'native_create_failed',
        message: 'flare_sdk_create returned an invalid handle.',
        operation: 'sdk.create',
      );
    }
    return {'handle': _handle};
  }

  Future<void> _dispose() async {
    if (_handle != 0 && !_released) {
      // Releasing the handle drops its refresher in the core as well.
      _bindings.sdkRelease(_handle);
    }
    _forgetTokenRefresher();
    _handle = 0;
    _released = true;
  }

  /// Installs [refresher] as the host's connect token refresher, or removes it
  /// when null.
  ///
  /// The core asks for a token on one of its background threads; the request
  /// comes back to this isolate, [refresher] runs here, and its token goes back
  /// through `flare_sdk_complete_connect_token_refresh`. A refresher that throws
  /// or takes longer than the core waits (20 seconds) counts as no new token.
  /// Disposing the client removes it.
  @override
  Future<void> setConnectTokenRefresher(ConnectTokenRefresher? refresher) async {
    _ensureContractVersion();
    final handle = _requireHandle();
    final previous = _tokenRefreshContext;
    if (refresher == null) {
      await _enqueue('sdk.set_connect_token_refresher', (context) {
        return _bindings.sdkSetConnectTokenRefresher(
          handle,
          nullptr,
          nullptr,
          context,
          _resultCallback.nativeFunction,
        );
      });
      _forgetTokenRefresher(previous);
      return;
    }
    final refreshContext = _reserveContextId();
    _tokenRefreshers[refreshContext] = ConnectTokenRefresh(
      refresher: refresher,
      complete: (requestId, token) {
        // The handle went away (released, or replaced after a reset): nothing
        // in the core waits for this answer any more.
        if (_released || _handle != handle) return false;
        return completeConnectTokenRefresh(requestId, token);
      },
    );
    try {
      await _enqueue('sdk.set_connect_token_refresher', (context) {
        return _bindings.sdkSetConnectTokenRefresher(
          handle,
          Pointer<Void>.fromAddress(refreshContext),
          _tokenRefreshCallback.nativeFunction,
          context,
          _resultCallback.nativeFunction,
        );
      });
    } catch (_) {
      _tokenRefreshers.remove(refreshContext);
      rethrow;
    }
    _tokenRefreshContext = refreshContext;
    if (previous != null && previous != refreshContext) {
      _tokenRefreshers.remove(previous);
    }
  }

  /// Answers refresh request [requestId] with [token] (null or empty when none
  /// could be obtained). False when the core no longer waits for it: the
  /// request expired, or no refresher is installed.
  bool completeConnectTokenRefresh(int requestId, String? token) {
    if (_handle == 0 || _released) return false;
    final handle = _handle;
    final code = using((arena) {
      final nativeToken = token == null || token.trim().isEmpty
          ? nullptr
          : token.toNativeUtf8(allocator: arena);
      return _bindings.sdkCompleteConnectTokenRefresh(
        handle,
        requestId,
        nativeToken,
      );
    });
    return code == _flareOk;
  }

  void _forgetTokenRefresher([int? context]) {
    final target = context ?? _tokenRefreshContext;
    if (target != null) _tokenRefreshers.remove(target);
    if (context == null || context == _tokenRefreshContext) {
      _tokenRefreshContext = null;
    }
  }

  int _requireHandle() {
    if (_handle == 0 || _released) {
      _createHandle();
    }
    return _handle;
  }

  Future<Object?> _login(Map<String, Object?> request) {
    return using((arena) {
      final userId =
          stringField(request, 'userId').toNativeUtf8(allocator: arena);
      // token 可选：配了 sdkConfig.auth（SDK 托管）时留空，由核心经 Core API 签发。
      final token = (request['token']?.toString() ?? '').toNativeUtf8(allocator: arena);
      final storeConfigJson = request['storeConfigJson']?.toString();
      final storeConfig = (storeConfigJson != null && storeConfigJson.isNotEmpty
              ? storeConfigJson
              : '{}')
          .toNativeUtf8(allocator: arena);
      return _enqueue('sdk.login', (context) {
        return _bindings.sdkLogin(
          _requireHandle(),
          userId,
          token,
          storeConfig,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _prepare(Map<String, Object?> request) {
    return using((arena) {
      final userId =
          stringField(request, 'userId').toNativeUtf8(allocator: arena);
      final storeConfigJson = request['storeConfigJson']?.toString();
      final storeConfig = (storeConfigJson != null && storeConfigJson.isNotEmpty
              ? storeConfigJson
              : '{}')
          .toNativeUtf8(allocator: arena);
      return _enqueue('sdk.prepare', (context) {
        return _bindings.sdkPrepare(
          _requireHandle(),
          userId,
          storeConfig,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _connect(Map<String, Object?> request) {
    return using((arena) {
      final userId =
          stringField(request, 'userId').toNativeUtf8(allocator: arena);
      // token 可选：配了 sdkConfig.auth（SDK 托管）时留空，由核心经 Core API 签发。
      final token = (request['token']?.toString() ?? '').toNativeUtf8(allocator: arena);
      return _enqueue('sdk.connect', (context) {
        return _bindings.sdkConnect(
          _requireHandle(),
          userId,
          token,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _updateAccessToken(Map<String, Object?> request) {
    return using((arena) {
      final accessToken =
          stringField(request, 'accessToken').toNativeUtf8(allocator: arena);
      final tenantId =
          request['tenantId']?.toString().toNativeUtf8(allocator: arena) ??
              nullptr;
      return _enqueue('sdk.update_access_token', (context) {
        return _bindings.sdkUpdateAccessToken(
          _requireHandle(),
          accessToken,
          tenantId,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _createTextMessage(Map<String, Object?> request) {
    return using((arena) {
      final conversationId =
          stringField(request, 'conversationId').toNativeUtf8(allocator: arena);
      final text = stringField(request, 'text').toNativeUtf8(allocator: arena);
      return _enqueue('message.create_text', (context) {
        return _bindings.messageCreateText(
          _requireHandle(),
          conversationId,
          text,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _listMessages(Map<String, Object?> request) {
    return using((arena) {
      final conversationId =
          stringField(request, 'conversationId').toNativeUtf8(allocator: arena);
      return _enqueue('message.list', (context) {
        return _bindings.messageList(
          _requireHandle(),
          conversationId,
          intField(request, 'beforeSeq', 0),
          intField(request, 'limit', 20),
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _messageMutation(
      _Async2StringFn fn, Map<String, Object?> request) {
    return using((arena) {
      final conversationId =
          stringField(request, 'conversationId').toNativeUtf8(allocator: arena);
      final messageId =
          stringField(request, 'messageId').toNativeUtf8(allocator: arena);
      return _enqueue('message.mutation', (context) {
        return fn(
          _requireHandle(),
          conversationId,
          messageId,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _syncMessages(Map<String, Object?> request) {
    return using((arena) {
      final conversationId =
          stringField(request, 'conversationId').toNativeUtf8(allocator: arena);
      return _enqueue('sync.messages', (context) {
        return _bindings.syncMessages(
          _requireHandle(),
          conversationId,
          intField(request, 'lastSeq', 0),
          intField(request, 'limit', 50),
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _mediaUploadPath(
    _Async2StringFn fn,
    Map<String, Object?> request,
  ) {
    return using((arena) {
      final path =
          stringField(request, 'absolutePath').toNativeUtf8(allocator: arena);
      final optionsJson = _optionalJsonString(request, 'options')
          .toNativeUtf8(allocator: arena);
      return _enqueue('media.upload_path', (context) {
        return fn(
          _requireHandle(),
          path,
          optionsJson,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _mediaUploadBytes(Map<String, Object?> request) {
    return using((arena) {
      final bytes = bytesField(request, 'bytes');
      final bytesPtr = arena<Uint8>(bytes.length);
      bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      final bytesView = arena<NativeFlareBytesView>();
      bytesView.ref.ptr = bytesPtr;
      bytesView.ref.len = bytes.length;
      final fileName =
          stringField(request, 'fileName').toNativeUtf8(allocator: arena);
      final mimeType = stringField(request, 'mimeType').toNativeUtf8(
        allocator: arena,
      );
      final optionsJson = _optionalJsonString(request, 'options')
          .toNativeUtf8(allocator: arena);
      return _enqueue('media.upload_bytes', (context) {
        return _bindings.mediaUploadBytes(
          _requireHandle(),
          bytesView.ref,
          fileName,
          mimeType,
          optionsJson,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _mediaDeleteFile(Map<String, Object?> request) {
    return using((arena) {
      final fileId =
          stringField(request, 'fileId').toNativeUtf8(allocator: arena);
      return _enqueue('media.delete_file', (context) {
        return _bindings.mediaDeleteFile(
          _requireHandle(),
          fileId,
          boolFieldWithDefault(request, false, 'hardDelete'),
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  /// The C function answers through the result callback with `{cancelled: bool}`.
  Future<bool> _mediaCancelUserFileDownload(Map<String, Object?> request) {
    return _callWithString(_bindings.mediaCancelUserFileDownload,
            stringField(request, 'downloadKey'))
        .then((result) => result is Map
            ? result['cancelled'] == true
            : result == true);
  }

  Future<Object?> _call0(_Async0Fn fn) {
    return _enqueue('native.call0', (context) {
      return fn(_requireHandle(), context, _resultCallback.nativeFunction);
    });
  }

  Future<Object?> _callWithString(_AsyncStringFn fn, String value) {
    return using((arena) {
      final ptr = value.toNativeUtf8(allocator: arena);
      return _enqueue('native.string', (context) {
        return fn(
            _requireHandle(), ptr, context, _resultCallback.nativeFunction);
      });
    });
  }

  Future<Object?> _callWithJson(_AsyncStringFn fn, Object? request) {
    return _callWithString(fn,
        jsonEncode(wireEncodeRequest(request ?? const <String, Object?>{})));
  }

  Future<Object?> _callBuildJson(Object? request) {
    return _callWithString(_bindings.messageBuild,
        jsonEncode(wireEncodeRequest(request ?? const <String, Object?>{})));
  }

  Future<Object?> _dispatchJson(Map<String, Object?> request,
      [String? opOverride]) {
    return using((arena) {
      final op = (opOverride ?? request['op']?.toString() ?? '')
          .toNativeUtf8(allocator: arena);
      final params = Map<String, Object?>.from(request)..remove('op');
      final json =
          jsonEncode(wireEncodeRequest(params)).toNativeUtf8(allocator: arena);
      return _enqueue('message.dispatch', (context) {
        return _bindings.messageDispatch(
          _requireHandle(),
          op,
          json,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _capabilityDispatchJson(Map<String, Object?> request,
      [String? opOverride]) {
    return using((arena) {
      final op = (opOverride ?? request['op']?.toString() ?? '')
          .toNativeUtf8(allocator: arena);
      final params = Map<String, Object?>.from(request)..remove('op');
      final json =
          jsonEncode(wireEncodeRequest(params)).toNativeUtf8(allocator: arena);
      return _enqueue('capability.dispatch', (context) {
        return _bindings.capabilityDispatch(
          _requireHandle(),
          op,
          json,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _mediaDispatchJson(Map<String, Object?> request,
      [String? opOverride]) {
    return using((arena) {
      final op = (opOverride ?? request['op']?.toString() ?? '')
          .toNativeUtf8(allocator: arena);
      final params = Map<String, Object?>.from(request)..remove('op');
      final json =
          jsonEncode(wireEncodeRequest(params)).toNativeUtf8(allocator: arena);
      return _enqueue('media.dispatch', (context) {
        return _bindings.mediaDispatch(
          _requireHandle(),
          op,
          json,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Future<Object?> _contractInvokeJson(String apiId, Object? request) {
    return using((arena) {
      final api = apiId.toNativeUtf8(allocator: arena);
      final json = jsonEncode(
        wireEncodeRequest(request ?? const <String, Object?>{}),
      ).toNativeUtf8(allocator: arena);
      return _enqueue(apiId, (context) {
        return _bindings.sdkInvokeJson(
          _requireHandle(),
          api,
          json,
          context,
          _resultCallback.nativeFunction,
        );
      });
    });
  }

  Map<String, Object?> _subscribeEvents(Object? request) {
    final handler = (request is Map && request['handler'] is NativeEventHandler)
        ? request['handler'] as NativeEventHandler
        : null;
    final contextId = _reserveContextId();
    if (handler != null) {
      _eventSinks[contextId] = handler;
    }
    final subscription = _bindings.eventSubscribe(
      _requireHandle(),
      Pointer<Void>.fromAddress(contextId),
      _eventCallback.nativeFunction,
    );
    if (subscription == 0) {
      _eventSinks.remove(contextId);
      throw const FlareSdkException(
        code: 'event_subscribe_failed',
        message:
            'flare_event_subscribe returned an invalid subscription handle.',
        operation: 'event.subscribe',
      );
    }
    return {'subscription': subscription, 'context': contextId};
  }

  Map<String, Object?> _subscribeEventsBatch(Object? request) {
    final handler = (request is Map && request['handler'] is NativeEventHandler)
        ? request['handler'] as NativeEventHandler
        : null;
    final contextId = _reserveContextId();
    if (handler != null) {
      _eventSinks[contextId] = handler;
    }
    final subscription = _bindings.eventSubscribeBatch(
      _requireHandle(),
      Pointer<Void>.fromAddress(contextId),
      _eventBatchCallback.nativeFunction,
    );
    if (subscription == 0) {
      _eventSinks.remove(contextId);
      throw const FlareSdkException(
        code: 'event_subscribe_failed',
        message:
            'flare_event_subscribe_batch returned an invalid subscription handle.',
        operation: 'event.subscribe_batch',
      );
    }
    return {'subscription': subscription, 'context': contextId};
  }

  void _unsubscribe(Map<String, Object?> request) {
    final subscription = intField(request, 'subscription');
    final context = (request['context'] as num?)?.toInt();
    _bindings.eventUnsubscribe(subscription);
    if (context != null) {
      _eventSinks.remove(context);
    }
  }

  Future<Object?> _enqueue(
      String operation, int Function(Pointer<Void>) start) {
    final id = _reserveContextId();
    final completer = Completer<Object?>();
    _pendingCalls[id] = _PendingCall(operation, completer);
    final code = start(Pointer<Void>.fromAddress(id));
    if (code != 0) {
      _pendingCalls.remove(id);
      throw FlareSdkException(
        code: 'native_error_$code',
        message: 'Native call returned error code $code before callback.',
        operation: operation,
      );
    }
    return completer.future;
  }

  String _takeString(NativeFlareString value) {
    final text = decodeFlareString(value);
    _bindings.stringFree(value);
    return text;
  }
}

final class _PendingCall {
  _PendingCall(this.operation, this.completer);

  final String operation;
  final Completer<Object?> completer;
}

void _handleResultCallback(
  Pointer<Void> context,
  Pointer<NativeFlareError> error,
  NativeFlareString result,
) {
  final call = _pendingCalls.remove(context.address);
  if (call == null) {
    return;
  }

  if (error != nullptr) {
    final message = decodeFlareString(error.ref.message);
    final detailsJson = decodeFlareString(error.ref.detailsJson);
    final code = error.ref.code;
    _NativeBindings.instance?.errorHeapFree(error);
    call.completer.completeError(FlareSdkException.fromNative(
      nativeCode: code,
      message: message.isEmpty ? 'Native operation failed.' : message,
      operation: call.operation,
      details: parseJsonLenient(detailsJson),
    ));
    return;
  }

  final raw = decodeFlareString(result);
  _NativeBindings.instance?.stringFree(result);
  call.completer.complete(parseJsonLenient(raw));
}

void _handleEventCallback(
  Pointer<Void> context,
  int eventType,
  NativeFlareString eventJson,
) {
  final raw = decodeFlareString(eventJson);
  _NativeBindings.instance?.stringFree(eventJson);
  _eventSinks[context.address]?.call(eventType, parseJsonLenient(raw));
}

void _handleEventBatchCallback(
  Pointer<Void> context,
  int eventCount,
  NativeFlareString eventsJson,
) {
  final raw = decodeFlareString(eventsJson);
  _NativeBindings.instance?.stringFree(eventsJson);
  final decoded = parseJsonLenient(raw);
  final sink = _eventSinks[context.address];
  if (sink == null || decoded is! Map) {
    return;
  }
  final events = decoded['events'];
  if (events is! Iterable) {
    return;
  }
  for (final item in events.take(eventCount)) {
    if (item is! Map) {
      continue;
    }
    final eventType = int.tryParse(
      '${item['eventType'] ?? ''}',
    );
    if (eventType == null) {
      continue;
    }
    sink(eventType, item['payload']);
  }
}

void _handleTokenRefreshCallback(Pointer<Void> context, int requestId) {
  _tokenRefreshers[context.address]?.answer(requestId);
}

/// One installed connect token refresher: runs the host function for each
/// request the core makes and hands the outcome back.
final class ConnectTokenRefresh {
  ConnectTokenRefresh({
    required this.refresher,
    required this.complete,
    this.timeout = const Duration(seconds: 20),
  });

  final ConnectTokenRefresher refresher;

  /// Hands one answer to the core; false when it no longer waits for it.
  final bool Function(int requestId, String? token) complete;

  /// How long the core waits for an answer.
  final Duration timeout;

  /// Runs the refresher for [requestId] and completes it. A refresher that
  /// throws or outlasts [timeout] answers with no token.
  Future<bool> answer(int requestId) async {
    String? token;
    try {
      token = await refresher().timeout(timeout);
    } catch (_) {
      token = null;
    }
    return complete(requestId, token);
  }
}

Object? parseJsonLenient(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  try {
    return wireDecodeResponse(jsonDecode(raw));
  } on FormatException {
    return raw;
  }
}

Map<String, Object?> asMap(Object? value) {
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value
        .map((key, entry) => MapEntry(key.toString(), entry as Object?));
  }
  throw ArgumentError.value(
      value, 'request', 'Expected a JSON object request.');
}

Map<String, Object?> asResponseMap(Object? value) {
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value
        .map((key, entry) => MapEntry(key.toString(), entry as Object?));
  }
  if (value is List) {
    return {'items': value};
  }
  return {'value': value};
}

Object? messageForTypedSend(Object? request) {
  final map = asMap(request);
  final message = map['message'];
  if (message is Map<String, Object?>) {
    return message;
  }
  if (message is Map) {
    return message
        .map((key, entry) => MapEntry(key.toString(), entry as Object?));
  }
  return map;
}

String stringField(Object? request, String key) {
  final map = asMap(request);
  final value = map[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw ArgumentError('Missing required string field `$key`.');
}

int intField(
  Map<String, Object?> request,
  String key, [
  int defaultValue = -1,
]) {
  final value = request[key];
  if (value == null && defaultValue >= 0) {
    return defaultValue;
  }
  if (value is num) {
    return value.toInt();
  }
  throw ArgumentError('Missing required integer field `$key`.');
}

bool boolField(Map<String, Object?> request, String key) {
  final value = request[key];
  if (value is bool) {
    return value;
  }
  throw ArgumentError('Missing required boolean field `$key`.');
}

bool boolFieldWithDefault(
  Map<String, Object?> request,
  bool defaultValue,
  String key,
) {
  final value = request[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is bool) {
    return value;
  }
  throw ArgumentError('Invalid boolean field `$key`.');
}

String _optionalJsonString(
  Map<String, Object?> request,
  String key,
) {
  final value = request[key];
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? 'null' : text;
  }
  return jsonEncode(wireEncodeRequest(value));
}

List<Object?> listField(Object? request, String key) {
  final map = asMap(request);
  final value = map[key];
  if (value is List) {
    return value;
  }
  throw ArgumentError('Missing required list field `$key`.');
}

Uint8List bytesField(Object? request, String key) {
  final map = asMap(request);
  final value = map[key];
  if (value is Uint8List) {
    return value;
  }
  if (value is List<int>) {
    return Uint8List.fromList(value);
  }
  throw ArgumentError('Missing required bytes field `$key`.');
}

int _reserveContextId() => _nextContextId++;

typedef _Async0Fn = int Function(
  int,
  Pointer<Void>,
  Pointer<NativeFunction<_NativeResultCallback>>,
);
typedef _AsyncStringFn = int Function(
  int,
  Pointer<Utf8>,
  Pointer<Void>,
  Pointer<NativeFunction<_NativeResultCallback>>,
);
typedef _Async2StringFn = int Function(
  int,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Void>,
  Pointer<NativeFunction<_NativeResultCallback>>,
);
typedef _AsyncDispatchFn = int Function(
  int,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Void>,
  Pointer<NativeFunction<_NativeResultCallback>>,
);
typedef _AsyncStringBoolFn = int Function(
  int,
  Pointer<Utf8>,
  bool,
  Pointer<Void>,
  Pointer<NativeFunction<_NativeResultCallback>>,
);

final class _NativeBindings {
  _NativeBindings(this.library) {
    instance = this;
  }

  static _NativeBindings? instance;

  final DynamicLibrary library;

  late final int Function() sdkCreate = library
      .lookupFunction<Uint64 Function(), int Function()>('flare_sdk_create');
  late final void Function(int) sdkRelease =
      library.lookupFunction<Void Function(Uint64), void Function(int)>(
          'flare_sdk_release');
  late final void Function() sdkHardReset = library
      .lookupFunction<Void Function(), void Function()>('flare_sdk_hard_reset');
  late final bool Function(int) sdkIsConnected =
      library.lookupFunction<Bool Function(Uint64), bool Function(int)>(
          'flare_sdk_is_connected');
  late final bool Function(int) sdkSessionActive =
      library.lookupFunction<Bool Function(Uint64), bool Function(int)>(
          'flare_sdk_session_active');
  late final int Function(
          int,
          Pointer<Void>,
          Pointer<NativeFunction<_NativeTokenRefreshCallback>>,
          Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>)
      sdkSetConnectTokenRefresher = library.lookupFunction<
              Int32 Function(
                  Uint64,
                  Pointer<Void>,
                  Pointer<NativeFunction<_NativeTokenRefreshCallback>>,
                  Pointer<Void>,
                  Pointer<NativeFunction<_NativeResultCallback>>),
              int Function(
                  int,
                  Pointer<Void>,
                  Pointer<NativeFunction<_NativeTokenRefreshCallback>>,
                  Pointer<Void>,
                  Pointer<NativeFunction<_NativeResultCallback>>)>(
          'flare_sdk_set_connect_token_refresher');
  late final int Function(int, int, Pointer<Utf8>)
      sdkCompleteConnectTokenRefresh = library.lookupFunction<
              Int32 Function(Uint64, Uint64, Pointer<Utf8>),
              int Function(int, int, Pointer<Utf8>)>(
          'flare_sdk_complete_connect_token_refresh');
  late final _AsyncDispatchFn sdkInvokeJson = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncDispatchFn>('flare_sdk_invoke_json');

  late final _AsyncStringFn sdkInit = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_sdk_init');
  late final _Async0Fn sdkUninit = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async0Fn>('flare_sdk_uninit');
  late final int Function(int, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
          Pointer<Void>, Pointer<NativeFunction<_NativeResultCallback>>)
      sdkLogin = library.lookupFunction<
          Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
              Pointer<Void>, Pointer<NativeFunction<_NativeResultCallback>>),
          int Function(
              int,
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Void>,
              Pointer<
                  NativeFunction<_NativeResultCallback>>)>('flare_sdk_login');
  late final _Async2StringFn sdkPrepare = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_sdk_prepare');
  late final _Async2StringFn sdkConnect = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_sdk_connect');
  late final _Async2StringFn sdkUpdateAccessToken = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_sdk_update_access_token');
  late final _Async0Fn sdkLogout = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async0Fn>('flare_sdk_logout');
  late final _Async0Fn sdkCurrentUserId = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async0Fn>('flare_sdk_current_user_id');
  late final _Async0Fn sdkDataRoot = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async0Fn>('flare_sdk_data_root');
  late final _Async0Fn sdkDisconnect = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async0Fn>('flare_sdk_disconnect');
  late final _AsyncDispatchFn mediaDispatch = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncDispatchFn>('flare_media_dispatch_json');
  late final _Async2StringFn messageCreateText = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_message_create_text');
  late final _AsyncStringFn messageSend = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_message_send');
  late final int Function(int, Pointer<Utf8>, int, int, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>) messageList =
      library
          .lookupFunction<
                  Int32 Function(
                      Uint64,
                      Pointer<Utf8>,
                      Uint64,
                      Int32,
                      Pointer<Void>,
                      Pointer<NativeFunction<_NativeResultCallback>>),
                  int Function(int, Pointer<Utf8>, int, int, Pointer<Void>,
                      Pointer<NativeFunction<_NativeResultCallback>>)>(
              'flare_message_list');
  late final _Async2StringFn messageRecall = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_message_recall');
  late final _Async2StringFn messageDelete = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_message_delete');
  late final _AsyncStringFn messageBuild = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_message_build_json');
  late final _AsyncDispatchFn messageDispatch = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncDispatchFn>('flare_message_dispatch_json');
  late final _AsyncDispatchFn capabilityDispatch = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncDispatchFn>('flare_capability_dispatch_json');
  late final _AsyncStringFn syncConversation = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_sdk_sync_conversation');
  late final int Function(int, Pointer<Utf8>, int, int, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>) syncMessages =
      library
          .lookupFunction<
                  Int32 Function(
                      Uint64,
                      Pointer<Utf8>,
                      Uint64,
                      Int32,
                      Pointer<Void>,
                      Pointer<NativeFunction<_NativeResultCallback>>),
                  int Function(int, Pointer<Utf8>, int, int, Pointer<Void>,
                      Pointer<NativeFunction<_NativeResultCallback>>)>(
              'flare_sdk_sync_messages');
  late final _AsyncStringFn presenceGet = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_sdk_get_user_presence');
  late final _AsyncStringFn presenceBatchGet = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_sdk_batch_get_user_presence');
  late final _AsyncStringFn presenceSubscribe = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringFn>('flare_sdk_subscribe_user_presence');

  late final _Async2StringFn mediaUploadFile = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_media_upload_file');
  late final _Async2StringFn mediaUploadImage = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_media_upload_image');
  late final _Async2StringFn mediaUploadVideo = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Pointer<Utf8>, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _Async2StringFn>('flare_media_upload_video');
  late final int Function(
          int,
          NativeFlareBytesView,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>) mediaUploadBytes =
      library.lookupFunction<
              Int32 Function(
                  Uint64,
                  NativeFlareBytesView,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Pointer<Void>,
                  Pointer<NativeFunction<_NativeResultCallback>>),
              int Function(
                  int,
                  NativeFlareBytesView,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Pointer<Void>,
                  Pointer<NativeFunction<_NativeResultCallback>>)>(
          'flare_media_upload_bytes');
  late final _AsyncStringBoolFn mediaDeleteFile = library.lookupFunction<
      Int32 Function(Uint64, Pointer<Utf8>, Bool, Pointer<Void>,
          Pointer<NativeFunction<_NativeResultCallback>>),
      _AsyncStringBoolFn>('flare_media_delete_file');
  late final _AsyncStringFn mediaCancelUserFileDownload =
      library.lookupFunction<
          Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
              Pointer<NativeFunction<_NativeResultCallback>>),
          _AsyncStringFn>('flare_media_cancel_user_file_download');
  late final _AsyncStringFn mediaDownloadFileToDownloads =
      library.lookupFunction<
          Int32 Function(Uint64, Pointer<Utf8>, Pointer<Void>,
              Pointer<NativeFunction<_NativeResultCallback>>),
          _AsyncStringFn>('flare_media_download_file_to_downloads');

  late final int Function(
          int, Pointer<Void>, Pointer<NativeFunction<_NativeEventCallback>>)
      eventSubscribe = library.lookupFunction<
              Uint64 Function(Uint64, Pointer<Void>,
                  Pointer<NativeFunction<_NativeEventCallback>>),
              int Function(int, Pointer<Void>,
                  Pointer<NativeFunction<_NativeEventCallback>>)>(
          'flare_event_subscribe');
  late final int Function(int, Pointer<Void>,
          Pointer<NativeFunction<_NativeEventBatchCallback>>)
      eventSubscribeBatch = library.lookupFunction<
              Uint64 Function(Uint64, Pointer<Void>,
                  Pointer<NativeFunction<_NativeEventBatchCallback>>),
              int Function(int, Pointer<Void>,
                  Pointer<NativeFunction<_NativeEventBatchCallback>>)>(
          'flare_event_subscribe_batch');
  late final void Function(int) eventUnsubscribe =
      library.lookupFunction<Void Function(Uint64), void Function(int)>(
          'flare_event_unsubscribe');
  late final void Function() eventUnsubscribeAll =
      library.lookupFunction<Void Function(), void Function()>(
          'flare_event_unsubscribe_all');

  late final NativeFlareString Function() sdkVersion = library.lookupFunction<
      NativeFlareString Function(),
      NativeFlareString Function()>('flare_sdk_version');
  late final NativeFlareString Function() sdkFfiContractVersion =
      library.lookupFunction<NativeFlareString Function(),
          NativeFlareString Function()>('flare_sdk_ffi_contract_version');
  late final void Function(NativeFlareString) stringFree =
      library.lookupFunction<Void Function(NativeFlareString),
          void Function(NativeFlareString)>('flare_string_free');
  late final void Function(Pointer<NativeFlareError>) errorHeapFree =
      library.lookupFunction<Void Function(Pointer<NativeFlareError>),
          void Function(Pointer<NativeFlareError>)>('flare_error_heap_free');
}
