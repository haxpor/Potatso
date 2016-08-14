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
        DDLogInfo("Setuping iCloud sync service")
        let setupOp = ICloudSetupOperation(completion: completion)
        let subscribeOp = BlockOperation { [weak self] in
            self?.subscribeNotification()
        }
        subscribeOp.addDependency(setupOp)
        operationQueue.addOperation(setupOp)
        operationQueue.addOperation(subscribeOp)
    }

    func sync(manually: Bool = false) {
        print("====== iCloud sync start")
        if manually {
            DDLogInfo("manually sync: clear zone token and mark all as not synced")
            setZoneChangeToken(potatsoZoneId, changeToken: nil)
            _ = try? DBUtils.markAll(syncd: false)
        }
        let setupOp = ICloudSetupOperation(completion: nil)
        let subscribeOp = BlockOperation { [weak self] in
            self?.subscribeNotification()
        }
        let syncOp = SyncOperation(zoneID: potatsoZoneId, syncType: SyncType.FetchCloudChangesAndThenPushLocalChanges) {
            print("====== iCloud sync completed")
        }

        subscribeOp.addDependency(setupOp)
        operationQueue.addOperation(subscribeOp)
        operationQueue.addOperation(setupOp)
        operationQueue.addOperation(syncOp)
    }

    func subscribeNotification() {
        DDLogInfo("subscribing cloudkit database changes...")
        let subscription = CKSubscription(zoneID: potatsoZoneId, subscriptionID: potatsoSubscriptionId, options: CKSubscriptionOptions(rawValue: 0))
        let info = CKNotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        potatsoDB.saveSubscription(subscription) { (sub, error) in
            if let error = error {
                DDLogError("subscribe cloudkit database changes error: \(error.localizedDescription)")
            } else {
                DDLogInfo("subscribe cloudkit database changes success")
            }
        }
    }

    func unsubscribeNotification() {
        DDLogInfo("unsubscribing cloudkit database changes...")
        potatsoDB.deleteSubscriptionWithID(potatsoSubscriptionId) { (id, error) in
            if let error = error {
                DDLogError("unsubscribe cloudkit database changes error: \(error.localizedDescription)")
            } else {
                DDLogInfo("unsubscribe cloudkit database changes success")
            }
        }
    }

    func stop() {
        unsubscribeNotification()
    }

}
