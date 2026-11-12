Pod::Spec.new do |s|
  s.name             = 'FlarePlatformPush'
  s.version          = '0.1.0'
  s.summary          = 'Flare platform push for iOS without the engine.'
  s.description      = <<-DESC
The FlarePlatformPush target of flare-core-apple-sdk as a pod, for Flutter hosts that build plugins with
CocoaPods. The sources are symbolic links to that package; nothing is copied.
                       DESC
  s.homepage         = 'https://github.com/flare-im/flare-core-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Flare'
  s.source           = { :path => '.' }
  s.source_files     = 'flare_core_flutter_push/Sources/FlarePlatformPush/*.swift'
  s.dependency 'FlarePlatformLifecycle'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'UserNotifications'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
