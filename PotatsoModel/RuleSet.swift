//
//  RuleSet.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift

public enum RuleSetError: ErrorType {
    case InvalidRuleSet
    case EmptyName
    case NameAlreadyExists
}

extension RuleSetError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .InvalidRuleSet:
            return "Invalid rule set"
        case .EmptyName:
            return "Empty name"
        case .NameAlreadyExists:
            return "Name already exists"
        }
    }
    
}

public final class RuleSet: BaseModel {
    public dynamic var editable = true
    public dynamic var name = ""
    public dynamic var updateAt = NSDate().timeIntervalSince1970
    public dynamic var desc = ""
    public dynamic var ruleCount = 0
    public let rules = List<Rule>()
    public dynamic var isSubscribe = false
    public dynamic var isOfficial = false

    public func validate(inRealm realm: Realm) throws {
        guard name.characters.count > 0 else {
            throw RuleSetError.EmptyName
        }
        guard realm.objects(RuleSet).filter("name = '\(name)'").first == nil else {
            throw RuleSetError.NameAlreadyExists
        }
    }
    
    
}

extension RuleSet {
    
    public override static func indexedProperties() -> [String] {
        return ["name"]
    }
    
}

extension RuleSet {
    
    public convenience init(dictionary: [String: AnyObject], inRealm realm: Realm) throws {
        self.init()
        guard let name = dictionary["name"] as? String else {
            throw RuleSetError.InvalidRuleSet
        }
        self.name = name
        if realm.objects(RuleSet).filter("name = '\(name)'").first != nil {
            self.name = "\(name) \(RuleSet.dateFormatter.stringFromDate(NSDate()))"
        }
        guard let rulesStr = dictionary["rules"] as? [String] else {
            throw RuleSetError.InvalidRuleSet
        }
        for ruleStr in rulesStr {
            self.rules.append(try Rule(str: ruleStr))
        }
    }
    
}

public func ==(lhs: RuleSet, rhs: RuleSet) -> Bool {
    return lhs.uuid == rhs.uuid
}