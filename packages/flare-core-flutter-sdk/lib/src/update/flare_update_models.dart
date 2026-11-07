/// The wire names of the update routes.
abstract final class FlareUpdateOperations {
  const FlareUpdateOperations._();

  static const String getState = 'update.get_state';
  static const String check = 'update.check';
  static const String download = 'update.download';
  static const String install = 'update.install';
  static const String reportInstall = 'update.report_install';
  static const String defer = 'update.defer';
  static const String skip = 'update.skip';
  static const String markPrompted = 'update.mark_prompted';
  static const String setLocale = 'update.set_locale';
  static const String getResources = 'update.get_resources';
}

/// The cross-platform update error codes.
abstract final class FlareUpdateErrorCodes {
  const FlareUpdateErrorCodes._();

  static const String manifestUnavailable = 'update.manifestUnavailable';
  static const String manifestRejected = 'update.manifestRejected';
  static const String noArtifact = 'update.noArtifact';
  static const String meteredConfirmationRequired =
      'update.meteredConfirmationRequired';
  static const String insufficientSpace = 'update.insufficientSpace';
  static const String downloadFailed = 'update.downloadFailed';
  static const String hashMismatch = 'update.hashMismatch';
  static const String installFailed = 'update.installFailed';
  static const String signatureMismatch = 'update.signatureMismatch';
  static const String downgradeRejected = 'update.downgradeRejected';
  static const String notSkippable = 'update.notSkippable';
}

/// Where the update flow stands; the names are the SDK wire values.
enum FlareUpdateState {
  idle,
  checking,
  upToDate,
  available,
  required,
  downloading,
  verifying,
  readyToInstall,
  installing,
  failed,
}

/// How the update should be put in front of the user.
enum FlareUpdatePromptForm {
  none,
  badge,
  sheet,
  modal,
  fullscreen;

  /// The forms that interrupt the user, as opposed to a quiet badge.
  bool get interrupts => this == sheet || this == modal || this == fullscreen;
}

/// How a release reaches the device.
enum FlareUpdateKind { store, package, webBundle, desktop }

/// Where a failed update sends the user instead: the Kit words its fallback
/// button by this.
enum FlareUpdateFallbackTarget { website, store }

/// The values `update.report_install` takes.
enum FlareUpdateOutcome { started, completed, cancelled, failed }

/// How an update ends that a store took over when
/// [FlareUpdateInstaller.execute] returned `started`.
enum FlareUpdateHandoff {
  none,

  /// The update is downloaded and waits for a restart only the user may start.
  restartReady,
  failed,
  cancelled,
}

/// A payload does not have the shape of the update contract.
final class FlareUpdateWireError implements Exception {
  const FlareUpdateWireError(this.field, this.value);

  final String field;
  final Object? value;

  @override
  String toString() => 'FlareUpdateWireError: bad $field: $value';
}

/// A route refused the call. [code] is the cross-platform code when the
/// engine gave one.
final class FlareUpdateException implements Exception {
  const FlareUpdateException(
    this.code, {
    this.message,
    this.retryable = false,
    this.fallbackUrl,
  });

  final String code;
  final String? message;
  final bool retryable;
  final String? fallbackUrl;

  @override
  String toString() => 'FlareUpdateException($code): ${message ?? ''}';
}

/// The installed app, as the engine knows it.
final class FlareUpdateCurrent {
  const FlareUpdateCurrent({
    this.version,
    this.build,
    this.channel,
    this.distribution,
  });

  factory FlareUpdateCurrent.fromMap(Map<String, Object?> map) =>
      FlareUpdateCurrent(
        version: _string(map['version']),
        build: _int(map['build']),
        channel: _string(map['channel']),
        distribution: _string(map['distribution']),
      );

  final String? version;
  final int? build;
  final String? channel;
  final String? distribution;
}

/// The release on offer. [notes] are already in the app's language.
final class FlareUpdateRelease {
  const FlareUpdateRelease({
    required this.releaseId,
    required this.version,
    required this.build,
    required this.kind,
    this.notes = const [],
    this.sizeBytes,
    this.mandatory = false,
    this.recommended = false,
  });

  factory FlareUpdateRelease.fromMap(Map<String, Object?> map) =>
      FlareUpdateRelease(
        releaseId: _required(_string(map['releaseId']), 'releaseId', map),
        version: _required(_string(map['version']), 'version', map),
        build: _required(_int(map['build']), 'build', map),
        kind: _required(_enumByName(FlareUpdateKind.values, map['kind']), 'kind', map),
        notes: _strings(map['notes']),
        sizeBytes: _int(map['sizeBytes']),
        mandatory: map['mandatory'] == true,
        recommended: map['recommended'] == true,
      );

  final String releaseId;
  final String version;
  final int build;
  final FlareUpdateKind kind;
  final List<String> notes;

  /// Null for a store release: the store knows the size, the manifest does not.
  final int? sizeBytes;
  final bool mandatory;
  final bool recommended;

