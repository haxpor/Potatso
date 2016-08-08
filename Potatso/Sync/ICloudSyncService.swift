//
//  ICloudSyncService.swift
//  Potatso
//
//  Created by LEI on 8/2/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit
import PSOperations
import PotatsoModel

class ICloudSyncService: SyncServiceProtocol {

    let operationQueue = OperationQueue()

    init() {

    }

    func setup(completion: (ErrorType? -> Void)?) {
        let setupOp = ICloudSetupOperation(completion: completion)
        operationQueue.addOperation(setupOp)
        subscribe()
    }

    func sync(manually: Bool = false) {
        if manually {
            setZoneChangeToken(potatsoZoneId, changeToken: nil)
            _ = try? DBUtils.markAll(false)
        }
        let setupOp = ICloudSetupOperation(completion: nil)

        let proxySyncOp = SyncOperation(zoneID: potatsoZoneId, objectClass: Proxy.self, syncType: SyncType.FetchCloudChangesAndThenPushLocalChanges) {
            print("<<<<<<<<< sync proxies completed")
        }
        let ruleSyncOp = SyncOperation(zoneID: potatsoZoneId, objectClass: Rule.self, syncType: SyncType.FetchCloudChangesAndThenPushLocalChanges) {
            print("<<<<<<<<< sync rules completed")
        }
        ruleSyncOp.addDependency(proxySyncOp)
        let ruleSetSyncOp = SyncOperation(zoneID: potatsoZoneId, objectClass: RuleSet.self, syncType: SyncType.FetchCloudChangesAndThenPushLocalChanges) {
            print("<<<<<<<<< sync rulesets completed")
        }
        ruleSetSyncOp.addDependency(ruleSyncOp)
        let configGroupSyncOp = SyncOperation(zoneID: potatsoZoneId, objectClass: ConfigurationGroup.self, syncType: SyncType.FetchCloudChangesAndThenPushLocalChanges) {
            print("<<<<<<<<< sync config groups completed")
        }
        configGroupSyncOp.addDependency(ruleSetSyncOp)

        operationQueue.addOperation(setupOp)
        operationQueue.addOperation(proxySyncOp)
        operationQueue.addOperation(ruleSyncOp)
        operationQueue.addOperation(ruleSetSyncOp)
        operationQueue.addOperation(configGroupSyncOp)
    }

    func subscribe() {
        let subscription = CKSubscription(zoneID: potatsoZoneId, subscriptionID: potatsoSubscriptionId, options: CKSubscriptionOptions(rawValue: 0))
        let info = CKNotificationInfo()
        info.alertBody = "Potatso iCloud updated"
        subscription.notificationInfo = info
        
        potatsoDB.saveSubscription(subscription) { (sub, error) in
            if let error = error {
                DDLogError("save cloudkit subscription error: \(error.localizedDescription)")
            } else {
                DDLogInfo("save cloudkit subscription success")
            }
        }
    }

    func stop() {
        potatsoDB.deleteSubscriptionWithID(potatsoSubscriptionId) { (id, error) in
            if let error = error {
                DDLogError("delete cloudkit subscription error: \(error.localizedDescription)")
            } else {
                DDLogInfo("delete cloudkit subscription success")
            }
        }
    }

}
