//
//  SyncVC.swift
//  Potatso
//
//  Created by LEI on 8/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka

class SyncVC: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Sync".localized()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserverForName(SyncManager.syncServiceChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [unowned self] (noti) in
            self.generateForm()
        }
        generateForm()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func generateForm() {
        form.delegate = nil
        form.removeAll()
        form +++ generateServiceSection()
        form.delegate = self
        tableView?.reloadData()
    }

    func generateServiceSection() -> Section {
        let section = Section()
        section
            <<< PushRow<SyncServiceType>() {
                $0.title = "Sync Service".localized()
                $0.options = [.None, .iCloud]
                $0.value = SyncManager.shared.currentSyncServiceType
                $0.selectorTitle = "Choose Sync Service".localized()
            }.onChange({ [weak self] (row) in
                if let type = row.value {
                    SyncManager.shared.setupNewService(type, completion: { (error) in
                        if let error = error {
                            if let vc = self {
                                Alert.show(vc, title: "Setup Failed", message: "\((error as NSError).localizedDescription)")
                            }
                        } else {
                            SyncManager.shared.currentSyncServiceType = type
                        }
                    })
                }
            })
        section
            <<< ButtonRow {
                $0.title = "Sync Now"
                $0.hidden = Condition.Function([""]) { form in
                    return SyncManager.shared.currentSyncServiceType == .None
                }
            }.onCellSelection({ (cell, row) in
                SyncManager.shared.sync()
            })
        return section
    }
}