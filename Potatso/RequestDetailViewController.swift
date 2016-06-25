//
//  RequestDetailViewController.swift
//  Potatso
//
//  Created by LEI on 4/26/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

let kDetailRawTextCellIdentifier = "rawText"

protocol RequestDetailCell {
    func config(request: Request, event: RequestEvent)
}

extension RequestEventType {
    
    var cellIdentifier: String {
        switch self {
        case .Init:
            return kDetailRawTextCellIdentifier
        default:
            return kDetailRawTextCellIdentifier
        }
    }
}

class RequestDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    let request: Request
    let requestEvents: [RequestEvent]
    
    init(request: Request) {
        self.request = request
        self.requestEvents = request.events
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Request Detail".localized()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requestEvents.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let event = requestEvents[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier(event.type.cellIdentifier, forIndexPath: indexPath)
        if let c = cell as? RequestDetailCell {
            c.config(request, event: event)
        }
        cell.selectionStyle = .None
        return cell
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        view.addSubview(leftHintView)
        view.addSubview(tableView)
        tableView.registerClass(RequestDetailRawTextCell.self, forCellReuseIdentifier: kDetailRawTextCellIdentifier)
        setupLayout()
    }
    
    func setupLayout() {
        constrain(tableView, leftHintView, view) { tableView, leftHintView, view in
            tableView.edges == view.edges
            
            leftHintView.width == 4
            leftHintView.top == view.top
            leftHintView.bottom == view.bottom
            leftHintView.centerX == view.leading + 15
        }
        
    }
    
    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .None
        v.estimatedRowHeight = 110
        v.rowHeight = UITableViewAutomaticDimension
        v.backgroundColor = UIColor.clearColor()
        return v
    }()
    
    
    lazy var leftHintView: UIView = {
        let v = UIView()
        v.backgroundColor = "E8E8E8".color
        return v
    }()
    
}