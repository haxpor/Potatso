[![donate button](https://img.shields.io/badge/$-donate-ff69b4.svg?maxAge=2592000&amp;style=flat)](https://github.com/haxpor/donate)

[![Build Status](https://travis-ci.org/haxpor/Potatso.svg?branch=master)](https://travis-ci.org/haxpor/Potatso)
![GPLv3 License](https://img.shields.io/badge/License-GPLv3-blue.svg)

# Potatso 

## Important

Please read [this](https://github.com/haxpor/Potatso/blob/master/ADHERE_LICENSE.md) first before you do anything with this project.  
In short, you need to respect to license of the project. You cannot copy the source code and publish to App Store.

---

## What is it?

Potatso is an iOS client that implements custom proxies with the leverage of Network Extension framework introduced by Apple since iOS 9.

Currently, Potatso is compatible with following proxies:

- [Shadowsocks](https://shadowsocks.org)
- [ShadowsocksR](https://github.com/breakwa11/shadowsocks-rss)

[Subscribe Telegram Channel](https://telegram.me/potatso) to get updates of Potatso.  
[Join Telegram Group](https://telegram.me/joinchat/BT0c4z49OGNZXwl9VsO0uQ) to chat with users.

Original Author: [@icodesign](https://twitter.com/icodesign_me)  
Swift 4 Maintainer: [@haxpor](https://twitter.com/haxpor)

## Project Info

Potatso has in total 26 dependencies as following

* 22 Cocoapod dependencies
* 4 submodules dependencies via local cocoapod

The project is tested with Xcode `9.4 (9F1027a)` on iOS `11.4 (15F79)` device with cocoapod version `1.4.0`+.  
If you experienced an expected issue, try to use those versions, if still experience the problem please file the issue.

The project will be further reduced for its dependencies.

## How to Build Project

Perform the following steps to be able to build the project.
Be warned that you **should not** call `pod update` as newer version of pod frameworks that Potatso depends on might break building process and there will be errors.

1. `git clone https://github.com/haxpor/Potatso.git` or for faster using less time in cloning `git clone https://github.com/haxpor/Potatso.git --depth=1`
2. `cd Potatso`
3. `git submodule update --init` to update git submodule
4. `pod install` to pull down dependencies into our project
5. Open `Potatso.xcworkspace` then Build and Run the project. Done.

> First two steps are clearly listed here as per [#89](https://github.com/haxpor/Potatso/issues/89); if you download project as zip via Github web interface it will not have enough information to pull down required gitsubmodule, and step 3 will have error. So make sure you clone via command line, or using any git client application before proceeding.
   
## How To Contribute

Clone the project, make some changes or add a new feature, then make a pull request.

## Acknowlegements

We use the following services or open-source libraries. So we'd like show them highest respect and thank for bringing those great projects:

### Services

- [Fabric](https://get.fabric.io/)
- [Reveal](http://revealapp.com/)
- [realm](https://realm.io/)

### Open-source Libraries

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

### Also we'd like to thank people that helped with the project

- [@Blankwonder](https://twitter.com/Blankwonder)
- [@龙七](#)
- [@haxpor](https://twitter.com/haxpor)
- TestFlight Users and [Telegram Group](https://telegram.me/joinchat/BT0c4z49OGNZXwl9VsO0uQ) users.

### Donate
- [@liqianyu](https://twitter.com/liqianyu)
- [@anonymous](#) x2

## Notice

Potatso 2 was released on [App Store](https://itunes.apple.com/us/app/id1162704202?mt=8)  
You can purchase it from App Store, or still use Potatso by building it manually and installing to your device from this project.

Please note that Potatso 2 will be closed-source as stated from original author's reason. Read more from [here](https://github.com/haxpor/Potatso/blob/master/ADHERE_LICENSE.md).

## Support Us

The development covers a lot of complicated work, costing not only money but also time.
These are the way to support

- [Download Potatso 2 from Apple Store](https://itunes.apple.com/us/app/id1162704202?mt=8). (**Recommended**) 
- Donate with Alipay to original author. (Account: **leewongstudio.com@gmail.com**)
- Donate to swift4 maintainer (WeChat: http://imgur.com/lsAao62, or PayPal: haxpor@gmail.com)

## License

**You cannot just copy the project, and publish to App Store.**  Please read [this](https://github.com/haxpor/Potatso/blob/master/ADHERE_LICENSE.md) first.

--

To be compatible with those libraries using GPL, we're distributing with GPLv3 license.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

