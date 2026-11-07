import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

const UpdateStatus _status = UpdateStatus(
  state: 'available',
  current: UpdateCurrentApp(
    version: '2.3.2',
    build: 20302,
    channel: 'stable',
    distribution: 'direct',
  ),
  release: UpdateReleaseSummary(
    releaseId: 'rel',
    version: '2.4.0',
    build: 20400,
    notes: ['Scheduled messages'],
    sizeBytes: 52428800,
    kind: 'package',
  ),
  progress: UpdateProgress(received: 1, total: 2),
  prompt: 'sheet',
  blockReason: 'This build is no longer supported',
  error: UpdateErrorInfo(
    code: FlareUpdateErrorCodes.downloadFailed,
    retryable: true,
    fallbackUrl: 'https://example.com/download',
  ),
);

void main() {
  late _FakeUpdate update;
  late _Subscriptions events;
  late FlareClientUpdateEngine engine;

  setUp(() {
    update = _FakeUpdate();
    events = _Subscriptions();
    engine = FlareClientUpdateEngine(
      update: () async => update,
      addEventListener: events.add,
    );
  });

  test('a status survives the way through wire JSON', () async {
    final status = FlareUpdateStatus.fromMap(
      await engine.dispatch(FlareUpdateOperations.getState),
    );

    expect(status.state, FlareUpdateState.available);
    expect(status.current.build, 20302);
    expect(status.current.distribution, 'direct');
    expect(status.release?.kind, FlareUpdateKind.package);
    expect(status.release?.notes, ['Scheduled messages']);
    expect(status.progress?.total, 2);
    expect(status.prompt, FlareUpdatePromptForm.sheet);
    expect(status.blockReason, 'This build is no longer supported');
    expect(status.error?.fallbackUrl, 'https://example.com/download');
  });

  test('a read says whether the app came back', () async {
    await engine.dispatch(FlareUpdateOperations.getState);
    expect(update.foreground, isNull);

    await engine.dispatch(FlareUpdateOperations.getState, {'foreground': true});
    expect(update.foreground, isTrue);
  });

  test('a language reaches the engine', () async {
    await engine.dispatch(FlareUpdateOperations.setLocale, {'locale': 'en-US'});
    expect(update.locale, 'en-US');
  });

  test('a plan reaches the controller in its own shape', () async {
    update.plan = const UpdateInstallPlan(
      kind: 'installPackage',
      path: '/data/2.4.0-20400.apk',
      sha256: 'aa',
      signingCertSha256: 'bb',
      build: 20400,
      sizeBytes: 52428800,
    );

    final plan = FlareUpdateInstallPlan.fromMap(
      await engine.dispatch(FlareUpdateOperations.install),
    );

    expect(plan, isA<FlareUpdateInstallPackage>());
    expect((plan as FlareUpdateInstallPackage).path, '/data/2.4.0-20400.apk');
  });

  test('the parameters reach the typed routes', () async {
    await engine.dispatch(FlareUpdateOperations.check, {'manual': true});
    await engine.dispatch(
      FlareUpdateOperations.download,
      {'allowMetered': true},
    );
    await engine.dispatch(FlareUpdateOperations.skip, {'build': 20400});
    await engine.dispatch(FlareUpdateOperations.markPrompted, {'form': 'modal'});
    await engine.dispatch(
      FlareUpdateOperations.reportInstall,
      {'outcome': 'failed', 'code': FlareUpdateErrorCodes.installFailed},
    );

    expect(update.manual, isTrue);
    expect(update.allowMetered, isTrue);
    expect(update.skipped, 20400);
    expect(update.marked?.build, isNull);
    expect(update.marked?.form, 'modal');
    expect(update.reported?.outcome, 'failed');
    expect(update.reported?.code, FlareUpdateErrorCodes.installFailed);
  });

  test('resource packs survive the way through wire JSON', () async {
    final packs = FlareUpdateResourcePack.listFromMap(
      await engine.dispatch(FlareUpdateOperations.getResources),
    );

    expect(packs.single.id, 'strings');
    expect(packs.single.kind, 'strings');
    expect(packs.single.packVersion, 3);
    expect(packs.single.contentJson, '{}');
  });

  test('the code in the error text of update.install becomes a refusal',
      () async {
    update.installFailure = const FlareSdkException(
      code: 'invalidParameter',
      message: 'update.hashMismatch',
    );

    await expectLater(
      engine.dispatch(FlareUpdateOperations.install),
      throwsA(
        isA<FlareUpdateException>().having(
          (refusal) => refusal.code,
          'code',
          FlareUpdateErrorCodes.hashMismatch,
        ),
      ),
    );
  });

  test('a failure without an update code stays what it is', () async {
    update.installFailure = const FlareSdkException(
      code: 'notInitialized',
      message: 'the update center is not initialised; call init first',
    );

    await expectLater(
      engine.dispatch(FlareUpdateOperations.install),
      throwsA(isA<FlareSdkException>()),
    );
  });

  test('a route name in the error text is no error code', () {
    expect(
      flareUpdateRefusal(
        const FlareSdkException(
          code: 'native_error_3',
          message: 'im:update.install failed with code 3 before callback',
        ),
      ),
      isNull,
    );
    expect(
      flareUpdateRefusal(
        const FlareSdkException(
          code: 'invalidParameter',
          message: 'update.install: update.noArtifact',
        ),
      )?.code,
      FlareUpdateErrorCodes.noArtifact,
    );
  });

  test('update://state arrives as wire JSON until the stream is cancelled',
      () async {
    final states = <Map<String, Object?>>[];
    final subscription = engine.stateEvents().listen(states.add);

    expect(events.listeners, hasLength(1));
    events.listeners.single.onUpdateState(_status);
    await Future<void>.delayed(Duration.zero);

    expect(states.single['state'], 'available');

    await subscription.cancel();
    expect(events.listeners, isEmpty);
  });
}

