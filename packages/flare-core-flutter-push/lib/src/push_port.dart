import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';

/// Presentation hints, never an authoritative message, receipt, membership or
/// deep-link URL. The signed-in SDK must authorize/sync before opening anything.
final class PushHint {
  const PushHint(this.applicationId, this.conversationId, this.messageId);
  final String applicationId;
  final String conversationId;
  final String messageId;

  static PushHint? parse(Map<String, dynamic> data) {
    String? read(String key) {
      final v = data[key];
      return v is String &&
              v.isNotEmpty &&
              v.length <= 256 &&
              !v.runes.any((r) => r < 32 || r == 127)
          ? v
          : null;
    }

    final app = read('tenant_id');
    final conversation = read('conversation_id');
    final message = read('message_id');
    return app == null || conversation == null || message == null
        ? null
        : PushHint(app, conversation, message);
  }
}

/// Runtime adaptation only. No account, binding ID, bearer, token journal or
/// registration retry state is owned here. Rust owns those through normal APIs.
final class PushBindingCallbacks {
  const PushBindingCallbacks({
    required this.permission,
    required this.token,
    required this.invalidate,
    required this.reconcile,
  });

  factory PushBindingCallbacks.core(FlareImClient client) {
    final bridge = NativePushLifecycleBridge(client);
    return PushBindingCallbacks(
      permission: (allowed) async {
        await bridge.onPermissionChanged(allowed);
      },
      token: (token) async {
        await bridge.onTokenRefresh(token);
      },
      invalidate: (provider) async {
        await bridge.onTokenInvalidated(provider);
      },
      reconcile: () async {
        await bridge.onResume();
      },
    );
  }

  /// Social/other composition using the same core-owned L1 dispatch surface.
  /// This does not create another handle or duplicate lifecycle behavior.
  factory PushBindingCallbacks.dispatch(
    Future<Object?> Function(String, Map<String, Object?>) invoke,
  ) {
    return PushBindingCallbacks(
      permission: (allowed) async {
        await invoke('sdk.set_push_permission', {'allowed': allowed});
      },
      token: (token) async {
        await invoke('sdk.update_push_token', {
          'provider': token.provider,
          'platform': token.platform,
          'token': token.token,
        });
      },
      invalidate: (provider) async {
        await invoke('sdk.clear_push_token', {'provider': provider});
      },
      reconcile: () async {
        await invoke('sdk.reconcile_push', const {});
      },
    );
  }

  final Future<void> Function(bool) permission;
  final Future<void> Function(PushTokenInput) token;
  final Future<void> Function(String) invalidate;
  final Future<void> Function() reconcile;
}

abstract interface class NativePushPort {
  /// Sets up channels/listeners only. Must not request system permission.
  Future<void> initialize();
  String get platform;
  String get provider;
  Future<bool> permission({bool request = false});
  Future<String?> token();
  Stream<void> get tokenChanges;
  Stream<PushHint> get opened;
  Stream<PushHint> get foreground;
  Future<PushHint?> initialHint();
  Future<void> clearNotifications();
  Future<void> setAutoInit(bool enabled);
}
