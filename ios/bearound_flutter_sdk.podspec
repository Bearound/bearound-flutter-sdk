#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bearound_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bearound_flutter_sdk'
  s.version          = '2.2.1'
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
  s.dependency 'BearoundSDK', '~> 2.2.1'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more infssos para Importar o SDK Natiormation,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'bearound_flutter_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
