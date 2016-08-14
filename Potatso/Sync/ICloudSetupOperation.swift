//
//  ICloudSetupOperation.swift
//  Potatso
//
//  Created by LEI on 8/5/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PSOperations
import CloudKit
import Async

class ICloudSetupOperation: GroupOperation {

    init(completion: (ErrorType? -> Void)? = nil) {
        let url = NSURL(string: "http://www.apple.com")!
        let reachabilityCondition = ReachabilityCondition(host: url)

        let container = CKContainer.defaultContainer()
        let iCloudCapability = Capability(iCloudContainer(container: container))

        let dummyOp = BlockOperation(block: nil)

        let finishObserver = BlockObserver { operation, error in
            if let _ = error.first {
                DDLogError("ICloudSetupOperation finished with error: \(error)")
            } else {
                DDLogInfo("ICloudSetupOperation finished")
            }
            Async.main {
                completion?(error.first)
            }
        }

        let prepareZoneOperation = PrepareZoneOperation(zoneID: potatsoZoneId)
        prepareZoneOperation.addCondition(reachabilityCondition)
        prepareZoneOperation.addCondition(iCloudCapability)
        prepareZoneOperation.addObserver(finishObserver)

        dummyOp.addDependency(prepareZoneOperation)

        super.init(operations: [prepareZoneOperation, dummyOp])
    }

}