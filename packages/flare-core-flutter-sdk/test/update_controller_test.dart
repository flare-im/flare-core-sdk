import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

const Duration _interval = Duration(milliseconds: 30);

Map<String, Object?> _release({
  String kind = 'package',
  int build = 20400,
  bool mandatory = false,
}) =>
    {
      'releaseId': 'rel_01JC8W',
      'version': '2.4.0',
      'build': build,
      'notes': ['Scheduled messages'],
      'sizeBytes': 52428800,
      'mandatory': mandatory,
      'recommended': false,
      'kind': kind,
    };

Map<String, Object?> _status(
  String state, {
  Map<String, Object?>? release,
  bool noRelease = false,
  String prompt = 'none',
  bool blockUi = false,
  bool readOnly = false,
  String? blockReason,
  Map<String, Object?>? error,
  String distribution = 'direct',
}) =>
    {
      'state': state,
      'current': {
        'version': '2.3.2',
        'build': 20302,
        'channel': 'stable',
        'distribution': distribution,
      },
      'release': noRelease ? null : release ?? _release(),
      'progress': null,
      'prompt': prompt,
      'blockUi': blockUi,
      'readOnly': readOnly,
      'blockReason': blockReason,
      'lastCheckedAt': null,
      'error': error,
    };

const Map<String, Object?> _packagePlan = {
  'kind': 'installPackage',
  'path': '/data/cache/2.4.0-20400.apk',
  'sha256': 'aa',
  'signingCertSha256': 'bb',
  'build': 20400,
  'sizeBytes': 52428800,
};

