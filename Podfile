# Podfile for flowall
platform :osx, '13.0'

target 'flowall' do
  use_frameworks!

  # No dependencies needed - using native WKWebView for video playback
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
