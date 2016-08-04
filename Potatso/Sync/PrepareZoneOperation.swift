import Foundation
import CloudKit
import PSOperations

/**
 Ensure the record zone exists before attempting to write or fetch from it.
 */
class PrepareZoneOperation: Operation {
    
    let zoneID: CKRecordZoneID
    
    init(zoneID: CKRecordZoneID) {
        self.zoneID = zoneID
        super.init()
        name = "Prepare Zone Operation"
    }
    
    override func execute() {
        print("\(self.name!) started")
        prepareCKRecordZone(self.zoneID) { (nsError) in
            self.finishWithError(nsError)
        }
    }
    
    func prepareCKRecordZone(zoneID: CKRecordZoneID, completionHandler: (NSError!) -> ()) {
        let privateDB = CKContainer.defaultContainer().privateCloudDatabase
        // Per CloudKitCatalog, not using NSOperation here
        privateDB.fetchAllRecordZonesWithCompletionHandler {
            (zones, nsError) in
            if nsError != nil {
                print(nsError)
                completionHandler(nsError)
            } else if let zones = zones {
                var foundZone = false
                for zone in zones {
                    if zone.zoneID == zoneID {
                        foundZone = true
                    }
                }
                if foundZone {
                    print("Zone \(zoneID.zoneName) exists, nothing to do here.")
                    completionHandler(nsError)
                } else {
                    print("Zone \(zoneID.zoneName) does not exist. Creating it now.")
                    // TODO: check NSUserDefault boolean value for the zoneName.
                    // If it exists and we are here then the user must have deleted their
                    // cloud data. If so we need to recreate that zone and reupload
                    // all user data from that zone to the cloud. To do so mark all
                    // live records as locally modified. Deleted records which have also
                    // been deleted locally will be gone forever.
                    privateDB.saveRecordZone(CKRecordZone(zoneID: zoneID)) {
                        (recordZone, nsError) in
                        // TODO: set a boolean NSUserDefault value equal to the
                        // zoneName to keep track of zones this device has previously used
                        completionHandler(nsError)
                    }
                }
            }
        }
    }
}
