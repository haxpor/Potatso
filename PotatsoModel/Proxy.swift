//
//  Proxy.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum ProxyType: String {
    case Shadowsocks = "SHADOWSOCKS"
    case Https = "HTTPS"
    case Socks5 = "SOCKS5"
    case None = "NONE"
}

extension ProxyType: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }
    
}

public enum ProxyError: ErrorType {
    case InvalidType
    case InvalidName
    case InvalidHost
    case InvalidPort
    case InvalidAuthScheme
    case NameAlreadyExists
    case InvalidUri
    case InvalidPassword
}

extension ProxyError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .InvalidType:
            return "Invalid type"
        case .InvalidName:
            return "Invalid name"
        case .InvalidHost:
            return "Invalid host"
        case .InvalidAuthScheme:
            return "Invalid encryption"
        case .InvalidUri:
            return "Invalid uri"
        case .NameAlreadyExists:
            return "Name already exists"
        case .InvalidPassword:
            return "Invalid password"
        case .InvalidPort:
            return "Invalid port"
        }
    }
    
}

public class Proxy: BaseModel {
    public dynamic var typeRaw = ProxyType.Shadowsocks.rawValue
    public dynamic var name = ""
    public dynamic var host = ""
    public dynamic var port = 0
    public dynamic var authscheme: String?
    public dynamic var user: String?
    public dynamic var password: String?
    public dynamic var ota: Bool = false

    public func validate(inRealm realm: Realm) throws {
        guard let _ = ProxyType(rawValue: typeRaw)else {
            throw ProxyError.InvalidType
        }
        guard name.characters.count > 0 else{
            throw ProxyError.InvalidName
        }
        guard realm.objects(Proxy).filter("name = '\(name)'").first == nil else {
            throw ProxyError.NameAlreadyExists
        }
        guard host.characters.count > 0 else {
            throw ProxyError.InvalidHost
        }
        guard port > 0 && port <= Int(UINT16_MAX) else {
            throw ProxyError.InvalidPort
        }
        switch type {
        case .Shadowsocks:
            guard let _ = authscheme else {
                throw ProxyError.InvalidAuthScheme
            }
        default:
            break
        }
    }

}

extension Proxy {
    
    public var type: ProxyType {
        get {
            return ProxyType(rawValue: typeRaw) ?? .Shadowsocks
        }
        set(v) {
            typeRaw = v.rawValue
        }
    }
    
    public override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
}

extension Proxy {
    
    public convenience init(dictionary: [String: AnyObject], inRealm realm: Realm) throws {
        self.init()
        if let uriString = dictionary["uri"] as? String {
            if uriString.lowercaseString.hasPrefix("ss://") {
                // Shadowsocks
                let proxyString = uriString.substringFromIndex(uriString.startIndex.advancedBy(5))
                guard let pc1 = proxyString.rangeOfString(":")?.startIndex, pc2 = proxyString.rangeOfString(":", options: .BackwardsSearch)?.startIndex, pcm = proxyString.rangeOfString("@", options: .BackwardsSearch)?.startIndex else {
                    throw ProxyError.InvalidUri
                }
                if !(pc1 < pcm && pcm < pc2) {
                    throw ProxyError.InvalidUri
                }
                let fullAuthscheme = proxyString.lowercaseString.substringWithRange(proxyString.startIndex..<pc1)
                if let pOTA = fullAuthscheme.rangeOfString("-auth", options: .BackwardsSearch)?.startIndex {
                    self.authscheme = fullAuthscheme.substringToIndex(pOTA)
                    self.ota = true
                }else {
                    self.authscheme = fullAuthscheme
                }
                self.password = proxyString.substringWithRange(pc1.successor()..<pcm)
                self.host = proxyString.substringWithRange(pcm.successor()..<pc2)
                guard let p = Int(proxyString.substringWithRange(pc2.successor()..<proxyString.endIndex)) else {
                    throw ProxyError.InvalidPort
                }
                self.port = p
                self.type = .Shadowsocks
            }else {
                // Not supported yet
                throw ProxyError.InvalidUri
            }
            guard let name = dictionary["name"] as? String else{
                throw ProxyError.InvalidName
            }
            self.name = name
        }else {
            guard let name = dictionary["name"] as? String else{
                throw ProxyError.InvalidName
            }
            guard let host = dictionary["host"] as? String else{
                throw ProxyError.InvalidHost
            }
            guard let typeRaw = (dictionary["type"] as? String)?.uppercaseString, type = ProxyType(rawValue: typeRaw) else{
                throw ProxyError.InvalidType
            }
            guard let portStr = (dictionary["port"] as? String), port = Int(portStr) else{
                throw ProxyError.InvalidPort
            }
            guard let encryption = dictionary["encryption"] as? String else{
                throw ProxyError.InvalidAuthScheme
            }
            guard let password = dictionary["password"] as? String else{
                throw ProxyError.InvalidPassword
            }
            self.host = host
            self.port = port
            self.password = password
            self.authscheme = encryption
            self.name = name
            self.type = type
        }
        if realm.objects(RuleSet).filter("name = '\(name)'").first != nil {
            self.name = Proxy.dateFormatter.stringFromDate(NSDate())
        }
        try validate(inRealm: realm)
    }
    
}

extension Proxy {
    
    public var uri: String {
        switch type {
        case .Shadowsocks:
            if let authscheme = authscheme, password = password {
                return "ss://\(authscheme):\(password)@\(host):\(port)"
            }
        default:
            break
        }
        return ""
    }
    public override var description: String {
        return name
    }
}

public func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.uuid == rhs.uuid
}