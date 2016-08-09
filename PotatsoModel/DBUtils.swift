//
//  DBUtils.swift
//  Potatso
//
//  Created by LEI on 8/3/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

public class DBUtils {

    private static func currentRealm(realm: Realm?) -> Realm {
        var mRealm = realm
        if mRealm == nil {
            mRealm = try! Realm()
        }
        return mRealm!
    }

    public static func add(object: BaseModel, update: Bool = true, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        mRealm.beginWrite()
        object.setModified()
        mRealm.add(object, update: update)
        try mRealm.commitWrite()
    }

    public static func add<S: SequenceType where S.Generator.Element: BaseModel>(objects: S, update: Bool = true, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        mRealm.beginWrite()
        objects.forEach({
            $0.setModified()
        })
        mRealm.add(objects, update: update)
        try mRealm.commitWrite()
    }

    public static func softDelete<T: BaseModel>(id: String, type: T.Type, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        object.deleted = true
        object.setModified()
        try mRealm.commitWrite()
    }

    public static func softDelete<T: BaseModel>(ids: [String], type: T.Type, inRealm realm: Realm? = nil) throws {
        for id in ids {
            try softDelete(id, type: type, inRealm: realm)
        }
    }

    public static func hardDelete<T: BaseModel>(id: String, type: T.Type, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        print(type)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        mRealm.delete(object)
        try mRealm.commitWrite()
    }

    public static func hardDelete<T: BaseModel>(ids: [String], type: T.Type, inRealm realm: Realm? = nil) throws {
        for id in ids {
            try hardDelete(id, type: type, inRealm: realm)
        }
    }

    public static func mark<T: BaseModel>(id: String, type: T.Type, synced: Bool, inRealm realm: Realm? = nil) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        object.synced = synced
        try mRealm.commitWrite()
    }

    public static func markAll(syncd syncd: Bool) throws {
        let mRealm = try! Realm()
        mRealm.beginWrite()
        for proxy in mRealm.objects(Proxy) {
            proxy.synced = false
        }
        for rule in mRealm.objects(Rule) {
            rule.synced = false
        }
        for ruleset in mRealm.objects(RuleSet) {
            ruleset.synced = false
        }
        for group in mRealm.objects(ConfigurationGroup) {
            group.synced = false
        }
        try mRealm.commitWrite()
    }
}


// Query
extension DBUtils {

    public static func get<T: BaseModel>(uuid: String, type: T.Type, inRealm realm: Realm? = nil) -> T? {
        let mRealm = currentRealm(realm)
        return mRealm.objects(type).filter("uuid = '\(uuid)'").first
    }

    public static func modify<T: BaseModel>(type: T.Type, id: String, inRealm realm: Realm? = nil, modifyBlock: ((Realm, T) -> ErrorType?)) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, type: type, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        if let error = modifyBlock(mRealm, object) {
            throw error
        }
        do {
            try object.validate(inRealm: mRealm)
        }catch {
            mRealm.cancelWrite()
            throw error
        }
        object.setModified()
        try mRealm.commitWrite()
    }

}

// Sync
extension DBUtils {

    public static func allObjectsToSyncModified() -> [BaseModel] {
        let mRealm = currentRealm(nil)
        let filter = "synced == false && deleted == false"
        let proxies = mRealm.objects(Proxy.self).filter(filter).map({ $0 })
        let rules = mRealm.objects(Rule.self).filter(filter).map({ $0 })
        let rulesets = mRealm.objects(RuleSet.self).filter(filter).map({ $0 })
        let groups = mRealm.objects(ConfigurationGroup.self).filter(filter).map({ $0 })
        var objects: [BaseModel] = []
        objects.appendContentsOf(proxies as [BaseModel])
        objects.appendContentsOf(rules as [BaseModel])
        objects.appendContentsOf(rulesets as [BaseModel])
        objects.appendContentsOf(groups as [BaseModel])
        return objects
    }

    public static func allObjectsToSyncDeleted() -> [BaseModel] {
        let mRealm = currentRealm(nil)
        let filter = "synced == false && deleted == true"
        let proxies = mRealm.objects(Proxy.self).filter(filter).map({ $0 })
        let rules = mRealm.objects(Rule.self).filter(filter).map({ $0 })
        let rulesets = mRealm.objects(RuleSet.self).filter(filter).map({ $0 })
        let groups = mRealm.objects(ConfigurationGroup.self).filter(filter).map({ $0 })
        var objects: [BaseModel] = []
        objects.appendContentsOf(proxies as [BaseModel])
        objects.appendContentsOf(rules as [BaseModel])
        objects.appendContentsOf(rulesets as [BaseModel])
        objects.appendContentsOf(groups as [BaseModel])
        return objects
    }
}

// BaseModel API
extension BaseModel {

    func setModified() {
        updatedAt = NSDate().timeIntervalSince1970
        synced = false
    }

}


// Config Group API
extension ConfigurationGroup {

    public static func changeProxy(forGroupId groupId: String, proxyId: String?) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> ErrorType? in
            group.proxies.removeAll()
            if let proxyId = proxyId, proxy = DBUtils.get(proxyId, type: Proxy.self, inRealm: realm){
                group.proxies.append(proxy)
            }
            return nil
        }
    }

    public static func appendRuleSet(forGroupId groupId: String, rulesetId: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> ErrorType? in
            if let ruleset = DBUtils.get(rulesetId, type: RuleSet.self, inRealm: realm) {
                group.ruleSets.append(ruleset)
            }
            return nil
        }
    }

    public static func changeDNS(forGroupId groupId: String, dns: String?) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> ErrorType? in
            group.dns = dns ?? ""
            return nil
        }
    }

    public static func changeName(forGroupId groupId: String, name: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> ErrorType? in
            group.name = name
            return nil
        }
    }

}

