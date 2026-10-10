#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bearound_flutter_sdk.podspec` to validate before publishing.
#
require 'yaml'

# Single source of truth for the version: read it from pubspec.yaml (repo root).
pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'bearound_flutter_sdk'
  s.version          = pubspec['version'].to_s
  s.summary          = 'BearoundSDK secure BLE beacon detection and indoor positioning by Bearound.'
  s.description      = <<-DESC
Official SDKs for integrating Bearound's secure BLE beacon detection and indoor location technology across Android, iOS, React Native, and Flutter.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'BeAround' => 'felipe.araujo@opencircle.com.br' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  if ENV['BEAROUND_APP_PRESENCE_LOCAL'] == '1'
    # Local native SDK (development only, opt-in, see scripts/app-presence-local-native.sh).
    # Require the version the local BearoundSDK.podspec declares, so the host's
    # `pod 'BearoundSDK', :path => ...` never conflicts with the release pin below.
    ios_sdk_path = ENV['BEAROUND_IOS_SDK_PATH'].to_s
    native_podspec = File.join(ios_sdk_path, 'BearoundSDK.podspec')
    unless ios_sdk_path.start_with?('/') && File.file?(native_podspec)
      raise "BEAROUND_APP_PRESENCE_LOCAL=1 requires BEAROUND_IOS_SDK_PATH to be the absolute path of a native iOS SDK checkout (got '#{ios_sdk_path}')."
    end
    unless File.file?(File.join(ios_sdk_path, 'BearoundSDK', 'Models', 'AppPresence.swift'))
      raise "Native iOS SDK at #{ios_sdk_path} does not contain the app presence API."
    end
    s.dependency 'BearoundSDK', Pod::Specification.from_file(native_podspec).version.to_s
  else
    s.dependency 'BearoundSDK', '3.15.0'
  end

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more infssos para Importar o SDK Natiormation,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'bearound_flutter_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
