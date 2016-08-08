import Foundation
import RealmSwift
import CloudKit
import PSOperations

class PushLocalChangesOperation<T: BaseModel where T: CloudKitRecord>: Operation {
    
    let zoneID: CKRecordZoneID
    var recordsToSave: [CKRecord]?
    var recordIDsToDelete: [CKRecordID]?

    let delayOperationQueue = OperationQueue()
    let maximumRetryAttempts: Int
    var retryAttempts: Int = 0
    
    let objectClass: T.Type
    
    init(zoneID: CKRecordZoneID, objectClass: T.Type, maximumRetryAttempts: Int = 3) {
        self.zoneID = zoneID
        self.objectClass = objectClass
        self.maximumRetryAttempts = maximumRetryAttempts
        
        super.init()
        name = "Push Local Changes of \(objectClass)"
    }
    
    override func execute() {
        print(">>>>>>>>> \(self.name!) started")
        
        // Query records
        let realm = try! Realm()
        
        // FIXME: Unsafe realm casting
        let toSyncObjects = realm.objects(self.objectClass)
            .filter("synced == false && deleted == false")
        let toDeleteObjects = realm.objects(self.objectClass)
            .filter("synced == false && deleted == true")
        print("toSyncObjects: \(toSyncObjects.map({ $0.uuid }).joinWithSeparator(", "))")
        print("toDeleteObjects: \(toDeleteObjects.map({ $0.uuid }).joinWithSeparator(", "))")

        self.recordsToSave = toSyncObjects.map {
            $0.toCloudKitRecord()
        }
        self.recordIDsToDelete = toDeleteObjects.map {
            $0.recordId
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
                            try DBUtils.mark(record.recordID.recordName, type: self.objectClass, synced: true)
                        }
                    }
                    
                    if let recordIDsToDelete = recordIDsToDelete {
                        print("recordIDsToDelete: \(recordIDsToDelete.map({ $0.recordName }).joinWithSeparator(", "))")
                        for recordID in recordIDsToDelete {
                            try deleteLocalRecord(recordID, objectClass: self.objectClass)
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
            completionHandler(error)
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