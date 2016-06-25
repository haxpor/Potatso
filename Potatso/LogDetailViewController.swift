//
//  LogDetailViewController.swift
//  Potatso
//
//  Created by LEI on 4/21/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoBase
import PotatsoLibrary

class LogDetailViewController: UIViewController {
    
    var source: dispatch_source_t?
    var fd: Int32 = 0
    var data = NSMutableData()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Logs".localized()
        showLog()
    }
    
    deinit {
        if let source = source {
            dispatch_source_cancel(source)
        }
    }
    
    func showLog() {
        guard LoggingLevel.currentLoggingLevel != .OFF else {
            emptyView.hidden = false
            return
        }
        fd = Darwin.open(Potatso.sharedLogUrl().path!, O_RDONLY)
        guard fd > 0 else {
            return
        }
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(fd), 0, queue)
        guard let source = source else {
            return
        }
        dispatch_source_set_event_handler(source){ [weak self] in
            self?.updateUI()
        }
        dispatch_source_set_cancel_handler(source) {
            let fd = dispatch_source_get_handle(source);
            Darwin.close(Int32(fd));
        }
        dispatch_resume(source);
    }
    
    func updateUI() {
        guard let source = source else {
            return
        }
        let pending = dispatch_source_get_data(source)
        let size = Int(min(pending, 65535))
        let buffer = UnsafeMutablePointer<UInt8>.alloc(size)
        defer {
            buffer.dealloc(size)
        }
        let readSize = Darwin.read(fd, buffer, size)
        data.appendBytes(buffer, length: readSize)
        if let content = String(data: data, encoding: NSUTF8StringEncoding) {
            dispatch_async(dispatch_get_main_queue(), { 
                self.logView.text = self.logView.text.stringByAppendingString(content)
            })
            data = NSMutableData()
        }
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        view.addSubview(logView)
        view.addSubview(emptyView)
        constrain(logView, emptyView, view) { logView, emptyView, view in
            logView.edges == view.edges
            emptyView.edges == view.edges
        }
    }
    
    lazy var logView: UITextView = {
        let v = UITextView()
        v.editable = false
        v.backgroundColor = Color.Background
        return v
    }()
    
    lazy var emptyView: BaseEmptyView = {
        let v = BaseEmptyView()
        v.title = "Logging is disabled".localized()
        v.hidden = true
        return v
    }()
    
}