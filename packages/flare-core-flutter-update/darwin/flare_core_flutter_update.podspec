Pod::Spec.new do |s|
  s.name             = 'flare_core_flutter_update'
  s.version          = '0.1.0'
  s.summary          = 'Flare update center host side: opens the App Store and TestFlight.'
  s.description      = <<-DESC
Runs the engine's install plans on iOS and macOS. The sources of FlarePlatformUpdate are linked in
next to the plugin: a pod cannot depend on a SwiftPM product, and that package's iOS 15 floor is above
what Flutter hosts deploy to.
                       DESC
  s.homepage         = 'https://github.com/flare-im/flare-core-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Flare'
  s.source           = { :path => '.' }
  s.source_files     = 'flare_core_flutter_update/Sources/flare_core_flutter_update/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
