Pod::Spec.new do |s|
  s.name             = 'FlarePlatformLifecycle'
  s.version          = '0.1.0'
  s.summary          = 'Flare platform lifecycle for iOS without the engine.'
  s.description      = <<-DESC
The FlarePlatformLifecycle target of flare-core-apple-sdk as a pod: what FlarePlatformPush builds on
(foreground state, background execution, app info). The sources are symbolic links to that package.
                       DESC
  s.homepage         = 'https://github.com/flare-im/flare-core-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Flare'
  s.source           = { :path => '.' }
  s.source_files     = 'flare_core_flutter_push/Sources/FlarePlatformLifecycle/*.swift'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'Network'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
