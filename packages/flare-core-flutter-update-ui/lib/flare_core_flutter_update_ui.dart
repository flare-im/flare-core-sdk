/// The Flare update center on the Flare IM UI Kit.
///
/// Create the controller with [flutterUpdateController], put a
/// [FlareUpdateScope] above the app's navigator and a [FlareUpdatePromptHost]
/// below it, around a page. Deep widgets ask the scope: the connection notice
/// for the controller, the composer for read-only mode, the settings row for
/// the badge. The engine decides what shows; nothing here keeps its own idea of
/// the prompt. A [FlareUpdateResourceScope] at the root puts this run's resource
/// packs over the Kit's built-in resources.
library;

export 'package:flare_core_flutter_update/flare_core_flutter_update.dart'
    show flutterAppConfig, flutterUpdateController;

export 'src/flare_update_about_screen.dart';
export 'src/flare_update_prompt_host.dart';
export 'src/flare_update_resource_scope.dart';
export 'src/flare_update_scope.dart';
