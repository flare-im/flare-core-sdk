import 'dart:async';

import '../api/api.dart';
import '../flare_core_sdk.dart';
import '../listener/listener.dart';
import '../model/model.dart';
import 'flare_update_installer.dart';
import 'flare_update_models.dart';

final RegExp _updateWord = RegExp(r'update\.[A-Za-z]+');

/// A route name such as `update.install` in an error text is no error code.
const Set<String> _errorCodes = {
  FlareUpdateErrorCodes.manifestUnavailable,
  FlareUpdateErrorCodes.manifestRejected,
  FlareUpdateErrorCodes.noArtifact,
  FlareUpdateErrorCodes.meteredConfirmationRequired,
  FlareUpdateErrorCodes.insufficientSpace,
  FlareUpdateErrorCodes.downloadFailed,
  FlareUpdateErrorCodes.hashMismatch,
  FlareUpdateErrorCodes.installFailed,
  FlareUpdateErrorCodes.signatureMismatch,
  FlareUpdateErrorCodes.downgradeRejected,
  FlareUpdateErrorCodes.notSkippable,
};

/// The refusal a failed `update.*` call stands for. `update.install` gives its
/// code as the error text; any other failure has none and this returns null,
/// so the controller falls back to the step's own code.
FlareUpdateException? flareUpdateRefusal(FlareSdkException failure) {
  for (final word in _updateWord.allMatches(failure.message)) {
    final code = word[0];
    if (code != null && _errorCodes.contains(code)) {
      return FlareUpdateException(
        code,
        message: failure.message,
        retryable: failure.retryable,
      );
    }
  }
  return null;
}

/// The core client as the update controller's engine: [FlareUpdateController]
/// speaks wire JSON, the generated client is typed, so this turns one into the
/// other. The social SDK has its own adapter over `imDispatch`.
final class FlareClientUpdateEngine implements FlareUpdateEngine {
  const FlareClientUpdateEngine({
    required Future<UpdateApi> Function() update,
    required EventSubscription Function(FlareImEventListener listener)
        addEventListener,
  })  : _update = update,
        _addEventListener = addEventListener;

  /// Resolves once the client is initialized: `update.*` needs `init`, not a
  /// session.
  final Future<UpdateApi> Function() _update;
  final EventSubscription Function(FlareImEventListener listener)
      _addEventListener;

  @override
  Future<Map<String, Object?>> dispatch(
    String operation, [
    Map<String, Object?> params = const {},
  ]) async {
    final update = await _update();
    try {
      return await _route(update, operation, params);
    } on FlareSdkException catch (failure) {
      throw flareUpdateRefusal(failure) ?? failure;
    }
  }

  Future<Map<String, Object?>> _route(
    UpdateApi update,
    String operation,
    Map<String, Object?> params,
  ) async =>
      switch (operation) {
        FlareUpdateOperations.getState => _statusMap(
            await update.getState(
              UpdateGetStateRequest(foreground: params['foreground'] as bool?),
            ),
          ),
        FlareUpdateOperations.check => _statusMap(
            await update.check(
              UpdateCheckRequest(manual: params['manual'] == true),
            ),
          ),
        FlareUpdateOperations.download => _statusMap(
            await update.download(
              UpdateDownloadRequest(
                allowMetered: params['allowMetered'] == true,
              ),
            ),
          ),
        FlareUpdateOperations.install => _planMap(await update.install()),
        FlareUpdateOperations.reportInstall => _statusMap(
            await update.reportInstall(
              UpdateReportInstallRequest(
                outcome: params['outcome'] as String? ?? '',
                code: params['code'] as String?,
              ),
            ),
          ),
        FlareUpdateOperations.defer => _statusMap(await update.defer()),
        FlareUpdateOperations.skip => _statusMap(
            await update.skip(
              UpdateSkipRequest(build: params['build'] as int? ?? 0),
            ),
          ),
        FlareUpdateOperations.markPrompted => _statusMap(
            await update.markPrompted(
              UpdateMarkPromptedRequest(
                build: params['build'] as int?,
                form: params['form'] as String? ?? '',
              ),
            ),
          ),
        FlareUpdateOperations.setLocale => _statusMap(
            await update.setLocale(
              UpdateSetLocaleRequest(locale: params['locale'] as String? ?? ''),
            ),
          ),
        FlareUpdateOperations.getResources => _resourcesMap(
            await update.getResources(const UpdateGetResourcesRequest()),
          ),
        _ => throw ArgumentError.value(operation, 'operation'),
      };

  @override
  Stream<Map<String, Object?>> stateEvents() {
    EventSubscription? subscription;
    late final StreamController<Map<String, Object?>> events;
    events = StreamController<Map<String, Object?>>(
      onListen: () {
        subscription = _addEventListener(
          _StateEvents((status) => events.add(_statusMap(status))),
        );
      },
      onCancel: () {
        subscription?.unsubscribe();
        subscription = null;
        return events.close();
      },
    );
    return events.stream;
  }
}

/// Forwards `update://state`; every other event is not its business.
final class _StateEvents extends FlareImEventListener {
  const _StateEvents(this._changed);

  final void Function(UpdateStatus status) _changed;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void onUpdateState(UpdateStatus event) => _changed(event);
}

Map<String, Object?> _statusMap(UpdateStatus status) {
  final release = status.release;
  final progress = status.progress;
  final error = status.error;
  return {
    'state': status.state,
    'current': {
      'version': status.current.version,
      'build': status.current.build,
      'channel': status.current.channel,
      'distribution': status.current.distribution,
    },
    'release': release == null
        ? null
        : {
            'releaseId': release.releaseId,
            'version': release.version,
            'build': release.build,
            'notes': release.notes,
            'sizeBytes': release.sizeBytes,
            'mandatory': release.mandatory,
            'recommended': release.recommended,
            'kind': release.kind,
          },
    'progress': progress == null
        ? null
        : {'received': progress.received, 'total': progress.total},
    'prompt': status.prompt,
    'blockUi': status.blockUi,
    'readOnly': status.readOnly,
    'blockReason': status.blockReason,
    'lastCheckedAt': status.lastCheckedAt,
    'error': error == null
        ? null
        : {
            'code': error.code,
            'retryable': error.retryable,
            'fallbackUrl': error.fallbackUrl,
          },
  };
}

Map<String, Object?> _resourcesMap(UpdateResources resources) => {
      'packs': [
        for (final pack in resources.packs)
          {
            'id': pack.id,
            'kind': pack.kind,
            'packVersion': pack.packVersion,
            'contentJson': pack.contentJson,
          },
      ],
    };

/// The fields a Flutter host can carry out; the plans for the web and the
/// desktop updater stay unsupported by kind.
Map<String, Object?> _planMap(UpdateInstallPlan plan) => {
      'kind': plan.kind,
      'store': plan.store,
      'url': plan.url,
      'packageName': plan.packageName,
      'appId': plan.appId,
      'immediate': plan.immediate,
      'path': plan.path,
      'sha256': plan.sha256,
      'signingCertSha256': plan.signingCertSha256,
      'build': plan.build,
      'sizeBytes': plan.sizeBytes,
    };
