//
//  DBInitializer.swift
//  Potatso
//
//  Created by LEI on 3/8/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import UIKit
import ICSMainFramework
import NetworkExtension
import CloudKit
import Async
import RealmSwift
import Realm

class DataInitializer: NSObject, AppLifeCycleProtocol {

    let s = ICloudSyncService()
    var token: RLMNotificationToken? = nil
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        do {
            try Manager.sharedManager.setup()
        }catch {
            error.log("Fail to setup manager")
        }
        updateCloudSets()
        sync()
//        token = defaultRealm.addNotificationBlock({ [weak self] (notification, realm) in
//            self?.sync()
//        })
        return true
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        _ = try? Manager.sharedManager.regenerateConfigFiles()
    }

    func applicationWillTerminate(application: UIApplication) {
        _ = try? Manager.sharedManager.regenerateConfigFiles()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        Receipt.shared.validate()
        sync()
    }

    func updateCloudSets() {
        let uuids = defaultRealm.objects(RuleSet).filter("isSubscribe = true").map({$0.uuid})
        Async.background(after: 1.5) {
            API.updateRuleSetListDetail(uuids) { (response) in
                if let sets = response.result.value {
                    do {
                        try RuleSet.addRemoteArray(sets)
                    }catch {
                        error.log("Unable to save updated rulesets")
                        return
                    }
                }else {
                    response.result.error?.log("Fail to update ruleset details")
                }
            }
        }
    }

    func sync() {
        cleanupData()
        SyncManager.shared.sync()
    }

    func cleanupData() {
        deleteOrphanRules()
    }

    func deleteOrphanRules() {
        let orphanRules = defaultRealm.objects(Rule).filter("rulesets.@count == 0")
        if orphanRules.count > 0 {
            let ids = orphanRules.map({ $0.uuid })
            for id in ids {
                _ = try? DBUtils.softDelete(id, type: Rule.self)
            }
        }
    }

}
