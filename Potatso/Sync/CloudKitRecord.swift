//
//  CloudKitRecord.swift
//  Potatso
//
//  Created by LEI on 8/3/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import CloudKit
import Realm
import RealmSwift

let potatsoZoneId = CKRecordZoneID(zoneName: "PotatsoCloud", ownerName: CKOwnerDefaultName)

public protocol CloudKitRecord {
    static var recordType: String { get }
    static var keys: [String] { get }
    var recordId: CKRecordID { get }
    func toCloudKitRecord() -> CKRecord
    static func fromCloudKitRecord(record: CKRecord) -> BaseModel
}

extension BaseModel {

    public static var basekeys: [String] {
        return ["uuid", "createAt", "updatedAt", "deleted"]
    }

}

extension Proxy: CloudKitRecord {

    public static var recordType: String {
        return "Proxy"
    }

    public static var keys: [String] {
        return basekeys + ["typeRaw", "name", "host", "port", "authscheme", "user", "password", "ota", "ssrProtocol", "ssrObfs", "ssrObfsParam"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Proxy.recordType, recordID: recordId)
        for key in Proxy.keys {
            record.setValue(self.valueForKey(key), forKey: key)
        }
        return record
    }

    public static func fromCloudKitRecord(record: CKRecord) -> BaseModel {
        let proxy = Proxy()
        for key in Proxy.keys {
            if let v = record.valueForKey(key) {
                proxy.setValue(v, forKey: key)
            }
        }
        return proxy
    }
}

extension Rule: CloudKitRecord {

    public static var recordType: String {
        return "Rule"
    }

    public static var keys: [String] {
        return basekeys + ["typeRaw", "content", "order"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: Rule.recordType, recordID: recordId)
        for key in Rule.keys {
            record.setValue(self.valueForKey(key), forKey: key)
        }
        return record
    }

    public static func fromCloudKitRecord(record: CKRecord) -> BaseModel {
        let rule = Rule()
        for key in Rule.keys {
            if let v = record.valueForKey(key) {
                rule.setValue(v, forKey: key)
            }
        }
        return rule
    }
}

extension RuleSet: CloudKitRecord {

    public static var recordType: String {
        return "RuleSet"
    }

    public static var keys: [String] {
        return basekeys + ["editable", "name", "updateAt", "desc", "ruleCount", "isSubscribe", "isOfficial"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: RuleSet.recordType, recordID: recordId)
        for key in RuleSet.keys {
            record.setValue(self.valueForKey(key), forKey: key)
        }
        record["rules"] = rules.map({ $0.uuid }).joinWithSeparator(",")
        return record
    }

    public static func fromCloudKitRecord(record: CKRecord) -> BaseModel {
        let ruleset = RuleSet()
        for key in RuleSet.keys {
            if let v = record.valueForKey(key) {
                ruleset.setValue(v, forKey: key)
            }
        }
        if let rulesUUIDs = record["rules"] as? String {
            let realm = try! Realm()
            let uuids = rulesUUIDs.componentsSeparatedByString(",")
            let rules = uuids.flatMap({ realm.objects(Rule).filter("uuid = '\($0)'").first })
            ruleset.rules.appendContentsOf(rules)
        }
        return ruleset
    }
}

extension ConfigurationGroup: CloudKitRecord {

    public static var recordType: String {
        return "ConfigurationGroup"
    }

    public static var keys: [String] {
        return basekeys + ["editable", "name", "defaultToProxy"]
    }

    public var recordId: CKRecordID {
        return CKRecordID(recordName: uuid, zoneID: potatsoZoneId)
    }

    public func toCloudKitRecord() -> CKRecord {
        let record = CKRecord(recordType: ConfigurationGroup.recordType, recordID: recordId)
        for key in ConfigurationGroup.keys {
            record.setValue(self.valueForKey(key), forKey: key)
        }
        record["proxies"] = proxies.map({ $0.uuid }).joinWithSeparator(",")
        record["ruleSets"] = ruleSets.map({ $0.uuid }).joinWithSeparator(",")
        return record
    }

    public static func fromCloudKitRecord(record: CKRecord) -> BaseModel {
        let group = ConfigurationGroup()
        for key in ConfigurationGroup.keys {
            if let v = record.valueForKey(key) {
                group.setValue(v, forKey: key)
            }
        }
        let realm = try! Realm()
        if let rulesUUIDs = record["proxies"] as? String {
            let uuids = rulesUUIDs.componentsSeparatedByString(",")
            let rules = uuids.flatMap({ realm.objects(Proxy).filter("uuid = '\($0)'").first })
            group.proxies.appendContentsOf(rules)
        }
        if let rulesUUIDs = record["ruleSets"] as? String {
            let uuids = rulesUUIDs.componentsSeparatedByString(",")
            let rules = uuids.flatMap({ realm.objects(RuleSet).filter("uuid = '\($0)'").first })
            group.ruleSets.appendContentsOf(rules)
        }
        return group
    }
}


func changeLocalRecord(record: CKRecord, objectClass: CloudKitRecord.Type) throws {
    let realm = try! Realm()
    let realmObject: BaseModel
    let local: BaseModel?
    switch record.recordType {
    case "Proxy":
        realmObject = Proxy.fromCloudKitRecord(record)
        realmObject.synced = true
        local = realm.objects(Proxy).filter("uuid = '\(realmObject.uuid)'").first
    default:
        return
    }
    if let local = local {
        if local.updatedAt > realmObject.updatedAt {
            try DBUtils.mark(local, synced: false)
            return
        } else if local.updatedAt == realmObject.updatedAt {
            try DBUtils.mark(local, synced: true)
            return
        }
    }
    try DBUtils.add(realmObject)
}

func deleteLocalRecord(recordID: CKRecordID, objectClass: CloudKitRecord.Type) throws {
    let realm = try! Realm()
    let id = recordID.recordName
    // FIXME: Unsafe realm casting
    if let object = realm.objectForPrimaryKey(objectClass as! BaseModel.Type, key: id) {
        print("Deleting local record.")
        try DBUtils.delete(object)
    }
}