final class _FakeUpdate implements UpdateApi {
  UpdateInstallPlan plan = const UpdateInstallPlan(kind: 'openStore', store: 'play');
  FlareSdkException? installFailure;
  bool? foreground;
  String? locale;
  bool? manual;
  bool? allowMetered;
  int? skipped;
  UpdateMarkPromptedRequest? marked;
  UpdateReportInstallRequest? reported;

  @override
  Future<UpdateStatus> getState(UpdateGetStateRequest request) async {
    foreground = request.foreground;
    return _status;
  }

  @override
  Future<UpdateStatus> setLocale(UpdateSetLocaleRequest request) async {
    locale = request.locale;
    return _status;
  }

  @override
  Future<UpdateResources> getResources(
    UpdateGetResourcesRequest request,
  ) async =>
      const UpdateResources(
        packs: [
          UpdateResourcePack(
            id: 'strings',
            kind: 'strings',
            packVersion: 3,
            contentJson: '{}',
          ),
        ],
      );

  @override
  Future<UpdateStatus> check(UpdateCheckRequest request) async {
    manual = request.manual;
    return _status;
  }

  @override
  Future<UpdateStatus> download(UpdateDownloadRequest request) async {
    allowMetered = request.allowMetered;
    return _status;
  }

  @override
  Future<UpdateInstallPlan> install() async {
    final failure = installFailure;
    if (failure != null) throw failure;
    return plan;
  }

  @override
  Future<UpdateStatus> reportInstall(UpdateReportInstallRequest request) async {
    reported = request;
    return _status;
  }

  @override
  Future<UpdateStatus> defer() async => _status;

  @override
  Future<UpdateStatus> skip(UpdateSkipRequest request) async {
    skipped = request.build;
    return _status;
  }

  @override
  Future<UpdateStatus> markPrompted(UpdateMarkPromptedRequest request) async {
    marked = request;
    return _status;
  }
}

final class _Subscriptions {
  final List<FlareImEventListener> listeners = [];

  EventSubscription add(FlareImEventListener listener) {
    listeners.add(listener);
    return _Subscription(() => listeners.remove(listener));
  }
}

final class _Subscription implements EventSubscription {
  _Subscription(this._cancel);

  final void Function() _cancel;

  @override
  Object get id => identityHashCode(this);

  @override
  void unsubscribe() => _cancel();
}
