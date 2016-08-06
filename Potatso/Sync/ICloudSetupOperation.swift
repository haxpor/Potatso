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

class ICloudSetupOperation: BlockOperation {

    init(completion: (ErrorType? -> Void)? = nil) {
        super.init(block: nil)
        let url = NSURL(string: "http://www.apple.com")!
        let reachabilityCondition = ReachabilityCondition(host: url)

        let container = CKContainer.defaultContainer()
        let iCloudCapability = Capability(iCloudContainer(container: container))

        let finishObserver = BlockObserver { operation, error in
            print("ICloudSetupOperation finished! \(error)")
            completion?(error.first)
        }

        addCondition(reachabilityCondition)
        addCondition(iCloudCapability)

        addObserver(finishObserver)
    }

}