# Potatso ![GPLv3 License](https://img.shields.io/badge/License-GPLv3-blue.svg)

<a href="https://itunes.apple.com/app/apple-store/id1070901416?pt=2305194&ct=potatso.github&mt=8">![](https://cdn.rawgit.com/shadowsocks/Potatso/master/Download.svg)</a>

Potatso is an iOS client that implements custom proxies with the leverage of Network Extension framework introduced by Apple since iOS 9.

Currently, Potatso is compatible with following proxies:

- [Shadowsocks](https://shadowsocks.org)
- [ShadowsocksR](https://github.com/breakwa11/shadowsocks-rss)

[Subscribe Telegram Channel](https://telegram.me/potatso) to get updates of Potatso. 

[Join Telegram Group](https://telegram.me/joinchat/BT0c4z49OGNZXwl9VsO0uQ) to chat with users.

Author: [icodesign](https://twitter.com/icodesign_me)

## Project Info

Potatso has in total 31 dependencies as following

* 28 Cocoapod dependencies
* 1 Carthage dependency
* 2 submodules dependencies

The project is tested with Xcode 8.2 (8C38) on iOS 10.2 (14C92) device with cocoapod version `1.0.1`.
If you experience error in building the project, it's good idea to proceed with cocoapod version `1.0.1` first by doing the following steps

* `sudo gem uninstall cocoapods` - to uninstall the current version first
* `sudo gem install cocoapods -v 1.0.1` - to specifically install cocoapods version `1.0.1`
* `pod --version` - to check version of current installed cocoapods. It should output `1.0.1`.

## Set up Guide - Code

Perform the following steps to be able to build the project.

1. `git submodule update --init` to update git submodule
2. `pod install` to pull down dependencies into our project
3. `carthage update` to pull down dependencies into `Carthage/Checkouts` folder and build each one
4. If **not** yet have "YAML.framework" as part of "Linked Frameworks and Libraries" section in "General" tab of Potatso target, then drag and drop `YAML.framework` file from `Carthage/Build/iOS` into it.
5. If **not** yet have "Carthage" run script inside "Build Phases" of Potato target, then click the "+" icon and choose "New Run Script Phase". Create a Run Script with name "Carthage" in which has `bin/sh` as shell with following content  
     
   ```json
   /usr/local/bin/carthage copy-frameworks  
   ```
     
   and add the paths to added framework under "Input Files" as follows  
     
   ```json
   $(SRCROOT)/Carthage/Build/iOS/YAML.framework  
   ```
   
6. Search for `io.wasin.potatso` for project-wide, and replace it with your own domain name. This is necessary as you need to create your own provisioning profile as it uses your domain name.
7. Open file `CallbackURLKit.swift` by hitting cmd+shift+o then enter the name of file. Add @escaping in front of all function signature parameters in `ActionHandler` defined at the top of the file. Make it as follows  
     
   ```swift
   public typealias ActionHandler = (Parameters, @escaping SuccessCallback, @escaping FailureCallback, @escaping CancelCallback) -> Void  
   ```  
8. Build the project. Done.

## Set up Guide - Apple Developer Website

Note that it's better to not allow Xcode to automatically manage yoru provisioning profile for the application included Potatso (main app), PacketTunnel (extension), and TodayWidget (extension). Most of the time, such provisioning profile won't generate on developer page, or point to generic one which makes it not working!.

So follow the following steps

* Create 3 App IDs for `Potatso`, `PacketTunnel`, and `TodayWidget`. Make sure to name bundle id for each one matches the ones that use in code. In this case `io.wasin.potatso`, `io.wasin.potatso.tunnel`, and `io.wasin.potatso.todaywidget` respectively. Rename to be your domain name freely.
   * **`Potatso`**  
      Enable `App Groups`, `Game Center`, `iCloud`, `In-App Purchase`, `Network Extensions`, and `Push Notifications`.
   * **`PacketTunnel`**  
      Enable `App Groups`, `Game Center`, `In-App Purchase`, and `Network Extensions`.
   * **`TodayWidget`**  
      Enable `App Groups`, `Game Center`, `In-App Purchase`, and `Network Extensions`.

* Create 3 corresponding provisioning profile for each created App ID.
* Now go back to Xcode
* Click on project -> click on General tap -> select `Potatso` target and uncheck "Automatically manage signing" -> select a proper provisioning profile in both "Signing (Debug)" and "Signing (Release)".
* Do the same for `PacketTunnel` and `TodayWidget` target.

## TODO

There're a couple of issues that needed to look at, but at tested, it doens't effect the functionality of the app.

* In file `Potatso/Core/API.swift`, it's the following code focusing on line with comment that I can't figure it out yet how to migrate it to Swift 3 code.  

   ```swift
   var JSONToMap: AnyObject?
   if let keyPath = keyPath, keyPath.isEmpty == false {
       //JSONToMap = (result.value? as AnyObject).value(forKeyPath: keyPath)
       JSONToMap = nil
   } else {
       JSONToMap = result.value as AnyObject?
   }
   ```
   
## How To Contribute

Clone the project, make some changes or add a new feature, then make a pull request.

## Support Us

The development covers a lot of complicated work, costing not only money but also time.

There're two ways you can support us:

- [Download Potatso from Apple Store](https://itunes.apple.com/app/apple-store/id1070901416?pt=2305194&ct=potatso.github&mt=8). (**Recommended**) 

- Donate with Alipay. (Account: **leewongstudio.com@gmail.com**)

## Acknowlegements

We use the following services or open-source libraries. So we'd like show them highest respect and thank for bringing those great projects:

Services:

- [Fabric](https://get.fabric.io/)
- [Reveal](http://revealapp.com/)
- [realm](https://realm.io/)
- [HelpShift](https://www.helpshift.com)

Open-source Libraries:

- [KissXML](https://github.com/robbiehanson/KissXML)
- [MMWormhole](https://github.com/mutualmobile/MMWormhole)
- [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket)
- [Cartography](https://github.com/robb/Cartography)
- [AsyncSwift](https://github.com/duemunk/Async)
- [Appirater](https://github.com/arashpayan/appirater)
- [Eureka](https://github.com/xmartlabs/Eureka)
- [MBProgressHUD](https://github.com/matej/MBProgressHUD)
- [CallbackURLKit](https://github.com/phimage/CallbackURLKit)
- [ISO8601DateFormatter](https://github.com/boredzo/iso-8601-date-formatter)
- [Alamofire](https://github.com/Alamofire/Alamofire)
- [ObjectMapper](https://github.com/Hearst-DD/ObjectMapper)
- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack)
- [AlamofireObjectMapper](https://github.com/tristanhimmelman/AlamofireObjectMapper)
- [YAML.framework](https://github.com/mirek/YAML.framework)
- [tun2socks-iOS](https://github.com/shadowsocks/tun2socks-iOS)
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [Antinat](http://antinat.sourceforge.net/)
- [Privoxy](https://www.privoxy.org/)

Also we'd like to thank people that helped with the project:

- [@Blankwonder](https://twitter.com/Blankwonder)
- [@龙七](#)
- [@haxpor](https://twitter.com/haxpor)

or donated us:
- [@liqianyu](https://twitter.com/liqianyu)
- [@anonymous](#) x2

And also thank all TestFlight Users and [Telegram Group](https://telegram.me/joinchat/BT0c4z49OGNZXwl9VsO0uQ) Users.


Thanks again!

## License

**You can't submit the app to App Store.**

To be compatible with those libraries using GPL, we're distributing with GPLv3 license.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.


