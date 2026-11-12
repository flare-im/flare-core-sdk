Pod::Spec.new do |s|
  s.name             = 'flare_core_flutter_push'
  s.version          = '0.1.0'
  s.summary          = 'Flare system push bridge: FlarePlatformPush behind a Flutter method channel.'
  s.description      = <<-DESC
Bridges FlarePlatformPush (notification permission, APNs registration, silent pushes, foreground
presentation, taps, badge) to Dart. FlarePlatformPush and FlarePlatformLifecycle are separate pods in
this directory whose sources are linked from flare-core-apple-sdk; a CocoaPods host lists both in its
Podfile (see README). SwiftPM hosts need nothing extra.
                       DESC
  s.homepage         = 'https://github.com/flare-im/flare-core-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Flare'
  s.source           = { :path => '.' }
  s.source_files     = 'flare_core_flutter_push/Sources/flare_core_flutter_push/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'FlarePlatformPush'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'UserNotifications'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
