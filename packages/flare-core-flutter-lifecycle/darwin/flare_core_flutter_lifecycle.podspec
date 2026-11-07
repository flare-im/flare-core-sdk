Pod::Spec.new do |s|
  s.name             = 'flare_core_flutter_lifecycle'
  s.version          = '0.1.0'
  s.summary          = 'Flare Core platform lifecycle: network, foreground state and app version.'
  s.description      = <<-DESC
Reports the device network (NWPathMonitor) and the bundle version to the Flare Core SDK.
                       DESC
  s.homepage         = 'https://github.com/flare-im/flare-core-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Flare'
  s.source           = { :path => '.' }
  s.source_files     = 'flare_core_flutter_lifecycle/Sources/flare_core_flutter_lifecycle/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.frameworks       = 'Network'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