  /// The wire shape, for the native installer.
  Map<String, Object?> toMap() => {
        'releaseId': releaseId,
        'version': version,
        'build': build,
        'kind': kind.name,
        'notes': notes,
        'sizeBytes': sizeBytes,
        'mandatory': mandatory,
        'recommended': recommended,
      };
}

/// Download progress in bytes.
final class FlareUpdateProgress {
  const FlareUpdateProgress({required this.received, this.total});

  factory FlareUpdateProgress.fromMap(Map<String, Object?> map) =>
      FlareUpdateProgress(
        received: _int(map['received']) ?? 0,
        total: _int(map['total']),
      );

  final int received;
  final int? total;
}

/// A resource pack of this run. It is data for the Kit, so [contentJson] stays
/// the text the engine verified.
final class FlareUpdateResourcePack {
  const FlareUpdateResourcePack({
    required this.id,
    required this.kind,
    required this.packVersion,
    required this.contentJson,
  });

  factory FlareUpdateResourcePack.fromMap(Map<String, Object?> map) =>
      FlareUpdateResourcePack(
        id: _required(_string(map['id']), 'pack.id', map),
        kind: _required(_string(map['kind']), 'pack.kind', map),
        packVersion: _required(
          _int(map['packVersion']),
          'pack.packVersion',
          map,
        ),
        contentJson: _required(
          _string(map['contentJson']),
          'pack.contentJson',
          map,
        ),
      );

  /// The packs of an `update.get_resources` answer.
  static List<FlareUpdateResourcePack> listFromMap(Map<String, Object?> map) {
    final packs = map['packs'];
    if (packs is! List) return const [];
    return packs
        .map((pack) => FlareUpdateResourcePack.fromMap(
              _required(_map(pack), 'pack', pack),
            ))
        .toList(growable: false);
  }

  final String id;
  final String kind;
  final int packVersion;
  final String contentJson;
}

/// The last failure.
final class FlareUpdateError {
  const FlareUpdateError({
    required this.code,
    this.retryable = false,
    this.fallbackUrl,
  });

  factory FlareUpdateError.fromMap(Map<String, Object?> map) =>
      FlareUpdateError(
        code: _required(_string(map['code']), 'error.code', map),
        retryable: map['retryable'] == true,
        fallbackUrl: _string(map['fallbackUrl']),
      );

  final String code;
  final bool retryable;
  final String? fallbackUrl;
}

/// The `update://state` payload, and what every `update.*` route except
/// `update.install` returns.
final class FlareUpdateStatus {
  const FlareUpdateStatus({
    required this.state,
    this.current = const FlareUpdateCurrent(),
    this.release,
    this.progress,
    this.prompt = FlareUpdatePromptForm.none,
    this.blockUi = false,
    this.readOnly = false,
    this.blockReason,
    this.lastCheckedAt,
    this.error,
  });

  /// Reads the wire shape; a malformed payload throws [FlareUpdateWireError].
  factory FlareUpdateStatus.fromMap(Map<String, Object?> map) {
    final release = _map(map['release']);
    final progress = _map(map['progress']);
    final error = _map(map['error']);
    return FlareUpdateStatus(
      state: _required(
        _enumByName(FlareUpdateState.values, map['state']),
        'state',
        map,
      ),
      current: FlareUpdateCurrent.fromMap(_map(map['current']) ?? const {}),
      release: release == null ? null : FlareUpdateRelease.fromMap(release),
      progress: progress == null ? null : FlareUpdateProgress.fromMap(progress),
      prompt: _enumByName(FlareUpdatePromptForm.values, map['prompt']) ??
          FlareUpdatePromptForm.none,
      blockUi: map['blockUi'] == true,
      readOnly: map['readOnly'] == true,
      blockReason: _string(map['blockReason']),
      lastCheckedAt: _int(map['lastCheckedAt']),
      error: error == null ? null : FlareUpdateError.fromMap(error),
    );
  }

  final FlareUpdateState state;
  final FlareUpdateCurrent current;
  final FlareUpdateRelease? release;
  final FlareUpdateProgress? progress;
  final FlareUpdatePromptForm prompt;
  final bool blockUi;
  final bool readOnly;

  /// Why this build is blocked, in the app's language; null when it is not.
  final String? blockReason;

  /// Milliseconds; null when no check has run yet.
  final int? lastCheckedAt;
  final FlareUpdateError? error;

  /// The direct channel falls back to the website, every other channel to its
  /// store.
  FlareUpdateFallbackTarget get fallbackTarget =>
      current.distribution == 'direct'
          ? FlareUpdateFallbackTarget.website
          : FlareUpdateFallbackTarget.store;

  /// A forced update that does not block the UI can be put aside to browse
  /// read only. The state says forced on its own: when the server refuses this
  /// build before the manifest arrives, [release] is null.
  bool get canContinueReadOnly =>
      (state == FlareUpdateState.required || release?.mandatory == true) &&
      !blockUi;

