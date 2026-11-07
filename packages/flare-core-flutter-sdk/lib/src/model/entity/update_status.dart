// GENERATED. Do not edit by hand.
import 'update_current_app.dart';
import 'update_error_info.dart';
import 'update_progress.dart';
import 'update_release_summary.dart';

/// Update center state: the update://state payload and the answer of every update.* call but install.
final class UpdateStatus {
  /// wire: `state`. idle, checking, upToDate, available, required, downloading, verifying, readyToInstall, installing or failed.
  final String state;
  /// wire: `current`. The running app.
  final UpdateCurrentApp current;
  /// wire: `release`. The release on offer. Can be absent in required: the server rejected this build and no manifest arrived yet.
  final UpdateReleaseSummary? release;
  /// wire: `progress`. Present while downloading.
  final UpdateProgress? progress;
  /// wire: `prompt`. none, badge, sheet, modal or fullscreen. The core keeps it through the whole flow; bind to it directly.
  final String prompt;
  /// wire: `blockUi`. A forced update blocks the interface.
  final bool blockUi;
  /// wire: `readOnly`. The connection was refused with UPGRADE_REQUIRED or REST answered 426.
  final bool readOnly;
  /// wire: `lastCheckedAt`. Last successful check, Unix milliseconds.
  final int? lastCheckedAt;
  /// wire: `error`. Why the last action did not go through.
  final UpdateErrorInfo? error;
  /// wire: `blockReason`. Why this build is blocked, in the chosen language. Present when the current build falls in blockedBuilds and the range gives a reason; a forced prompt shows it ahead of the fixed text.
  final String? blockReason;

  const UpdateStatus({
    this.state = '',
    required this.current,
    this.release,
    this.progress,
    this.prompt = '',
    this.blockUi = false,
    this.readOnly = false,
    this.lastCheckedAt,
    this.error,
    this.blockReason,
  });
}
