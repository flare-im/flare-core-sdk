/// Flutter platform lifecycle for the Flare Core SDK.
///
/// Create the client with [FlareCoreFlutter.createClient]: after `init`
/// succeeds it reports the device network (from the native network callbacks)
/// and foreground state (from `AppLifecycleListener`) to the core, and fills
/// `sdkConfig.app` from the installed package. Apps add no wiring of their own.
library;

export 'src/flare_core_flutter.dart';
export 'src/flutter_platform_lifecycle_source.dart';
export 'src/flutter_recover_scheme.dart';