  /// This status with the fields the controller lays over the engine's word.
  FlareUpdateStatus overlaid({
    FlareUpdateState? state,
    FlareUpdatePromptForm? prompt,
    FlareUpdateError? error,
  }) =>
      FlareUpdateStatus(
        state: state ?? this.state,
        current: current,
        release: release,
        progress: progress,
        prompt: prompt ?? this.prompt,
        blockUi: blockUi,
        readOnly: readOnly,
        blockReason: blockReason,
        lastCheckedAt: lastCheckedAt,
        error: error ?? this.error,
      );
}

/// What the platform is asked to do; the engine decides it, the installer only
/// carries it out.
sealed class FlareUpdateInstallPlan {
  const FlareUpdateInstallPlan();

  /// Reads the wire shape; a malformed payload throws [FlareUpdateWireError].
  factory FlareUpdateInstallPlan.fromMap(Map<String, Object?> map) {
    final kind = _required(_string(map['kind']), 'kind', map);
    return switch (kind) {
      'openStore' => FlareUpdateOpenStore(
          store: _required(_string(map['store']), 'store', map),
          url: _string(map['url']),
          packageName: _string(map['packageName']),
          appId: _string(map['appId']),
          immediate: map['immediate'] == true,
        ),
      'installPackage' => FlareUpdateInstallPackage(
          path: _required(_string(map['path']), 'path', map),
          sha256: _required(_string(map['sha256']), 'sha256', map),
          signingCertSha256: _required(
            _string(map['signingCertSha256']),
            'signingCertSha256',
            map,
          ),
          build: _required(_int(map['build']), 'build', map),
          sizeBytes: _required(_int(map['sizeBytes']), 'sizeBytes', map),
        ),
      _ => FlareUpdateUnsupportedPlan(kind),
    };
  }

  /// The wire shape, for the native installer.
  Map<String, Object?> toMap();
}

/// Opens a store, or the website when [store] is [website].
final class FlareUpdateOpenStore extends FlareUpdateInstallPlan {
  const FlareUpdateOpenStore({
    required this.store,
    this.url,
    this.packageName,
    this.appId,
    this.immediate = false,
  });

  /// The value of [store] for a plain link: no store app is involved.
  static const String website = 'website';

  final String store;
  final String? url;
  final String? packageName;
  final String? appId;

  /// Play only: run the immediate flow rather than the flexible one.
  final bool immediate;

  @override
  Map<String, Object?> toMap() => {
        'kind': 'openStore',
        'store': store,
        'url': url,
        'packageName': packageName,
        'appId': appId,
        'immediate': immediate,
      };
}

/// Installs a verified download. Android only.
final class FlareUpdateInstallPackage extends FlareUpdateInstallPlan {
  const FlareUpdateInstallPackage({
    required this.path,
    required this.sha256,
    required this.signingCertSha256,
    required this.build,
    required this.sizeBytes,
  });

  final String path;
  final String sha256;
  final String signingCertSha256;
  final int build;
  final int sizeBytes;

  @override
  Map<String, Object?> toMap() => {
        'kind': 'installPackage',
        'path': path,
        'sha256': sha256,
        'signingCertSha256': signingCertSha256,
        'build': build,
        'sizeBytes': sizeBytes,
      };
}

/// A plan for another platform; Flutter hosts cannot carry it out.
final class FlareUpdateUnsupportedPlan extends FlareUpdateInstallPlan {
  const FlareUpdateUnsupportedPlan(this.kind);

  final String kind;

  @override
  Map<String, Object?> toMap() => {'kind': kind};
}

/// What became of a plan. `completed` means nothing is left to do here: for a
/// store that its page opened, whether the user installs being the store's
/// business. `started` means work goes on in the background and
/// [FlareUpdateInstaller.handoffs] tells how it ends. [code] is set on `failed`.
final class FlareUpdateInstallResult {
  const FlareUpdateInstallResult(this.outcome, {this.code});

  const FlareUpdateInstallResult.failed(String this.code)
      : outcome = FlareUpdateOutcome.failed;

  /// Reads the `{outcome, code}` a native installer answers with.
  factory FlareUpdateInstallResult.fromMap(Map<String, Object?> map) =>
      FlareUpdateInstallResult(
        _required(
          _enumByName(FlareUpdateOutcome.values, map['outcome']),
          'outcome',
          map,
        ),
        code: _string(map['code']),
      );

  final FlareUpdateOutcome outcome;
  final String? code;

  /// The `update.report_install` parameters.
  Map<String, Object?> toReportParams() => {
        'outcome': outcome.name,
        if (code != null) 'code': code,
      };
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList(growable: false) : const [];

Map<String, Object?>? _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : null;

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

T _required<T extends Object>(T? value, String field, Object? payload) {
  if (value == null) throw FlareUpdateWireError(field, payload);
  return value;
}
