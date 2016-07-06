//
//  Config.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import PotatsoModel
import YAML

public enum ConfigError: ErrorType {
    case DownloadFail
    case SyntaxError
}

extension ConfigError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .DownloadFail:
            return "Download fail"
        case .SyntaxError:
            return "Syntax error"
        }
    }
    
}

public class Config {
    
    public var groups: [ConfigurationGroup] = []
    public var proxies: [Proxy] = []
    public var ruleSets: [RuleSet] = []
    
    let realm: Realm
    var configDict: [String: AnyObject] = [:]
    
    public init() {
        realm = try! Realm()
    }
    
    public func setup(string configString: String) throws {
        guard configString.characters.count > 0, let object = try? YAMLSerialization.objectWithYAMLString(configString, options: kYAMLReadOptionStringScalars), yaml = object as? [String: AnyObject] else {
            throw ConfigError.SyntaxError
        }
        self.configDict = yaml
        try setupModels()
    }
    
    public func setup(url url: NSURL) throws {
        guard let string = try? String(contentsOfURL: url) else {
            throw ConfigError.DownloadFail
        }
        try setup(string: string)
    }
    
    public func save() throws {
        do {
            try realm.commitWrite()
        }catch {
            throw error
        }
    }
    
    func setupModels() throws {
        realm.beginWrite()
        do {
            try setupProxies()
            try setupRuleSets()
            try setupConfigGroups()
        }catch {
            realm.cancelWrite()
            throw error
        }
    }
    
    func setupProxies() throws {
        if let proxiesConfig = configDict["proxies"] as? [[String: AnyObject]] {
            proxies = try proxiesConfig.map({ (config) -> Proxy? in
                return try Proxy(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try proxies.forEach {
                try $0.validate(inRealm: realm)
                realm.add($0)
            }
        }
    }
    
    func setupRuleSets() throws{
        if let proxiesConfig = configDict["ruleSets"] as? [[String: AnyObject]] {
            ruleSets = try proxiesConfig.map({ (config) -> RuleSet? in
                return try RuleSet(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try ruleSets.forEach {
                try $0.validate(inRealm: realm)
                realm.add($0)
            }
        }
    }
    
    func setupConfigGroups() throws{
        if let proxiesConfig = configDict["configGroups"] as? [[String: AnyObject]] {
            groups = try proxiesConfig.map({ (config) -> ConfigurationGroup? in
                return try ConfigurationGroup(dictionary: config, inRealm: realm)
            }).filter { $0 != nil }.map { $0! }
            try groups.forEach {
                try $0.validate(inRealm: realm)
                realm.add($0)
            }
        }
    }

}