void main() {
  late _FakeEngine engine;
  late _FakeInstaller installer;
  late StreamController<void> foreground;
  late List<Object> errors;

  setUp(() {
    engine = _FakeEngine();
    installer = _FakeInstaller();
    foreground = StreamController<void>.broadcast();
    errors = [];
  });

  tearDown(() async {
    await foreground.close();
    await engine.close();
    await installer.close();
  });

  Future<FlareUpdateController> controller([
    Map<String, Object?>? initial,
  ]) async {
    engine.answers[FlareUpdateOperations.getState] =
        initial ?? _status('available');
    final controller = FlareUpdateController(
      engine: engine,
      installer: installer,
      foreground: foreground.stream,
      onError: (error, _) => errors.add(error),
      pollInterval: _interval,
    )..install();
    await _settle();
    return controller;
  }

  group('reading the status', () {
    test('reads on start, on the foreground and on login', () async {
      final sdk = await controller();
      expect(engine.count(FlareUpdateOperations.getState), 1);
      expect(sdk.status?.state, FlareUpdateState.available);

      foreground.add(null);
      await _settle();
      expect(engine.count(FlareUpdateOperations.getState), 2);

      sdk.onLoginSucceeded();
      await _settle();
      expect(engine.count(FlareUpdateOperations.getState), 3);
      await sdk.dispose();
    });

    test('a return says so: the lifecycle report may come after it', () async {
      final sdk = await controller();
      expect(engine.paramsOf(FlareUpdateOperations.getState).single, isEmpty);

      foreground.add(null);
      await _settle();
      expect(engine.paramsOf(FlareUpdateOperations.getState).last, {
        'foreground': true,
      });

      sdk.onLoginSucceeded();
      await _settle();
      expect(engine.paramsOf(FlareUpdateOperations.getState).last, isEmpty);
      await sdk.dispose();
    });

    test('a refused login reads the status: no event says why', () async {
      final sdk = await controller(_status('idle', noRelease: true));

      engine.answers[FlareUpdateOperations.getState] = _status(
        'required',
        noRelease: true,
        prompt: 'modal',
        readOnly: true,
      );
      sdk.onLoginFailed();
      await _settle();

      expect(sdk.status?.state, FlareUpdateState.required);
      expect(sdk.status?.readOnly, isTrue);
      await sdk.dispose();
    });

    test('polls a running state that stays silent, and stops with it',
        () async {
      final sdk = await controller(_status('downloading'));
      await _waitFor(() => engine.count(FlareUpdateOperations.getState) >= 2);

      engine.answers[FlareUpdateOperations.getState] =
          _status('readyToInstall');
      await _waitFor(() => sdk.status?.state == FlareUpdateState.readyToInstall);
      final reads = engine.count(FlareUpdateOperations.getState);

      await Future<void>.delayed(_interval * 3);
      expect(engine.count(FlareUpdateOperations.getState), reads);
      await sdk.dispose();
    });

    for (final running in ['checking', 'verifying']) {
      test('polls $running too', () async {
        final sdk = await controller(_status(running));
        await _waitFor(() => engine.count(FlareUpdateOperations.getState) >= 2);
        await sdk.dispose();
      });
    }

    test('a check answers at once and the poll brings its result', () async {
      final sdk = await controller(_status('idle', noRelease: true));
      final running = _status('checking', noRelease: true);
      engine.answers[FlareUpdateOperations.check] = running;
      engine.answers[FlareUpdateOperations.getState] = running;

      final answer = await sdk.check();
      expect(answer?.state, FlareUpdateState.checking);
      expect(engine.paramsOf(FlareUpdateOperations.check).single, {
        'manual': true,
      });
      await _waitFor(() => engine.count(FlareUpdateOperations.getState) >= 2);

      engine.answers[FlareUpdateOperations.getState] = _status('available');
      await _waitFor(() => sdk.status?.state == FlareUpdateState.available);
      final reads = engine.count(FlareUpdateOperations.getState);

      await Future<void>.delayed(_interval * 3);
      expect(engine.count(FlareUpdateOperations.getState), reads);
      await sdk.dispose();
    });

    test('a language change reaches the engine and comes back', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.setLocale] = _status(
        'required',
        release: _release(mandatory: true),
        blockReason: 'This build is no longer supported',
      );

      await sdk.setLocale('en-US');

      expect(engine.paramsOf(FlareUpdateOperations.setLocale).single, {
        'locale': 'en-US',
      });
      expect(sdk.status?.blockReason, 'This build is no longer supported');
      await sdk.dispose();
    });

    test('a language the engine refuses is no update error', () async {
      final sdk = await controller();
      engine.refusals[FlareUpdateOperations.setLocale] =
          const FlareUpdateException(FlareUpdateErrorCodes.installFailed);

      await sdk.setLocale('en-US');

      expect(sdk.status?.error, isNull);
      expect(errors, hasLength(1));
      await sdk.dispose();
    });

    test('a language set before the engine is up waits for its first status',
        () async {
      engine.answers[FlareUpdateOperations.getState] = _status('available');
      final sdk = FlareUpdateController(
        engine: engine,
        installer: installer,
        foreground: foreground.stream,
        pollInterval: _interval,
      );

      await sdk.setLocale('en-US');
      expect(engine.count(FlareUpdateOperations.setLocale), 0);

      sdk.install();
      await _settle();

      expect(engine.paramsOf(FlareUpdateOperations.setLocale).single, {
        'locale': 'en-US',
      });
      await sdk.dispose();
    });

    test('a language the engine refused goes again with the next status',
        () async {
      final sdk = await controller();
      engine.refusals[FlareUpdateOperations.setLocale] =
          const FlareUpdateException(FlareUpdateErrorCodes.installFailed);

      await sdk.setLocale('en-US');
      expect(engine.count(FlareUpdateOperations.setLocale), 1);

      sdk.onLoginSucceeded();
      await _settle();
      expect(engine.count(FlareUpdateOperations.setLocale), 2);

      sdk.onLoginSucceeded();
      await _settle();
      expect(engine.count(FlareUpdateOperations.setLocale), 2);
      await sdk.dispose();
    });

    test('two quick changes arrive in order', () async {
      final sdk = await controller();

      await Future.wait([sdk.setLocale('en-US'), sdk.setLocale('zh-CN')]);

      expect(
        engine
            .paramsOf(FlareUpdateOperations.setLocale)
            .map((params) => params['locale']),
        ['en-US', 'zh-CN'],
      );
      await sdk.dispose();
    });

    test('does not poll any other state', () async {
      final sdk = await controller(_status('installing'));
      await Future<void>.delayed(_interval * 3);
      expect(engine.count(FlareUpdateOperations.getState), 1);
      await sdk.dispose();
    });

    test('an event holds the poll back', () async {
      final sdk = await controller(_status('downloading'));
      engine.events.add(_status('readyToInstall'));
      await _settle();
      await Future<void>.delayed(_interval * 3);
      expect(engine.count(FlareUpdateOperations.getState), 1);
      await sdk.dispose();
    });

    test('takes every return value as the latest status', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.check] =
          _status('upToDate', noRelease: true);
      await sdk.check();
      expect(sdk.status?.state, FlareUpdateState.upToDate);
      expect(engine.paramsOf(FlareUpdateOperations.check).single, {
        'manual': true,
      });
      await sdk.dispose();
    });

    test('drops a malformed event and keeps the last status', () async {
      final sdk = await controller();
      engine.events.add({'state': 'unheardOf'});
      await _settle();
      expect(sdk.status?.state, FlareUpdateState.available);
      expect(errors.single, isA<FlareUpdateWireError>());
      await sdk.dispose();
    });
  });

  group('update', () {
    test('runs download, install and report in order', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.download] =
          _status('readyToInstall');
      engine.answers[FlareUpdateOperations.install] = _packagePlan;
      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('installing');
      installer.result =
          const FlareUpdateInstallResult(FlareUpdateOutcome.completed);
      engine.calls.clear();

      await sdk.update();

      expect(engine.routes(), [
        FlareUpdateOperations.download,
        FlareUpdateOperations.install,
        FlareUpdateOperations.getState,
        FlareUpdateOperations.reportInstall,
      ]);
      expect(engine.calls.first.params, {'allowMetered': false});
      expect(engine.calls.last.params, {'outcome': 'completed'});
      expect(installer.executed.single, isA<FlareUpdateInstallPackage>());
      await sdk.dispose();
    });

    test('waits for a download that returns early', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.getState] = _status('downloading');
      engine.answers[FlareUpdateOperations.download] = _status('downloading');
      engine.answers[FlareUpdateOperations.install] = _packagePlan;
      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('installing');
      final run = sdk.update();
      await _settle();
      expect(installer.executed, isEmpty);

      engine.answers[FlareUpdateOperations.getState] =
          _status('readyToInstall');
      await run;
      expect(installer.executed, hasLength(1));
      await sdk.dispose();
    });

    test('stops when the download fails', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.download] = _status(
        'failed',
        error: {'code': FlareUpdateErrorCodes.hashMismatch, 'retryable': true},
      );
      await sdk.update();
      expect(installer.executed, isEmpty);
      expect(engine.count(FlareUpdateOperations.install), 0);
      expect(sdk.status?.error?.code, FlareUpdateErrorCodes.hashMismatch);
      await sdk.dispose();
    });

    test('a store release skips the download', () async {
      final store = _release(kind: 'store');
      final sdk = await controller(
        _status('available', release: store, distribution: 'play'),
      );
      engine.answers[FlareUpdateOperations.install] = const {
        'kind': 'openStore',
        'store': 'play',
        'immediate': false,
      };
      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('installing', release: store);
      await sdk.update();
      expect(engine.count(FlareUpdateOperations.download), 0);
      expect(engine.paramsOf(FlareUpdateOperations.reportInstall).single, {
        'outcome': 'completed',
      });
      await sdk.dispose();
    });

    test('a metered refusal makes the next update allow metered', () async {
      final sdk = await controller();
      engine.refusals[FlareUpdateOperations.download] =
          const FlareUpdateException(
        FlareUpdateErrorCodes.meteredConfirmationRequired,
        retryable: true,
      );
      await sdk.update();
      expect(
        sdk.status?.error?.code,
        FlareUpdateErrorCodes.meteredConfirmationRequired,
      );

      engine.answers[FlareUpdateOperations.download] =
          _status('readyToInstall');
      engine.answers[FlareUpdateOperations.install] = _packagePlan;
      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('installing');
      await sdk.update();

      expect(
        engine
            .paramsOf(FlareUpdateOperations.download)
            .map((params) => params['allowMetered']),
        [false, true],
      );
      expect(sdk.status?.error, isNull);
      await sdk.dispose();
    });

    test('a metered error in the status counts the same', () async {
      final sdk = await controller(_status(
        'available',
        error: {'code': FlareUpdateErrorCodes.meteredConfirmationRequired},
      ));
      engine.answers[FlareUpdateOperations.download] = _status('available');
      await sdk.update();
      expect(engine.paramsOf(FlareUpdateOperations.download).single, {
        'allowMetered': true,
      });
      await sdk.dispose();
    });
  });

  group('the Kit callbacks', () {
    for (final state in ['available', 'downloading', 'verifying']) {
      test('later defers in $state', () async {
        final sdk = await controller(_status(state, prompt: 'sheet'));
        engine.answers[FlareUpdateOperations.defer] = _status(state);
        await sdk.later();
        expect(engine.count(FlareUpdateOperations.defer), 1);
        expect(sdk.status?.prompt, FlareUpdatePromptForm.none);
        await sdk.dispose();
      });
    }

    test('a download put aside waits for the user', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.getState] = _status('downloading');
      engine.answers[FlareUpdateOperations.download] = _status('downloading');
      engine.answers[FlareUpdateOperations.defer] = _status('downloading');
      final run = sdk.update();
      await _settle();

      await sdk.later();
      engine.events.add(_status('readyToInstall', prompt: 'sheet'));
      await run;

      expect(installer.executed, isEmpty);
      expect(engine.count(FlareUpdateOperations.install), 0);
      expect(sdk.status?.state, FlareUpdateState.readyToInstall);

      engine.answers[FlareUpdateOperations.install] = _packagePlan;
      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('installing');
      await sdk.update();
      expect(installer.executed, hasLength(1));
      await sdk.dispose();
    });

    test('binds the prompt the engine gives', () async {
      final sdk = await controller(_status('available', prompt: 'sheet'));
      engine.answers[FlareUpdateOperations.markPrompted] =
          _status('available', prompt: 'sheet');
      engine.answers[FlareUpdateOperations.defer] =
          _status('available', prompt: 'badge');

      await sdk.markPrompted();

      expect(engine.paramsOf(FlareUpdateOperations.markPrompted).single, {
        'build': 20400,
        'form': 'sheet',
      });
      expect(sdk.status?.prompt, FlareUpdatePromptForm.sheet);

      await sdk.later();
      expect(sdk.status?.prompt, FlareUpdatePromptForm.badge);
      await sdk.dispose();
    });

    test('a forced state needs no release', () async {
      final sdk = await controller(
        _status('required', noRelease: true, prompt: 'modal'),
      );
      expect(sdk.status?.canContinueReadOnly, isTrue);

      await sdk.markPrompted();
      expect(engine.paramsOf(FlareUpdateOperations.markPrompted).single, {
        'form': 'modal',
      });

      await sdk.update();
      expect(engine.count(FlareUpdateOperations.install), 0);
      expect(installer.executed, isEmpty);

      engine.answers[FlareUpdateOperations.defer] =
          _status('required', noRelease: true, readOnly: true);
      await sdk.continueReadOnly();
      expect(engine.count(FlareUpdateOperations.defer), 1);
      expect(sdk.status?.prompt, FlareUpdatePromptForm.none);
      expect(sdk.status?.readOnly, isTrue);
      await sdk.dispose();
    });

    test('update looks for the release a refusal did not bring', () async {
      final sdk = await controller(
        _status('required', noRelease: true, prompt: 'modal'),
      );
      final running = _status('checking', noRelease: true, prompt: 'modal');
      engine.answers[FlareUpdateOperations.check] = running;
      engine.answers[FlareUpdateOperations.getState] = running;

      final answer = await sdk.update();

      expect(answer?.state, FlareUpdateState.checking);
      expect(engine.paramsOf(FlareUpdateOperations.check).single, {
        'manual': true,
      });
      expect(engine.count(FlareUpdateOperations.install), 0);

      final forced = _release(mandatory: true);
      engine.answers[FlareUpdateOperations.getState] =
          _status('required', release: forced, prompt: 'modal');
      await _waitFor(() => sdk.status?.release != null);
      expect(sdk.status?.state, FlareUpdateState.required);
      expect(engine.count(FlareUpdateOperations.install), 0);
      await sdk.dispose();
    });

    test('a forced download can still be put aside', () async {
      final sdk = await controller(
        _status('downloading', release: _release(mandatory: true)),
      );
      expect(sdk.status?.canContinueReadOnly, isTrue);
      await sdk.dispose();
    });

    test('a badge is not marked', () async {
      final sdk = await controller(_status('available', prompt: 'badge'));
      await sdk.markPrompted();
      expect(engine.count(FlareUpdateOperations.markPrompted), 0);
      await sdk.dispose();
    });

    test('skip names the release on offer', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.skip] =
          _status('idle', noRelease: true);
      await sdk.skip();
      expect(engine.paramsOf(FlareUpdateOperations.skip).single, {
        'build': 20400,
      });
      await sdk.dispose();
    });

    test('a refused install keeps the fallback link of the status', () async {
      final sdk = await controller(_status('readyToInstall'));
      final failed = {
        'code': FlareUpdateErrorCodes.hashMismatch,
        'retryable': true,
        'fallbackUrl': 'https://example.com/download',
      };
      engine.refusals[FlareUpdateOperations.install] =
          const FlareUpdateException(FlareUpdateErrorCodes.hashMismatch);
      engine.answers[FlareUpdateOperations.getState] =
          _status('failed', error: failed);

      await sdk.update();

      expect(sdk.status?.error?.code, FlareUpdateErrorCodes.hashMismatch);
      expect(sdk.status?.error?.retryable, isTrue);
      expect(sdk.status?.error?.fallbackUrl, 'https://example.com/download');
      await sdk.dispose();
    });

    test('a refused route reaches the status', () async {
      final sdk = await controller(
        _status('required', release: _release(mandatory: true)),
      );
      engine.refusals[FlareUpdateOperations.skip] =
          const FlareUpdateException(FlareUpdateErrorCodes.notSkippable);
      await sdk.skip();
      expect(sdk.status?.error?.code, FlareUpdateErrorCodes.notSkippable);
      await sdk.dispose();
    });

    test('read only is the engine\'s: continuing defers, the foreground reads',
        () async {
      final forced = _status(
        'required',
        release: _release(mandatory: true),
        prompt: 'modal',
      );
      final sdk = await controller(forced);
      expect(sdk.status?.canContinueReadOnly, isTrue);

      engine.answers[FlareUpdateOperations.defer] = _status(
        'required',
        release: _release(mandatory: true),
        readOnly: true,
      );
      await sdk.continueReadOnly();

      expect(engine.count(FlareUpdateOperations.defer), 1);
      expect(sdk.status?.prompt, FlareUpdatePromptForm.none);
      expect(sdk.status?.readOnly, isTrue);

      foreground.add(null);
      await _settle();
      expect(sdk.status?.prompt, FlareUpdatePromptForm.modal);
      expect(sdk.status?.readOnly, isFalse);
      await sdk.dispose();
    });

    test('a download put aside for read only does not install by itself',
        () async {
      final sdk = await controller(
        _status('downloading', release: _release(mandatory: true)),
      );
      engine.answers[FlareUpdateOperations.defer] = _status(
        'downloading',
        release: _release(mandatory: true),
        readOnly: true,
      );
      final update = sdk.update();
      await _settle();

      await sdk.continueReadOnly();
      engine.events.add(
        _status('readyToInstall', release: _release(mandatory: true)),
      );
      await update;

      expect(engine.count(FlareUpdateOperations.install), 0);
      await sdk.dispose();
    });

    test('a blocking update has no read only way out', () async {
      final sdk = await controller(_status(
        'required',
        release: _release(mandatory: true),
        prompt: 'fullscreen',
        blockUi: true,
      ));
      expect(sdk.status?.canContinueReadOnly, isFalse);
      await sdk.continueReadOnly();
      expect(engine.count(FlareUpdateOperations.defer), 0);
      expect(sdk.status?.prompt, FlareUpdatePromptForm.fullscreen);
      await sdk.dispose();
    });

    test('gives the Kit retryable and the fallback target', () async {
      final failed = {
        'code': FlareUpdateErrorCodes.hashMismatch,
        'retryable': true,
        'fallbackUrl': 'https://example.com/download',
      };
      final sdk = await controller(_status('failed', error: failed));
      expect(sdk.status?.error?.retryable, isTrue);
      expect(sdk.status?.fallbackTarget, FlareUpdateFallbackTarget.website);

      engine.events.add(_status('failed', error: failed, distribution: 'play'));
      await _settle();
      expect(sdk.status?.fallbackTarget, FlareUpdateFallbackTarget.store);
      await sdk.dispose();
    });

    test('opens the fallback link', () async {
      final sdk = await controller(_status(
        'failed',
        error: {
          'code': FlareUpdateErrorCodes.downloadFailed,
          'fallbackUrl': 'https://example.com',
        },
      ));
      expect(await sdk.openFallback(), isTrue);
      final plan = installer.executed.single as FlareUpdateOpenStore;
      expect(plan.store, FlareUpdateOpenStore.website);
      expect(plan.url, 'https://example.com');
      await sdk.dispose();
    });
  });

  group('resource packs', () {
    test('the content stays the text the engine verified', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.getResources] = {
        'packs': [
          {
            'id': 'emoji',
            'kind': 'emoji',
            'packVersion': 3,
            'contentJson': '{"packs":[]}',
          },
          {
            'id': 'strings',
            'kind': 'strings',
            'packVersion': 12,
            'contentJson': '{}',
          },
        ],
      };

      final packs = await sdk.loadResources();

      expect(packs.map((pack) => pack.id), ['emoji', 'strings']);
      expect(packs.first.kind, 'emoji');
      expect(packs.first.packVersion, 3);
      expect(packs.first.contentJson, '{"packs":[]}');
      expect(
        engine.paramsOf(FlareUpdateOperations.getResources).single,
        isEmpty,
      );
      await sdk.dispose();
    });

    test('no packs is an empty list', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.getResources] = {'packs': []};
      expect(await sdk.loadResources(), isEmpty);
      await sdk.dispose();
    });

    test('a failed read only reaches onError', () async {
      final sdk = await controller();
      engine.refusals[FlareUpdateOperations.getResources] =
          const FlareUpdateException(FlareUpdateErrorCodes.installFailed);

      expect(await sdk.loadResources(), isEmpty);
      expect(errors, hasLength(1));
      expect(sdk.status?.error, isNull);
      await sdk.dispose();
    });

    test('a pack with a field missing is a broken answer', () async {
      final sdk = await controller();
      engine.answers[FlareUpdateOperations.getResources] = {
        'packs': [
          {'id': 'strings'},
        ],
      };

      expect(await sdk.loadResources(), isEmpty);
      expect(errors.single, isA<FlareUpdateWireError>());
      await sdk.dispose();
    });
  });

  group('the store', () {
    test('a store without the update is not prompted', () async {
      installer.prompts = false;
      final sdk = await controller(
        _status('available', release: _release(kind: 'store'), prompt: 'sheet'),
      );
      expect(sdk.status?.prompt, FlareUpdatePromptForm.none);

      installer.prompts = true;
      foreground.add(null);
      await _settle();
      expect(sdk.status?.prompt, FlareUpdatePromptForm.sheet);
      await sdk.dispose();
    });

    test('a forced release is prompted whatever the store says', () async {
      installer.prompts = false;
      final sdk = await controller(_status(
        'required',
        release: _release(kind: 'store', mandatory: true),
        prompt: 'modal',
      ));
      expect(sdk.status?.prompt, FlareUpdatePromptForm.modal);
      await sdk.dispose();
    });

    test('a downloaded store update waits for the user', () async {
      final store = _release(kind: 'store');
      final sdk = await controller(
        _status('installing', release: store, prompt: 'sheet'),
      );
      installer.handoffEvents.add(FlareUpdateHandoff.restartReady);
      await _settle();

      expect(sdk.status?.state, FlareUpdateState.readyToInstall);
      expect(sdk.status?.prompt, FlareUpdatePromptForm.sheet);
      expect(installer.completed, 0);

      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('idle', noRelease: true);
      await sdk.update();

      expect(installer.completed, 1);
      expect(engine.count(FlareUpdateOperations.install), 0);
      expect(engine.paramsOf(FlareUpdateOperations.reportInstall).single, {
        'outcome': 'completed',
      });
      await sdk.dispose();
    });

    test('a failed handoff is reported', () async {
      final store = _release(kind: 'store');
      final sdk = await controller(_status('installing', release: store));
      engine.answers[FlareUpdateOperations.reportInstall] =
          _status('failed', release: store);
      installer.handoffEvents.add(FlareUpdateHandoff.failed);
      await _settle();
      expect(engine.paramsOf(FlareUpdateOperations.reportInstall).single, {
        'outcome': 'failed',
        'code': FlareUpdateErrorCodes.installFailed,
      });
      await sdk.dispose();
    });
  });

  test('nothing moves after dispose', () async {
    final sdk = await controller(_status('downloading'));
    await sdk.dispose();
    await Future<void>.delayed(_interval * 3);
    expect(engine.count(FlareUpdateOperations.getState), 1);
    expect(sdk.status?.state, FlareUpdateState.downloading);
  });

  group('wire', () {
    test('reads a full status', () {
      final status = FlareUpdateStatus.fromMap({
        'state': 'downloading',
        'current': {'build': 20302, 'distribution': 'direct'},
        'release': _release(),
        'progress': {'received': 1048576, 'total': 52428800},
        'prompt': 'sheet',
        'blockUi': false,
        'readOnly': true,
        'lastCheckedAt': 1793871062839,
        'error': {
          'code': 'update.hashMismatch',
          'retryable': true,
          'fallbackUrl': 'https://example.com',
        },
      });
      expect(status.state, FlareUpdateState.downloading);
      expect(status.current.build, 20302);
      expect(status.release?.kind, FlareUpdateKind.package);
      expect(status.progress?.total, 52428800);
      expect(status.prompt, FlareUpdatePromptForm.sheet);
      expect(status.readOnly, isTrue);
      expect(status.lastCheckedAt, 1793871062839);
      expect(status.error?.fallbackUrl, 'https://example.com');
    });

    test('refuses an unknown state', () {
      expect(
        () => FlareUpdateStatus.fromMap({'state': 'unheardOf'}),
        throwsA(isA<FlareUpdateWireError>()),
      );
    });

    test('keeps a plan for another platform as a value', () {
      final plan = FlareUpdateInstallPlan.fromMap({
        'kind': 'activateWebBundle',
        'buildId': '20261105-abc',
      });
      expect((plan as FlareUpdateUnsupportedPlan).kind, 'activateWebBundle');
    });

    test('a package plan needs its certificate', () {
      final incomplete = Map<String, Object?>.of(_packagePlan)
        ..remove('signingCertSha256');
      expect(
        () => FlareUpdateInstallPlan.fromMap(incomplete),
        throwsA(isA<FlareUpdateWireError>()),
      );
    });

    test('a plan round-trips through the map the host receives', () {
      final plan = FlareUpdateInstallPlan.fromMap(_packagePlan);
      expect(plan.toMap(), _packagePlan);
    });

    test('the report carries the code only when there is one', () {
      expect(
        const FlareUpdateInstallResult.failed('update.signatureMismatch')
            .toReportParams(),
        {'outcome': 'failed', 'code': 'update.signatureMismatch'},
      );
      expect(
        const FlareUpdateInstallResult(FlareUpdateOutcome.started)
            .toReportParams(),
        {'outcome': 'started'},
      );
    });
  });
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

