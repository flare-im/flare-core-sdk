import 'dart:async';

import 'package:flare_im_ui/flare_im_ui.dart' as kit;
import 'package:flutter/material.dart';

import 'flare_update_scope.dart';

/// Stands in for the version on a platform that cannot read it.
const String _unknownVersion = '—';

/// The Kit's version panel for the status in the [FlareUpdateScope] above. It
/// sizes to its content, so it goes inside a scrolling page.
class FlareUpdateVersionPanel extends StatelessWidget {
  const FlareUpdateVersionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FlareUpdateScope.controllerOf(context);
    final status = FlareUpdateScope.statusOf(context);
    return kit.FlareVersionPanel(
      version: status?.current.version ?? _unknownVersion,
      build: status?.current.build,
      channel: status?.current.channel,
      updateState: status?.state.name,
      onCheck: controller == null ? null : () => unawaited(controller.check()),
      onUpdate:
          controller == null ? null : () => unawaited(controller.update()),
    );
  }
}

/// The page a settings row opens: the version, the build, the channel and the
/// row that checks for an update.
class FlareUpdateAboutScreen extends StatelessWidget {
  const FlareUpdateAboutScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: kit.FlareScreen(
          title: kit.FlareStrings.of(context).versionPanelTitle,
          onBack: onBack,
          child: const FlareUpdateVersionPanel(),
        ),
      );
}
