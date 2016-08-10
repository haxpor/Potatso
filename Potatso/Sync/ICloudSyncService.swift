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
        let subscribeOp = BlockOperation {
            self.subscribe()
        }
        subscribeOp.addDependency(setupOp)
        operationQueue.addOperation(setupOp)
        operationQueue.addOperation(subscribeOp)
    }

    func sync(manually: Bool = false) {
        if manually {
            setZoneChangeToken(potatsoZoneId, changeToken: nil)
            _ = try? DBUtils.markAll(syncd: false)
        }
        let setupOp = ICloudSetupOperation(completion: nil)
        let subscribeOp = BlockOperation {
            self.subscribe()
        }
        let syncOp = SyncOperation(zoneID: potatsoZoneId, syncType: SyncType.FetchCloudChangesAndThenPushLocalChanges) {
            print("<<<<<<<<< sync completed")
        }

        subscribeOp.addDependency(setupOp)
        operationQueue.addOperation(subscribeOp)
        operationQueue.addOperation(setupOp)
        operationQueue.addOperation(syncOp)
    }

    func subscribe() {
        let subscription = CKSubscription(zoneID: potatsoZoneId, subscriptionID: potatsoSubscriptionId, options: CKSubscriptionOptions(rawValue: 0))
        let info = CKNotificationInfo()
        info.shouldSendContentAvailable = true
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