final class _FakeEngine implements FlareUpdateEngine {
  final List<({String operation, Map<String, Object?> params})> calls = [];
  final Map<String, Map<String, Object?>> answers = {};
  final Map<String, FlareUpdateException> refusals = {};
  final StreamController<Map<String, Object?>> events =
      StreamController<Map<String, Object?>>.broadcast();

  Future<void> close() => events.close();

  @override
  Future<Map<String, Object?>> dispatch(
    String operation, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add((operation: operation, params: params));
    final refusal = refusals.remove(operation);
    if (refusal != null) throw refusal;
    return answers[operation] ?? answers[FlareUpdateOperations.getState]!;
  }

  @override
  Stream<Map<String, Object?>> stateEvents() => events.stream;

  int count(String operation) =>
      calls.where((call) => call.operation == operation).length;

  List<String> routes() => calls.map((call) => call.operation).toList();

  List<Map<String, Object?>> paramsOf(String operation) => calls
      .where((call) => call.operation == operation)
      .map((call) => call.params)
      .toList();
}

final class _FakeInstaller implements FlareUpdateInstaller {
  FlareUpdateInstallResult result =
      const FlareUpdateInstallResult(FlareUpdateOutcome.completed);
  bool prompts = true;
  int completed = 0;
  final List<FlareUpdateInstallPlan> executed = [];
  final StreamController<FlareUpdateHandoff> handoffEvents =
      StreamController<FlareUpdateHandoff>.broadcast();

  Future<void> close() => handoffEvents.close();

  @override
  Future<FlareUpdateInstallResult> execute(FlareUpdateInstallPlan plan) async {
    executed.add(plan);
    return result;
  }

  @override
  Future<bool> canPrompt(FlareUpdateRelease release) async => prompts;

  @override
  Stream<FlareUpdateHandoff> handoffs() => handoffEvents.stream;

  @override
  Future<FlareUpdateInstallResult> completeHandoff() async {
    completed += 1;
    return const FlareUpdateInstallResult(FlareUpdateOutcome.completed);
  }
}
