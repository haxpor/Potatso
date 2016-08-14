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

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        Manager.sharedManager.setup()
        CloudSetManager.shared.update()
        sync()
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

    func sync() {
        deleteOrphanRules {
            SyncManager.shared.sync()
        }
    }


    func deleteOrphanRules(completion: (Void -> Void)?) {
        Async.background {
            let realm = try! Realm()
            let orphanRules = realm.objects(Rule).filter("rulesets.@count == 0 && deleted == false")
            if orphanRules.count > 0 {
                let ids = orphanRules.map({ $0.uuid })
                for id in ids {
                    _ = try? DBUtils.softDelete(id, type: Rule.self)
                }
            }
            completion?()
        }
    }

}
