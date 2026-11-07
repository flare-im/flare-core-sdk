import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flare_core_flutter_update/flare_core_flutter_update.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('test/flare_core_flutter_update');
  const store = FlareUpdateOpenStore(
    store: 'play',
    url: 'https://play.google.com/store/apps/details?id=com.acme.chat',
    packageName: 'com.acme.chat',
    immediate: true,
  );
  const release = FlareUpdateRelease(
    releaseId: 'rel',
    version: '2.4.0',
    build: 20400,
    kind: FlareUpdateKind.store,
  );
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, null);
  });

  FlutterUpdateInstaller installer({
    bool native = true,
    FlareUpdateUrlOpener? openUrl,
  }) =>
      FlutterUpdateInstaller(
        methods: methods,
        nativeInstaller: native,
        nativeHandoff: false,
        openUrl: openUrl,
      );

  test('sends the plan to the host and reads its outcome', () async {
    answer((_) => {'outcome': 'completed'});
    final result = await installer().execute(store);
    expect(result.outcome, FlareUpdateOutcome.completed);
    expect(calls.single.method, 'execute');
    expect(calls.single.arguments, store.toMap());
  });

  test('a refused package comes back with its code', () async {
    answer(
      (_) => {
        'outcome': 'failed',
        'code': FlareUpdateErrorCodes.signatureMismatch,
      },
    );
    final result = await installer().execute(
      const FlareUpdateInstallPackage(
        path: '/data/cache/a.apk',
        sha256: 'aa',
        signingCertSha256: 'bb',
        build: 20400,
        sizeBytes: 1024,
      ),
    );
    expect(result.outcome, FlareUpdateOutcome.failed);
    expect(result.code, FlareUpdateErrorCodes.signatureMismatch);
  });

  test('a host error is a failed install', () async {
    answer((_) => throw PlatformException(code: 'update'));
    final result = await installer().execute(store);
    expect(result.code, FlareUpdateErrorCodes.installFailed);
  });

  test('a host without the plugin is a failed install', () async {
    final result = await installer().execute(store);
    expect(result.code, FlareUpdateErrorCodes.installFailed);
  });

  test('asks the host about a release', () async {
    answer((_) => false);
    expect(await installer().canPrompt(release), isFalse);
    expect(calls.single.method, 'canPrompt');
  });

  test('a host without an answer does not hold the prompt back', () async {
    expect(await installer().canPrompt(release), isTrue);
  });

  test('finishes a handoff on the host', () async {
    answer((_) => {'outcome': 'completed'});
    final result = await installer().completeHandoff();
    expect(result.outcome, FlareUpdateOutcome.completed);
    expect(calls.single.method, 'completeHandoff');
  });

  group('without a native installer', () {
    test('opens the link of the plan', () async {
      final opened = <Uri>[];
      final result = await installer(
        native: false,
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
      ).execute(
        const FlareUpdateOpenStore(store: 'website', url: 'https://example.com/a'),
      );
      expect(result.outcome, FlareUpdateOutcome.completed);
      expect(opened, [Uri.parse('https://example.com/a')]);
      expect(calls, isEmpty);
    });

    test('fails when nothing can open it', () async {
      final result = await installer(
        native: false,
        openUrl: (_) async => false,
      ).execute(const FlareUpdateOpenStore(store: 'website', url: 'https://a'));
      expect(result.code, FlareUpdateErrorCodes.installFailed);
    });

    test('fails a plan without a link', () async {
      var opened = false;
      final result = await installer(
        native: false,
        openUrl: (_) async => opened = true,
      ).execute(const FlareUpdateUnsupportedPlan('desktopUpdater'));
      expect(result.code, FlareUpdateErrorCodes.installFailed);
      expect(opened, isFalse);
    });

    test('nothing holds the prompt back', () async {
      expect(await installer(native: false).canPrompt(release), isTrue);
    });
  });

  test('no handoffs where the host has none', () async {
    expect(await installer().handoffs().isEmpty, isTrue);
  });
}
