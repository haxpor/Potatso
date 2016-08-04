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

    public static let shared = SyncManager()

    private var services: [SyncServiceType: SyncServiceProtocol] = [:]
    private static let serviceTypeKey = "serviceTypeKey"

    public var currentSyncServiceType: SyncServiceType {
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
        }
    }

    public var selectedSyncServiceType: SyncServiceType = .None

    init() {
        selectedSyncServiceType = currentSyncServiceType
    }

    public func getSelectedSyncService() -> SyncServiceProtocol? {
        let type = selectedSyncServiceType
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

}

extension SyncManager {

    public func setup(completion: (ErrorType? -> Void)?) {
        getSelectedSyncService()?.setup(completion)
    }

    public func sync() {
        getSelectedSyncService()?.sync()
    }
    
}