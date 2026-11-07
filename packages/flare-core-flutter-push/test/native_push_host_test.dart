import 'dart:async';

import 'package:flare_core_flutter_push/flare_core_flutter_push.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'start reads permission without prompt; no signed-in token registration',
    () async {
      final f = _Fixture();
      await f.host.start();
      expect(f.port.prompts, 0);
      expect(f.calls, ['permission:false', 'permission:false', 'reconcile']);
      expect(f.port.tokenReads, 0);
      await f.close();
    },
  );

  test(
    'authorized host delegates canonical token and normal resume only',
    () async {
      final f = _Fixture();
      await f.host.setSessionActive(true);
      await f.host.start();
      expect(
        f.calls,
        containsAllInOrder([
          'token:fcm:android',
          'permission:true',
          'reconcile',
        ]),
      );
      expect(f.host.state, PushHostState.listening);
      await f.host.refresh(requestPermission: true);
      expect(f.port.prompts, 1);
      expect(f.port.autoInit, isTrue);
      await f.close();
      expect(f.port.autoInit, isFalse);
    },
  );

  test('OS denial bypasses unresolved token write on resume', () async {
    final f = _Fixture()..tokenWrite = Completer<void>();
    await f.host.setSessionActive(true);
    final starting = f.host.start();
    await f.tokenStarted.future;
    f.port.allowed = false;
    await f.host.onResume();
    expect(f.calls.last, 'permission:false');
    expect(f.host.state, PushHostState.permissionDenied);
    f.tokenWrite!.complete();
    await starting;
    expect(f.host.state, PushHostState.permissionDenied);
    await f.close();
  });

  test(
    'logout fences a late OS token read and clears presented notifications',
    () async {
      final f = _Fixture();
      await f.host.setSessionActive(true);
      f.port.tokenReply = Completer<String?>();
      final starting = f.host.start();
      await f.port.tokenStarted.future;
      final before = f.port.clears;
      await f.host.setSessionActive(false);
      expect(f.port.clears, before + 1);
      f.port.tokenReply!.complete('old-account-token');
      await starting;
      expect(f.calls.where((v) => v.startsWith('token:')), isEmpty);
      await f.close();
    },
  );

  test(
    'token callback burst has one in-flight SDK write and coalesces latest read',
    () async {
      final f = _Fixture()..tokenWrite = Completer<void>();
      await f.host.setSessionActive(true);
      final starting = f.host.start();
      await f.tokenStarted.future;
      for (var i = 0; i < 100; i++) {
        f.port.changes.add(null);
      }
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.where((v) => v.startsWith('token:')).length, 1);
      f.tokenWrite!.complete();
      await starting;
      expect(f.calls.where((v) => v.startsWith('token:')).length, 2);
      await f.close();
    },
  );

  test(
    'cold/warm hints never dispatch business writes; logout drops late hints',
    () async {
      final f = _Fixture();
      final hints = <PushHint>[];
      void observe() {
        if (f.host.hint.value case final value?) hints.add(value);
      }

      f.host.hint.addListener(observe);
      await f.host.setSessionActive(true);
      f.port.initial = const PushHint('app-a', 'conversation-a', 'message-a');
      await f.host.start();
      f.port.opens.add(const PushHint('app-a', 'conversation-b', 'message-b'));
      expect(hints.length, 2);
      await f.host.setSessionActive(false);
      f.port.opens.add(const PushHint('app-a', 'old', 'old'));
      expect(hints.length, 2);
      expect(
        f.calls.every(
          (v) =>
              v == 'reconcile' ||
              v.startsWith('permission:') ||
              v.startsWith('token:'),
        ),
        isTrue,
      );
      expect(f.host.hint.value, isNull);
      f.host.hint.removeListener(observe);
      await f.close();
    },
  );

  test(
    'failed plugin setup is safe unavailable, removes subscriptions, explicit retry works',
    () async {
      final f = _Fixture();
      f.port.fail = true;
      await f.host.start();
      expect(f.host.state, PushHostState.unavailable);
      expect(f.port.autoInit, isFalse);
      f.port.fail = false;
      await f.host.start();
      expect(f.port.initializations, 2);
      await f.close();
    },
  );

  test(
    'stop during plugin startup prevents late auto-init or subscription',
    () async {
      final f = _Fixture();
      f.port.initializeReply = Completer<void>();
      final starting = f.host.start();
      await f.port.initializeStarted.future;
      await f.host.stop();
      f.port.initializeReply!.complete();
      await starting;
      expect(f.port.autoInit, isFalse);
      expect(f.host.state, PushHostState.stopped);
      await f.close();
    },
  );

  test('untrusted hints require bounded strings and no routing coercion', () {
    expect(
      PushHint.parse({
        'tenant_id': 1,
        'conversation_id': 'c',
        'message_id': 'm',
      }),
      isNull,
    );
    expect(
      PushHint.parse({
        'tenant_id': 'a',
        'conversation_id': 'c\n',
        'message_id': 'm',
      }),
      isNull,
    );
    expect(
      PushHint.parse({
        'tenant_id': 'a',
        'conversation_id': 'c',
        'message_id': 'm',
      })?.messageId,
      'm',
    );
  });

  test(
    'missing OS token retires desired provider before any permission enable',
    () async {
      final f = _Fixture();
      f.port.tokenReply = Completer<String?>()..complete(null);
      await f.host.setSessionActive(true);
      await f.host.start();
      expect(f.host.state, PushHostState.waitingForToken);
      expect(f.calls, contains('invalidate:fcm'));
      expect(f.calls, isNot(contains('permission:true')));
      await f.close();
    },
  );

  test(
    'production channel definitions match sound/badge combinations without OS override',
    () {
      final channels = messageChannels('Messages', 'Quiet messages');
      expect(channels.map((c) => c.id).toSet().length, 4);
      expect(channels.map((c) => c.id), [
        messageChannelId,
        quietMessageChannelId,
        noBadgeMessageChannelId,
        quietNoBadgeMessageChannelId,
      ]);
      expect(channels.map((c) => c.playSound), [true, false, true, false]);
      expect(channels.map((c) => c.showBadge), [true, true, false, false]);
      expect(
        channels.where((c) => !c.playSound).every((c) => !c.enableVibration),
        isTrue,
      );
    },
  );

  test(
    'production background entry point does not start SDK or fabricate a message',
    () async {
      await flareFirebaseBackgroundMessage(
        const RemoteMessage(
          data: {
            'tenant_id': 'untrusted',
            'conversation_id': 'opaque',
            'message_id': 'hint-only',
          },
        ),
      );
    },
  );

  test(
    'dispatch adapter forwards only the existing core L1 operations',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final binding = PushBindingCallbacks.dispatch((op, args) async {
        calls.add((op, args));
        return null;
      });
      await binding.permission(false);
      await binding.reconcile();
      expect(calls.map((c) => c.$1), [
        'sdk.set_push_permission',
        'sdk.reconcile_push',
      ]);
      expect(calls.first.$2, {'allowed': false});
      expect(calls.last.$2, isEmpty);
    },
  );
}

