Pod::Spec.new do |s|
  s.name             = 'flare_core_flutter_push'
  s.version          = '0.1.0'
  s.summary          = 'Flare system notifications on macOS: the engine presentations in the notification centre.'
  s.description      = <<-DESC
Posts the engine's system presentations through UNUserNotificationCenter (one notification per
conversation, the collapse id as identifier), takes them down on clear, sets the dock badge and routes a
click back to Dart. macOS has no push binding here: the desktop alerts by itself.
                       DESC
  s.homepage         = 'https://github.com/flare-im/flare-core-sdk'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'Flare'
  s.source           = { :path => '.' }
  s.source_files     = 'flare_core_flutter_push/Sources/flare_core_flutter_push/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.15'
  s.frameworks       = 'UserNotifications'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
