import Foundation
import RealmSwift
import CloudKit
import PSOperations

class PushLocalChangesOperation: Operation {
    
    let zoneID: CKRecordZoneID
    var recordsToSave: [CKRecord]?
    var recordIDsToDelete: [CKRecordID]?

    let delayOperationQueue = OperationQueue()
    let maximumRetryAttempts: Int
    var retryAttempts: Int = 0

    init(zoneID: CKRecordZoneID, maximumRetryAttempts: Int = 3) {
        self.zoneID = zoneID
        self.maximumRetryAttempts = maximumRetryAttempts
        
        super.init()
        name = "Push Local Changes"
    }
    
    override func execute() {
        print(">>>>>>>>> \(self.name!) started")
        
        // FIXME: Unsafe realm casting
        let toSyncObjects = DBUtils.allObjectsToSyncModified()
        let toDeleteObjects = DBUtils.allObjectsToSyncDeleted()
        print("toSyncObjects: \(toSyncObjects.map({ $0.uuid }).joinWithSeparator(", "))")
        print("toDeleteObjects: \(toDeleteObjects.map({ $0.uuid }).joinWithSeparator(", "))")

        self.recordsToSave = toSyncObjects.map {
            ($0 as! CloudKitRecord).toCloudKitRecord()
        }
        self.recordIDsToDelete = toDeleteObjects.map {
            ($0 as! CloudKitRecord).recordId
        }

        modifyRecords(self.recordsToSave, recordIDsToDelete: self.recordIDsToDelete) {
            (nsError) in
            self.finishWithError(nsError)
        }
    }
    
    func modifyRecords(recordsToSave: [CKRecord]?,
                       recordIDsToDelete: [CKRecordID]?,
                       completionHandler: (NSError!) -> ()) {
        
        let modifyOperation = CKModifyRecordsOperation(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete)
        modifyOperation.savePolicy = .ChangedKeys
        modifyOperation.modifyRecordsCompletionBlock = {
            (savedRecords, deletedRecordIDs, nsError) -> Void in
            if let error = nsError {
                print("modifyRecords error: \(error), \(savedRecords?.count), \(recordIDsToDelete?.count)")
                self.handleCloudKitPushError(
                    savedRecords,
                    deletedRecordIDs: deletedRecordIDs,
                    error: error,
                    completionHandler: completionHandler)
                
            } else {
                do {
                    // Update local modified flag
                    if let savedRecords = savedRecords {
                        print("savedRecords: \(savedRecords.map({ $0.recordID.recordName }).joinWithSeparator(", "))")
                        for record in savedRecords {
                            // FIXME: Unsafe realm casting
                            try DBUtils.mark(record.recordID.recordName, type: record.realmClassType!, synced: true)
                        }
                    }
                    
                    if let recordIDsToDelete = recordIDsToDelete {
                        print("recordIDsToDelete: \(recordIDsToDelete.map({ $0.recordName }).joinWithSeparator(", "))")
                        for recordID in recordIDsToDelete {
                            try deleteLocalRecord(recordID)
                        }
                    }
                    
                } catch let realmError as NSError {
                    self.finishWithError(realmError)
                }
                
                completionHandler(nsError)
            }
        }
        
        modifyOperation.start()
    }
    
    // MARK: - Error Handling
    
