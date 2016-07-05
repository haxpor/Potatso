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

class DataInitializer: NSObject, AppLifeCycleProtocol {
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        do {
            try Manager.sharedManager.setup()
        }catch {
            error.log("Fail to setup manager")
        }
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
    }

    func applicationDidBecomeActive(application: UIApplication) {
        deleteOrphanRules()
        let uuids = defaultRealm.objects(RuleSet).filter("isSubscribe = true").map({$0.uuid})
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

    func deleteOrphanRules() {
        let orphanRules = defaultRealm.objects(Rule).filter("rulesets.@count == 0")
        _ = try? defaultRealm.write({
            defaultRealm.delete(orphanRules)
        })
    }

}
