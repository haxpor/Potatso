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

    public static func add(object: BaseModel, update: Bool = true) throws {
        let realm = try! Realm()
        realm.beginWrite()
        object.setModified()
        realm.add(object, update: update)
        try realm.commitWrite()
    }

    public static func add<S: SequenceType where S.Generator.Element: BaseModel>(objects: S, update: Bool = true) throws {
        let realm = try! Realm()
        realm.beginWrite()
        objects.forEach({
            $0.setModified()
        })
        realm.add(objects, update: update)
        try realm.commitWrite()
    }

    public static func delete(object: BaseModel, update: Bool = true) throws {
        let realm = try! Realm()
        realm.beginWrite()
        object.deleted = true
        object.setModified()
        try realm.commitWrite()
    }

    public static func delete<S: SequenceType where S.Generator.Element: BaseModel>(objects: S, update: Bool = true) throws {
        let realm = try! Realm()
        realm.beginWrite()
        objects.forEach({
            $0.deleted = true
            $0.setModified()
        })
        try realm.commitWrite()
    }

    public static func mark(object: BaseModel, synced: Bool) throws {
        let realm = try! Realm()
        realm.beginWrite()
        object.synced = synced
        try realm.commitWrite()
    }

    public static func mark(type type: BaseModel.Type, objectId: String, synced: Bool) throws {
        let realm = try! Realm()
        guard let object = realm.objects(type).filter("uuid = '\(objectId)'").first else {
            return
        }
        try mark(object, synced: synced)
    }

}


// Query
extension DBUtils {

    public static func get<T: BaseModel>(uuid: String, inRealm realm: Realm? = nil) -> T? {
        var mRealm = realm
        if mRealm == nil {
            mRealm = try! Realm()
        }
        return mRealm?.objects(T).filter("uuid = '\(uuid)'").first
    }

    public static func modify<T: BaseModel>(type: T.Type, id: String, modifyBlock: ((Realm, T) -> ErrorType?)) throws {
        let realm = try! Realm()
        guard let object: T = DBUtils.get(id, inRealm: realm) else {
            return
        }
        realm.beginWrite()
        if let error = modifyBlock(realm, object) {
            throw error
        }
        do {
            try object.validate(inRealm: realm)
        }catch {
            realm.cancelWrite()
            throw error
        }
        try realm.commitWrite()
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
