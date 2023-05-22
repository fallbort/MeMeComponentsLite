#
#  Be sure to run `pod spec lint MeMeComponents.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "MeMeComponents"
  spec.version      = "1.0.0"
  spec.summary      = "MeMeComponents Modules"

  spec.description  = <<-DESC
                   MeMeComponents Modules,contain,
                   1.MeMeComponents
                   DESC

  spec.homepage     = "https://bitbucket.org/funplus/streaming-client-compents"

  spec.license      = "MIT"
#  spec.license      = { :type => "MIT", :file => "LICENSE.md" }

  spec.author             = { "xfb" => "fabo.xie@nextentertain.com" }

  # spec.platform     = :ios
   spec.platform     = :ios, "10.0"
   spec.ios.deployment_target = "10.0"

  spec.source       = { :git => "https://bitbucket.org/funplus/streaming-client-compents.git",:tag => "#{spec.version}" }

  spec.swift_version = '5.0'
  spec.static_framework = true

  spec.default_subspec = 'Base'

  spec.subspec 'Base' do |base|
      base.source_files = 'Source/Base/**/*.{h,m,swift}'
      base.dependency 'MeMeKit'
      base.framework    = "Foundation"
  end

  spec.subspec 'Net' do |base|
      base.source_files = 'Source/Net/**/*.{h,m,swift}'
      base.dependency 'MeMeKit'
      base.dependency 'MeMeComponents/Base'
      base.dependency 'Alamofire'
      base.dependency 'AlamofireNetworkActivityIndicator'
      base.dependency 'ObjectMapper'
      base.dependency 'Result'
      base.dependency 'RxSwift'
      base.dependency 'Moya'
      base.framework   = "Foundation"
  end
end
