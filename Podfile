source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

def fabric
    pod 'Fabric'   #crash日志收集
    pod 'Crashlytics'
end

def library
    pod 'KissXML'
    pod 'KissXML/libxml_module'
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
    pod 'RealmSwift'
end

target "Potatso" do
    pod 'Aspects', :path => "./Library/Aspects/"       #类方法的拦截
    pod 'Cartography', :git => 'https://github.com/corujautx/Cartography.git'  #自动布局约束
    pod 'AsyncSwift'
    pod 'SwiftColor'
    pod 'Appirater'     #提醒用户评论打分
    pod 'Eureka', :path => "./Library/Eureka/"      #talbeView 第三方库
    pod 'MBProgressHUD'
    pod 'CallbackURLKit', :path => "./Library/CallbackURLKit"
    pod 'ICDMaterialActivityIndicatorView', '~> 0.1.0'
    pod 'Reveal-iOS-SDK', '~> 1.6.2', :configurations => ['Debug']  #界面调试工具
    pod 'ICSPullToRefresh', '~> 0.6'
    pod 'ISO8601DateFormatter', '~> 0.8'
    pod 'Alamofire'     #requests工具
    pod 'ObjectMapper'
    pod 'CocoaLumberjack/Swift', '~> 3.0.0'  #抓取crash日志上传
    #    pod 'Helpshift', '5.6.1'   #国外的客服系统
    pod 'PSOperations', '~> 3.0.0'  #线程管理工具
    #    pod 'LogglyLogger-CocoaLumberjack', '~> 3.0'
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
    pod 'Cartography', :git => 'https://github.com/corujautx/Cartography.git'
    pod 'SwiftColor'
    library
    socket
    model
end

target "PotatsoLibrary" do
    library
    model
end

target "PotatsoModel" do
    model
end

target "PotatsoLibraryTests" do
    library
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ENABLE_BITCODE'] = 'NO'
            if target.name == "HelpShift"
                config.build_settings["OTHER_LDFLAGS"] = '$(inherited) "-ObjC"'
            end
        end
    end
end

