import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as sdk;
import 'package:flare_im_ui/flare_im_ui.dart' as kit;
import 'package:flutter/widgets.dart';

import 'flare_update_resource_scope.dart';
import 'flare_update_scope.dart';

/// Stands in for the version when neither a release nor the install names one.
/// A forced update without a release shows the running version: the server
/// refused this build before the manifest arrived.
const String _unknownVersion = '—';

/// The Kit's prompt for the status in the [FlareUpdateScope] above: it opens
/// when `status.prompt` asks for a prompt and closes when the engine stops
/// asking. It tells the engine once a prompt is on screen, which its frequency
/// rules count on.
///
/// It goes under the app's navigator, around a page. One at a time: the prompt
/// is a route on the root navigator, so a second host would open a second one.
class FlareUpdatePromptHost extends StatefulWidget {
  const FlareUpdatePromptHost({super.key, required this.child});

  final Widget child;

  @override
  State<FlareUpdatePromptHost> createState() => _FlareUpdatePromptHostState();
}

class _FlareUpdatePromptHostState extends State<FlareUpdatePromptHost> {
  static const kit.FlareUpdatePrompt _none = kit.FlareUpdatePrompt(
    form: kit.FlareUpdatePromptForm.sheet,
    version: _unknownVersion,
  );

  /// What was last on screen: a closing route keeps it to the end.
  kit.FlareUpdatePrompt _last = _none;

  /// What the engine has already heard about.
  ({sdk.FlareUpdatePromptForm form, int? build})? _marked;

  void _markPrompted(
    sdk.FlareUpdateController controller,
    sdk.FlareUpdateStatus status,
  ) {
    final shown = (form: status.prompt, build: status.release?.build);
    if (shown == _marked) return;
    _marked = shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.markPrompted());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = FlareUpdateScope.controllerOf(context);
    final status = FlareUpdateScope.statusOf(context);
    final form = _kitForm(status?.prompt);
    final settled = FlareUpdateResourceScope.settledOf(context);
    if (controller == null || status == null || form == null || !settled) {
      _marked = null;
      return kit.FlareUpdatePromptPresenter(
        open: false,
        prompt: _last,
        child: widget.child,
      );
    }
    _last = _prompt(controller, status, form);
    _markPrompted(controller, status);
    return kit.FlareUpdatePromptPresenter(
      open: true,
      prompt: _last,
      child: widget.child,
    );
  }

  kit.FlareUpdatePrompt _prompt(
    sdk.FlareUpdateController controller,
    sdk.FlareUpdateStatus status,
    kit.FlareUpdatePromptForm form,
  ) {
    final release = status.release;
    final progress = status.progress;
    final error = status.error;
    void update() => unawaited(controller.update());
    return kit.FlareUpdatePrompt(
      form: form,
      version: release?.version ?? status.current.version ?? _unknownVersion,
      notes: release?.notes ?? const [],
      reason: status.blockReason,
      sizeBytes: release?.sizeBytes,
      mandatory: release?.mandatory ??
          status.state == sdk.FlareUpdateState.required,
      state: status.state.name,
      progress: progress == null
          ? null
          : kit.FlareUpdateProgress(
              received: progress.received,
              total: progress.total,
            ),
      errorCode: error?.code,
      retryable: error?.retryable ?? true,
      fallbackTarget: switch (status.fallbackTarget) {
        sdk.FlareUpdateFallbackTarget.website =>
          kit.FlareUpdateFallbackTarget.website,
        sdk.FlareUpdateFallbackTarget.store =>
          kit.FlareUpdateFallbackTarget.store,
      },
      canContinueReadOnly: status.canContinueReadOnly,
      onUpdate: update,
      onLater: () => unawaited(controller.later()),
      onSkip: () => unawaited(controller.skip()),
      onRetry: update,
      onFallback: error?.fallbackUrl == null
          ? null
          : () => unawaited(controller.openFallback()),
      onContinueReadOnly: () => unawaited(controller.continueReadOnly()),
    );
  }
}

/// The form of a prompt; null for `none` and `badge`, which are not prompts.
kit.FlareUpdatePromptForm? _kitForm(sdk.FlareUpdatePromptForm? form) =>
    switch (form) {
      sdk.FlareUpdatePromptForm.sheet => kit.FlareUpdatePromptForm.sheet,
      sdk.FlareUpdatePromptForm.modal => kit.FlareUpdatePromptForm.modal,
      sdk.FlareUpdatePromptForm.fullscreen =>
        kit.FlareUpdatePromptForm.fullscreen,
      sdk.FlareUpdatePromptForm.none ||
      sdk.FlareUpdatePromptForm.badge ||
      null =>
        null,
    };
