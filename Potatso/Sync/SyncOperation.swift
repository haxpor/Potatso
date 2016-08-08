import Foundation
import RealmSwift
import CloudKit
import PSOperations

public enum SyncType: CustomStringConvertible {
    case PushLocalChanges
    case FetchCloudChanges
    case FetchCloudChangesAndThenPushLocalChanges
    
    public var description : String {
        switch self {
        case .PushLocalChanges:
            return "Push Local Changes"
        case .FetchCloudChanges:
            return "Fetch Cloud Changes"
        case .FetchCloudChangesAndThenPushLocalChanges:
            return "Fetch Cloud Changes And Then Push Local Changes"
        }
    }
}

/**
 Sync local realm database with CloudKit.
 
 Required Conditions:
 - Reachability
 - iCloud
 
 Order of Operations:
 - PrepareZoneOperation
 - PushLocalChangesOperation
 - FetchCloudChangesOperation
 - completionHandler
 
 */
public class SyncOperation<T: BaseModel where T: CloudKitRecord>: GroupOperation {
    
    private var hasProducedAlert = false
    
    public init(zoneID: CKRecordZoneID,
         objectClass: T.Type,
         syncType: SyncType,
         completionHandler: () -> Void) {

        let finishOperation = NSBlockOperation(block: completionHandler)

        // Setup operations relating to SyncType
        let pushLocalChangesOperation: PushLocalChangesOperation<T>
        let fetchCloudChangesOperation: FetchCloudChangesOperation<T>
        let operations: [NSOperation]
        
        switch syncType {
        case .PushLocalChanges:
            pushLocalChangesOperation = PushLocalChangesOperation(zoneID: zoneID,
                                                                  objectClass: objectClass)
            
            finishOperation.addDependency(pushLocalChangesOperation)
            
            operations = [
                pushLocalChangesOperation,
                finishOperation]
            
        case .FetchCloudChanges:
            fetchCloudChangesOperation = FetchCloudChangesOperation(zoneID: zoneID, objectClass: objectClass)
            
            finishOperation.addDependency(fetchCloudChangesOperation)
            
            operations = [
                fetchCloudChangesOperation,
                finishOperation]
            
        case .FetchCloudChangesAndThenPushLocalChanges:
            pushLocalChangesOperation = PushLocalChangesOperation(zoneID: zoneID, objectClass: objectClass)
            fetchCloudChangesOperation = FetchCloudChangesOperation(zoneID: zoneID, objectClass: objectClass)
            
            fetchCloudChangesOperation.addDependency(pushLocalChangesOperation)
            finishOperation.addDependency(fetchCloudChangesOperation)
            
            operations = [
                fetchCloudChangesOperation,
                pushLocalChangesOperation,
                finishOperation]
        }
        
        super.init(operations: operations)

        name = "Sync \(syncType)"
    }
    
    override public func finished(errors: [NSError]) {
        if self.cancelled {
            print("Sync operation was cancelled.")
        }
    }
    
    override public func operationDidFinish(operation: NSOperation, withErrors errors: [NSError]) {
        if let firstError = errors.first {
            produceAlert(firstError)
        } else {
            if let name = operation.name {
                print("  \(name) finished")
            }
        }
    }
    
    private func produceAlert(error: NSError) {
        /*
         We only want to show the first error, since subsequent errors might
         be caused by the first.
         */
        if hasProducedAlert { return }
        produceOperation(createAlertOperation(error))
        hasProducedAlert = true
    }
}
