//
//  SyncManager.swift
//  Potatso
//
//  Created by LEI on 8/2/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import CloudKit

public enum SyncServiceType: String {
    case None
    case iCloud
}

public protocol SyncServiceProtocol {
    func setup(completion: (ErrorType? -> Void)?)
    func sync()
}

public class SyncManager {

    static let shared = SyncManager()

    public static let syncServiceChangedNotification = "syncServiceChangedNotification"
    private var services: [SyncServiceType: SyncServiceProtocol] = [:]
    private static let serviceTypeKey = "serviceTypeKey"

    var currentSyncServiceType: SyncServiceType {
        get {
            if let raw = NSUserDefaults.standardUserDefaults().objectForKey(SyncManager.serviceTypeKey) as? String, type = SyncServiceType(rawValue: raw) {
                return type
            }
            return .None
        }
        set(new) {
            guard currentSyncServiceType != new else {
                return
            }
            NSUserDefaults.standardUserDefaults().setObject(new.rawValue, forKey: SyncManager.serviceTypeKey)
            NSUserDefaults.standardUserDefaults().synchronize()
            NSNotificationCenter.defaultCenter().postNotificationName(SyncManager.syncServiceChangedNotification, object: nil)
        }
    }

    init() {
    }

    func getCurrentSyncService() -> SyncServiceProtocol? {
        return getSyncService(forType: currentSyncServiceType)
    }

    func getSyncService(forType type: SyncServiceType) -> SyncServiceProtocol? {
        if let service = services[type] {
            return service
        }
        let s: SyncServiceProtocol
        switch type {
        case .iCloud:
            s = ICloudSyncService()
        default:
            return nil
        }
        services[type] = s
        return s
    }

    func showSyncVC(inVC vc:UIViewController? = nil) {
        guard let currentVC = vc ?? UIApplication.sharedApplication().keyWindow?.rootViewController else {
            return
        }
        let syncVC = SyncVC()
        currentVC.showViewController(syncVC, sender: self)
    }

}

extension SyncManager {

    func setupNewService(type: SyncServiceType, completion: (ErrorType? -> Void)?) {
        getSyncService(forType: type)?.setup(completion)
    }

    func setup(completion: (ErrorType? -> Void)?) {
        getCurrentSyncService()?.setup(completion)
    }

    func sync() {
        getCurrentSyncService()?.sync()
    }
    
}