import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart'
    show FlareUpdateController, FlareUpdatePromptForm, FlareUpdateStatus;
import 'package:flutter/widgets.dart';

enum _Aspect { status, readOnly, badge }

/// Hands an update controller and its status to the widgets below.
///
/// It goes above the app's navigator: chat pages are pushed routes, and a
/// status they only got through their constructor would not follow them.
/// Without a scope (a page in a test) there is no status, no read-only mode and
/// no badge.
class FlareUpdateScope extends StatefulWidget {
  const FlareUpdateScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final FlareUpdateController controller;
  final Widget child;

  /// The controller, for an action. Does not rebuild the caller.
  static FlareUpdateController? controllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FlareUpdateModel>()?.controller;

  /// The whole status; rebuilds the caller on every change, progress included.
  static FlareUpdateStatus? statusOf(BuildContext context) =>
      _model(context, _Aspect.status)?.status;

  /// Whether the app is read only: the composer is disabled while it is.
  static bool readOnlyOf(BuildContext context) =>
      _model(context, _Aspect.readOnly)?.readOnly ?? false;

  /// Whether the entry to the About page carries the badge.
  static bool badgeOf(BuildContext context) =>
      _model(context, _Aspect.badge)?.badge ?? false;

  static _FlareUpdateModel? _model(BuildContext context, _Aspect aspect) =>
      InheritedModel.inheritFrom<_FlareUpdateModel>(context, aspect: aspect);

  @override
  State<FlareUpdateScope> createState() => _FlareUpdateScopeState();
}

class _FlareUpdateScopeState extends State<FlareUpdateScope> {
  StreamSubscription<FlareUpdateStatus>? _statuses;
  FlareUpdateStatus? _status;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(FlareUpdateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    unawaited(_statuses?.cancel());
    _follow();
  }

  @override
  void dispose() {
    unawaited(_statuses?.cancel());
    super.dispose();
  }

  void _follow() {
    _status = widget.controller.status;
    _statuses = widget.controller.statuses.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  Widget build(BuildContext context) => _FlareUpdateModel(
        controller: widget.controller,
        status: _status,
        child: widget.child,
      );
}

class _FlareUpdateModel extends InheritedModel<_Aspect> {
  const _FlareUpdateModel({
    required this.controller,
    required this.status,
    required super.child,
  });

  final FlareUpdateController controller;
  final FlareUpdateStatus? status;

  bool get readOnly => status?.readOnly ?? false;
  bool get badge => status?.prompt == FlareUpdatePromptForm.badge;

  @override
  bool updateShouldNotify(_FlareUpdateModel oldWidget) =>
      !identical(oldWidget.status, status);

  /// Download progress changes the status several times a second; a chat page
  /// that only asks about read-only mode should not rebuild for it.
  @override
  bool updateShouldNotifyDependent(
    _FlareUpdateModel oldWidget,
    Set<_Aspect> dependencies,
  ) =>
      dependencies.contains(_Aspect.status) ||
      (dependencies.contains(_Aspect.readOnly) &&
          oldWidget.readOnly != readOnly) ||
      (dependencies.contains(_Aspect.badge) && oldWidget.badge != badge);
}
