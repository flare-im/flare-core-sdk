/// Flutter host side of the Flare update center.
///
/// Create the controller with [flutterUpdateController]: the engine decides,
/// the controller of `flare_core_flutter_sdk` runs the flow, and this package
/// carries out the plans on the host. Android reuses
/// `flare-core-android-update`, iOS and macOS `FlarePlatformUpdate`; Windows
/// and Linux open the plan's link.
library;

export 'src/flutter_app_config.dart';
export 'src/flutter_update_installer.dart';
