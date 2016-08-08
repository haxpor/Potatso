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
        guard let object: T = DBUtils.get(id, inRealm: mRealm) else {
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
        guard let object: T = DBUtils.get(id, inRealm: mRealm) else {
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
        guard let object: T = DBUtils.get(id, inRealm: mRealm) else {
            return
        }
        mRealm.beginWrite()
        object.synced = synced
        try mRealm.commitWrite()
    }

    public static func markAll(syncd: Bool) throws {
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

    public static func get<T: BaseModel>(uuid: String, inRealm realm: Realm? = nil) -> T? {
        let mRealm = currentRealm(realm)
        return mRealm.objects(T).filter("uuid = '\(uuid)'").first
    }

    public static func modify<T: BaseModel>(type: T.Type, id: String, inRealm realm: Realm? = nil, modifyBlock: ((Realm, T) -> ErrorType?)) throws {
        let mRealm = currentRealm(realm)
        guard let object: T = DBUtils.get(id, inRealm: mRealm) else {
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
            if let proxyId = proxyId, proxy: Proxy = DBUtils.get(proxyId, inRealm: realm){
                group.proxies.append(proxy)
            }
            return nil
        }
    }

    public static func appendRuleSet(forGroupId groupId: String, rulesetId: String) throws {
        try DBUtils.modify(ConfigurationGroup.self, id: groupId) { (realm, group) -> ErrorType? in
            if let ruleset: RuleSet = DBUtils.get(rulesetId, inRealm: realm) {
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
