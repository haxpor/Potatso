//
//  ConfigurationGroup.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum ConfigurationGroupError: Error {
    case invalidConfigurationGroup
    case emptyName
    case nameAlreadyExists
}

extension ConfigurationGroupError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .invalidConfigurationGroup:
            return "Invalid config group"
        case .emptyName:
            return "Empty name"
        case .nameAlreadyExists:
            return "Name already exists"
        }
    }
    
}


open class ConfigurationGroup: BaseModel {
    @objc open dynamic var editable = true
    @objc open dynamic var name = ""
    @objc open dynamic var defaultToProxy = true
    @objc open dynamic var dns = ""
    open var proxies = List<Proxy>()
    open var ruleSets = List<RuleSet>()
    
    open override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
    open override func validate(inRealm realm: Realm) throws {
        guard !name.isEmpty else {
            throw ConfigurationGroupError.emptyName
        }
    }

    open override var description: String {
        return name
    }
}

extension ConfigurationGroup {
    
    public convenience init(dictionary: [String: AnyObject], inRealm realm: Realm) throws {
        self.init()
        guard let name = dictionary["name"] as? String else {
            throw ConfigurationGroupError.invalidConfigurationGroup
        }
        self.name = name
        if realm.objects(RuleSet.self).filter("name = '\(name)'").first != nil {
            self.name = "\(name) \(ConfigurationGroup.dateFormatter.string(from: Date()))"
        }
        if let proxyName = dictionary["proxy"] as? String, let proxy = realm.objects(Proxy.self).filter("name = '\(proxyName)'").first {
            self.proxies.removeAll()
            self.proxies.append(proxy)
        }
        if let ruleSetsName = dictionary["ruleSets"] as? [String] {
            for ruleSetName in ruleSetsName {
                if let ruleSet = realm.objects(RuleSet.self).filter("name = '\(ruleSetName)'").first {
                    self.ruleSets.append(ruleSet)
                }
            }
        }
        if let defaultToProxy = dictionary["defaultToProxy"] as? NSString {
            self.defaultToProxy = defaultToProxy.boolValue
        }
        if let dns = dictionary["dns"] as? String {
            self.dns = dns
        }
        if let dns = dictionary["dns"] as? [String] {
            self.dns = dns.joined(separator: ",")
        }
    }

    
}

public func ==(lhs: ConfigurationGroup, rhs: ConfigurationGroup) -> Bool {
    return lhs.uuid == rhs.uuid
}
