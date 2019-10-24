#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint chirp_flutter.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'chirp_flutter'
  s.version          = '0.0.1'
  s.summary          = 'ChirpSDK Flutter'
  s.description      = <<-DESC
ChirpSDK iOS plugin for Flutter
                       DESC
  s.homepage         = 'https://chirp.io'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Asio Ltd' => 'developers@chirp.io' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency         'Flutter'
  s.dependency         'ChirpSDK', '3.6.0'

  s.static_framework = true
  s.platform         = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
end