    /**
     Implement custom logic here for handling CloudKit push errors.
     */
    func handleCloudKitPushError(
        savedRecords: [CKRecord]?,
        deletedRecordIDs: [CKRecordID]?,
        error: NSError,
        completionHandler: (NSError!) -> ()) {
        
        let ckErrorCode: CKErrorCode = CKErrorCode(rawValue: error.code)!
        
        switch ckErrorCode {
            
        case .PartialFailure:
            self.resolvePushConflictsAndRetry(
                savedRecords,
                deletedRecordIDs: deletedRecordIDs,
                error: error,
                completionHandler: completionHandler)
            
        case .LimitExceeded:
            self.splitModifyOperation(error, completionHandler: completionHandler)
            
        case .ZoneBusy, .RequestRateLimited, .ServiceUnavailable, .NetworkFailure, .NetworkUnavailable, .ResultsTruncated:
            // Retry necessary
            retryPush(error,
                      retryAfter: parseRetryTime(error),
                      completionHandler: completionHandler)
            
        case .BadDatabase, .InternalError, .BadContainer, .MissingEntitlement,
             .ConstraintViolation, .IncompatibleVersion, .AssetFileNotFound,
             .AssetFileModified, .InvalidArguments, .UnknownItem,
             .PermissionFailure, .ServerRejectedRequest:
            // Developer issue
            completionHandler(error)
            
        case .QuotaExceeded, .OperationCancelled:
            // User issue. Provide alert.
            completionHandler(error)
            
        case .BatchRequestFailed, .ServerRecordChanged:
            // Not possible for push operation (I think) only possible for
            // individual records within the userInfo dictionary of a PartialFailure
            completionHandler(error)
            
        case .NotAuthenticated:
            // Handled as condition of SyncOperation
            // TODO: add logic to retry entire operation
            completionHandler(error)
            
        case .ZoneNotFound, .UserDeletedZone:
            // Handled in PrepareZoneOperation.
            // TODO: add logic to retry entire operation
            completionHandler(error)
            
        case .ChangeTokenExpired:
            // TODO: Determine correct handling
            SyncManager.shared.sync(true)
        }
    }
    
    /**
     In the case of a .LimitExceeded error split the CKModifyOperation in half. For simplicity,
     also split the save and delete operations.
     */
    func splitModifyOperation(error: NSError, completionHandler: (NSError!) -> ()) {
        
        if let recordsToSave = self.recordsToSave {
            
            if recordsToSave.count > 0 {
                print("Receiving CKErrorLimitExceeded with <= 1 records.")
                
                let recordsToSaveLeft = Array(recordsToSave.prefixUpTo(recordsToSave.count/2))
                let recordsToSaveRight = Array(recordsToSave.suffixFrom(recordsToSave.count/2))
                
                self.modifyRecords(recordsToSaveLeft,
                                   recordIDsToDelete: nil,
                                   completionHandler: completionHandler)
                
                self.modifyRecords(recordsToSaveRight,
                                   recordIDsToDelete: nil,
                                   completionHandler: completionHandler)
            }
        }
        
        if let recordIDsToDelete = self.recordIDsToDelete {
            
            if recordIDsToDelete.count > 0 {
                
                let recordIDsToDeleteLeft = Array(recordIDsToDelete.prefixUpTo(recordIDsToDelete.count/2))
                let recordIDsToDeleteRight = Array(recordIDsToDelete.suffixFrom(recordIDsToDelete.count/2))
                
                self.modifyRecords(nil,
                                   recordIDsToDelete: recordIDsToDeleteLeft,
                                   completionHandler: completionHandler)
                
                self.modifyRecords(nil,
                                   recordIDsToDelete: recordIDsToDeleteRight,
                                   completionHandler: completionHandler)
            }
        }
    }
    
    func resolvePushConflictsAndRetry(savedRecords: [CKRecord]?,
                                      deletedRecordIDs: [CKRecordID]?,
                                      error: NSError,
                                      completionHandler: (NSError!) -> ()) {
        
        let adjustedRecords = resolveConflicts(error,
                                               completionHandler: completionHandler,
                                               resolver: overwriteFromClient)
        
        modifyRecords(adjustedRecords, recordIDsToDelete: deletedRecordIDs, completionHandler: completionHandler)
    }
    
    // MARK: - Retry
    
    // Wait a default of 3 seconds
    func parseRetryTime(error: NSError) -> Double {
        var retrySecondsDouble: Double = 3
        if let retrySecondsString = error.userInfo[CKErrorRetryAfterKey] as? String {
            retrySecondsDouble = Double(retrySecondsString)!
        }
        return retrySecondsDouble
    }
    
    /**
     After `maximumRetryAttempts` this function will return an error.
     */
    func retryPush(error: NSError, retryAfter: Double, completionHandler: (NSError!) -> ()) {
        
        if self.retryAttempts < self.maximumRetryAttempts {
            self.retryAttempts += 1
            
            let delayOperation = DelayOperation(interval: retryAfter)
            let finishObserver = BlockObserver { operation, error in
                self.modifyRecords(self.recordsToSave,
                    recordIDsToDelete: self.recordIDsToDelete,
                    completionHandler: completionHandler)
            }
            delayOperation.addObserver(finishObserver)
            delayOperationQueue.addOperation(delayOperation)
            
        } else {
            completionHandler(error)
        }
    }
}