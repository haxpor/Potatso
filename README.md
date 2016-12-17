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

The project is tested with Xcode 8.2 beta (8C30a) on iOS 10.2 (14C92) device.

## Guide

Perform the following steps to be able to build the project.

1. `git submodule update --init` to update git submodule
2. `pod install` to pull down dependencies into our project
3. `carthage update` to pull down dependencies into `Carthage/Checkouts` folder and build each one
4. On application targets' "General" settings tab in the "Linked Frameworks and Libraries" section of Potatso target, drag and drop `YAML.framework` file from `Carthage/Build/iOS` into it.
5. On application targets' "Build Phases" settings tab, click the "+" icon and choose "New Run Script Phase". Create a Run Script in which has `bin/sh` as shell with following content  
     
   ```shell
   /usr/local/bin/carthage copy-frameworks  
   ```
     
   and add the paths to added framework under "Input Files" as follows  
     
   ```
   $(SRCROOT)/Carthage/Build/iOS/YAML.framework  
   ```
   
6. Search for `io.wasin.potatso` for project-wide, and replace it with your own domain name. This is necessary as you need to create your own provisioning profile as it uses your domain name.
7. Open file `CallbackURLKit.swift` by hitting cmd+shift+o then enter the name of file. Add @escaping in front of all function signature parameters in `ActionHandler` defined at the top of the file. Make it as follows  
     
   ```
   public typealias ActionHandler = (Parameters, @escaping SuccessCallback, @escaping FailureCallback, @escaping CancelCallback) -> Void  
   ```  
     
   At this point, you can try to build the project to your device. It should be successful. **Note** only build but its functionality is not complete yet as we need to proceed to next step.
8. Send a request to Apple asking for permission to use core features of Network extension API that this project utilizes by heading to [https://developer.apple.com/contact/network-extension/](https://developer.apple.com/contact/network-extension/). Fill out the form, and send. This might take around 2 weeks as seen [here](http://www.jianshu.com/p/ee038189f373) (Chinese content).
9. ... to be updated ...

## How To Contribute

// TODO

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


