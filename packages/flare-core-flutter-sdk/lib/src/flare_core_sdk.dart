import 'dart:ffi';

import 'contract/bridge_contract.dart';
import 'bridge/ffi_native_bridge.dart';
import 'adapter/default_flare_im_client.dart';
import 'bridge/native_library_loader.dart';

/// Public entry point for creating a Flutter client backed by the core SDK FFI.
abstract final class FlareCoreSdk {
  const FlareCoreSdk._();

  /// Creates a ready-to-use client with the default platform native library.
  ///
  /// Flutter apps use `FlareCoreFlutter.createClient` from
  /// `flare_core_flutter_lifecycle` instead: it initializes this client with
  /// the device's platform source, so the network, foreground state and app
  /// version reach the core without app wiring.
  static DefaultFlareImClient createClient({
    DynamicLibrary? library,
    String? libraryPath,
  }) {
    final bridge = FfiNativeBridge(
      library: library,
      libraryPath: libraryPath,
    );
    return DefaultFlareImClient(bridge);
  }

  /// Creates a client from a custom bridge, useful for host integration tests.
  static DefaultFlareImClient createClientWithBridge(NativeBridge bridge) {
    return DefaultFlareImClient(bridge);
  }

  /// Loads the native FFI library with the same default policy used by
  /// [createClient].
  static DynamicLibrary loadNativeLibrary({String? libraryPath}) {
    return loadFlareNativeLibrary(libraryPath: libraryPath);
  }
}

/// Stable Dart exception surfaced by the Flutter SDK runtime.
///
/// An SDK failure carries the binding's structured error
/// (`bindings/contract/errors.json`): [code] is the core error code
/// (`PERMISSION_DENIED`), [reason] the localized key (`sdk.plugin.disabled`),
/// [machineReason] Core's or the plugin's code (`PLUGIN_DISABLED`, `CALL_FULL`),
/// [httpStatus] and [remoteCode] Core's answer, [refusedMessageIds] the
/// messages the operation refused. Read these, never [message].
///
/// Failures with their own handling arrive as typed subclasses:
/// [OverloadedException], [UpgradeRequiredException] and
/// [NetworkUncertainException].
final class FlareSdkException implements Exception {
  const FlareSdkException({
    required this.code,
    required this.message,
    this.operation,
    this.details,
    this.reason,
    this.retryable = false,
    this.httpStatus,
    this.remoteCode,
    this.machineReason,
    this.refusedMessageIds,
  });

  /// The exception for a failed native call: the structured error in
  /// `details_json` when the SDK wrote one, else the C ABI code alone. The
  /// codes with their own handling (C `FLARE_ERR_OVERLOADED`,
  /// `FLARE_ERR_UPGRADE_REQUIRED`, `FLARE_ERR_NETWORK_UNCERTAIN`) come back
  /// as their typed subclass.
  factory FlareSdkException.fromNative({
    required int nativeCode,
    required String message,
    required String? operation,
    required Object? details,
  }) {
    final structured = details is Map ? details : const <Object?, Object?>{};
    final code = structured['code'];
    final reason = structured['reason'];
    final httpStatus = structured['httpStatus'];
    final remoteCode = structured['remoteCode'];
    final machineReason = structured['machineReason'];
    final wireCode =
        code is String && code.isNotEmpty ? code : 'native_error_$nativeCode';
    final typedReason = reason is String ? reason : null;
    final retryable = structured['retryable'] == true;
    final typedHttpStatus = httpStatus is int ? httpStatus : null;
    final typedRemoteCode = remoteCode is int ? remoteCode : null;
    final typedMachineReason = machineReason is String ? machineReason : null;
    final refused = _stringList(structured['refusedMessageIds']);
    switch (_typedKind(nativeCode, wireCode)) {
      case _TypedKind.overloaded:
        final wait = structured['retryAfterMs'];
        return OverloadedException(
          message: message,
          operation: operation,
          details: details,
          reason: typedReason,
          retryable: retryable,
          httpStatus: typedHttpStatus,
          remoteCode: typedRemoteCode,
          machineReason: typedMachineReason,
          retryAfterMs: wait is num && wait.isFinite && wait >= 0
              ? wait.toInt()
              : null,
        );
      case _TypedKind.upgradeRequired:
        return UpgradeRequiredException(
          message: message,
          operation: operation,
          details: details,
          reason: typedReason,
          retryable: retryable,
          httpStatus: typedHttpStatus,
          remoteCode: typedRemoteCode,
          machineReason: typedMachineReason,
        );
      case _TypedKind.networkUncertain:
        return NetworkUncertainException(
          message: message,
          operation: operation,
          details: details,
          reason: typedReason,
          retryable: retryable,
          httpStatus: typedHttpStatus,
          remoteCode: typedRemoteCode,
          machineReason: typedMachineReason,
        );
      case null:
        return FlareSdkException(
          code: wireCode,
          message: message,
          operation: operation,
          details: details,
          reason: typedReason,
          retryable: retryable,
          httpStatus: typedHttpStatus,
          remoteCode: typedRemoteCode,
          machineReason: typedMachineReason,
          refusedMessageIds: refused,
        );
    }
  }

