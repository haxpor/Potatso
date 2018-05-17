source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

def fabric
    pod 'Fabric'
    pod 'Crashlytics'
end

def library
    pod 'KissXML', '~> 5.2.2'
    pod 'ICSMainFramework', :path => "./Library/ICSMainFramework/"
    pod 'MMWormhole', '~> 2.0.0'
    pod 'KeychainAccess'
end

def tunnel
    pod 'MMWormhole', '~> 2.0.0'
end

def socket
    pod 'CocoaAsyncSocket', '~> 7.4.3'
end

def model
    pod 'RealmSwift', '~> 2.10.2'
end

target "Potatso" do
    pod 'Aspects', :path => "./Library/Aspects/"
    pod 'Cartography'
    pod 'AsyncSwift'
    pod 'SwiftColor'
    pod 'Appirater'
    pod 'Eureka'
    pod 'MBProgressHUD'
    pod 'CallbackURLKit', :path => "./Library/CallbackURLKit"
    pod 'ICDMaterialActivityIndicatorView', '~> 0.1.0'
    pod 'Reveal-iOS-SDK', '~> 1.6.2', :configurations => ['Debug']
    pod 'ICSPullToRefresh', '~> 0.6'
    pod 'ISO8601DateFormatter', '~> 0.8'
    pod 'Alamofire'
    pod 'ObjectMapper'
    pod 'CocoaLumberjack/Swift', '~> 3.0.0'
    pod 'PSOperations'
    tunnel
    library
    fabric
    socket
    model
end

target "PacketTunnel" do
    tunnel
    socket
end

target "PacketProcessor" do
    socket
end

target "TodayWidget" do
    pod 'Cartography'
    pod 'SwiftColor'
    library
    socket
    model
end

target "PotatsoLibrary" do
    library
    model
    # YAML-Framework 0.0.3 is not available in cocoapods so we install it from local using git submodule
    pod 'YAML-Framework', :path => "./Library/YAML-Framework"
end

target "PotatsoModel" do
    model
end

target "PotatsoLibraryTests" do
    library
end

