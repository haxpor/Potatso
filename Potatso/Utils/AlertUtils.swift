//
//  AlertUtils.swift
//  Potatso
//
//  Created by LEI on 4/10/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class Alert: NSObject {

    static func show(vc: UIViewController, title: String? = nil, message: String? = nil, confirmMessage: String = "OK".localized(), confirmCallback: (() -> Void)?, cancelMessage: String = "CANCEL".localized(), cancelCallback: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: confirmMessage, style: .Default, handler: { (action) in
            confirmCallback?()
        }))
        alert.addAction(UIAlertAction(title: cancelMessage, style: .Cancel, handler: { (action) in
            cancelCallback?()
        }))
        vc.presentViewController(alert, animated: true, completion: nil)
    }
    
    static func show(vc: UIViewController, title: String? = nil, message: String? = nil, confirmCallback: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default, handler: { (action) in
            confirmCallback?()
        }))
        vc.presentViewController(alert, animated: true, completion: nil)
    }
    
}