  /// C ABI codes from `bindings/contract/errors.json`.
  static const int _nativeOverloaded = 12;
  static const int _nativeUpgradeRequired = 13;
  static const int _nativeNetworkUncertain = 14;

  /// The typed error for a C ABI code or an error code, core name
  /// (`OVERLOADED`) or client code (`overloaded`) alike.
  static _TypedKind? _typedKind(int nativeCode, String code) {
    if (nativeCode == _nativeOverloaded ||
        code == 'OVERLOADED' ||
        code == 'overloaded') {
      return _TypedKind.overloaded;
    }
    if (nativeCode == _nativeUpgradeRequired ||
        code == 'UPGRADE_REQUIRED' ||
        code == 'upgradeRequired') {
      return _TypedKind.upgradeRequired;
    }
    if (nativeCode == _nativeNetworkUncertain ||
        code == 'NETWORK_UNCERTAIN' ||
        code == 'networkUncertain') {
      return _TypedKind.networkUncertain;
    }
    return null;
  }

  /// [value] when it is a non-empty list of strings, else null.
  static List<String>? _stringList(Object? value) =>
      value is List && value.isNotEmpty && value.every((item) => item is String)
          ? List<String>.unmodifiable(value.cast<String>())
          : null;

  final String code;
  final String message;
  final String? operation;
  final Object? details;
  final String? reason;
  final bool retryable;
  final int? httpStatus;
  final int? remoteCode;
  final String? machineReason;

  /// The messages the operation refused, by id (a forward whose sources cannot
  /// all be forwarded).
  final List<String>? refusedMessageIds;

  @override
  String toString() {
    final op = operation == null ? '' : ' operation=$operation';
    return 'FlareSdkException(code=$code$op, message=$message)';
  }
}

enum _TypedKind { overloaded, upgradeRequired, networkUncertain }

/// The server is shedding load (`OVERLOADED`, C `FLARE_ERR_OVERLOADED`).
///
/// Retry on the same access point after [retryAfterMs] when given; it is never
/// an access point failure.
final class OverloadedException extends FlareSdkException {
  const OverloadedException({
    required super.message,
    super.operation,
    super.details,
    super.reason,
    super.retryable,
    super.httpStatus,
    super.remoteCode,
    super.machineReason,
    this.retryAfterMs,
  }) : super(code: 'OVERLOADED');

  /// How long the server asked to wait, when it said.
  final int? retryAfterMs;
}

/// The app build is below the server minimum (`UPGRADE_REQUIRED`,
/// C `FLARE_ERR_UPGRADE_REQUIRED`).
///
/// The session stays stopped (`actionRequired` / `upgradeRequired`) until the
/// user upgrades.
final class UpgradeRequiredException extends FlareSdkException {
  const UpgradeRequiredException({
    required super.message,
    super.operation,
    super.details,
    super.reason,
    super.retryable,
    super.httpStatus,
    super.remoteCode,
    super.machineReason,
  }) : super(code: 'UPGRADE_REQUIRED');
}

/// A non-idempotent request may or may not have reached the server
/// (`NETWORK_UNCERTAIN`, C `FLARE_ERR_NETWORK_UNCERTAIN`).
///
/// Reconcile with the same Idempotency-Key before retrying.
final class NetworkUncertainException extends FlareSdkException {
  const NetworkUncertainException({
    required super.message,
    super.operation,
    super.details,
    super.reason,
    super.retryable,
    super.httpStatus,
    super.remoteCode,
    super.machineReason,
  }) : super(code: 'NETWORK_UNCERTAIN');
}