final class _Fixture {
  final port = _Port();
  final calls = <String>[];
  final tokenStarted = Completer<void>();
  Completer<void>? tokenWrite;
  late final host = NativePushHost(
    port: port,
    binding: PushBindingCallbacks(
      permission: (allowed) async {
        calls.add('permission:$allowed');
      },
      token: (token) async {
        calls.add('token:${token.provider}:${token.platform}');
        if (!tokenStarted.isCompleted) tokenStarted.complete();
        if (tokenWrite != null) await tokenWrite!.future;
      },
      invalidate: (provider) async {
        calls.add('invalidate:$provider');
      },
      reconcile: () async {
        calls.add('reconcile');
      },
    ),
  );
  Future<void> close() async {
    await host.stop();
    host.dispose();
    await port.changes.close();
    await port.opens.close();
    await port.messages.close();
  }
}

final class _Port implements NativePushPort {
  bool allowed = true;
  bool autoInit = false;
  bool fail = false;
  int prompts = 0, tokenReads = 0, initializations = 0, clears = 0;
  PushHint? initial;
  Completer<String?>? tokenReply;
  Completer<void>? initializeReply;
  final initializeStarted = Completer<void>();
  final tokenStarted = Completer<void>();
  final changes = StreamController<void>.broadcast(sync: true);
  final opens = StreamController<PushHint>.broadcast(sync: true);
  final messages = StreamController<PushHint>.broadcast(sync: true);
  @override
  String get platform => 'android';
  @override
  String get provider => 'fcm';
  @override
  Future<void> initialize() async {
    initializations++;
    if (!initializeStarted.isCompleted) initializeStarted.complete();
    if (initializeReply != null) await initializeReply!.future;
    if (fail)
      throw StateError('secret test driver diagnostics must not escape');
  }

  @override
  Future<bool> permission({bool request = false}) async {
    if (request) prompts++;
    return allowed;
  }

  @override
  Future<String?> token() async {
    tokenReads++;
    if (!tokenStarted.isCompleted) tokenStarted.complete();
    return tokenReply == null ? 'os-token' : tokenReply!.future;
  }

  @override
  Stream<void> get tokenChanges => changes.stream;
  @override
  Stream<PushHint> get opened => opens.stream;
  @override
  Stream<PushHint> get foreground => messages.stream;
  @override
  Future<PushHint?> initialHint() async => initial;
  @override
  Future<void> clearNotifications() async {
    clears++;
  }

  @override
  Future<void> setAutoInit(bool enabled) async {
    autoInit = enabled;
  }
}
