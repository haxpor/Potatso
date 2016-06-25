//
//  UrlHandler.swift
//  Potatso
//
//  Created by LEI on 4/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import PotatsoLibrary
import Async
import CallbackURLKit


class UrlHandler: NSObject, AppLifeCycleProtocol {
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        let manager = Manager.sharedInstance
        manager.callbackURLScheme = Manager.URLSchemes?.first
        for action in [URLAction.ON, URLAction.OFF, URLAction.SWITCH] {
            manager[action.rawValue] = { parameters, success, failure, cancel in
                action.perform(nil, parameters: parameters) { error in
                    Async.main(after: 1, block: {
                        if let error = error {
                            failure(error as NSError)
                        }else {
                            success(nil)
                        }
                    })
                    return
                }
            }
        }
        return true
    }
    
    func application(app: UIApplication, openURL url: NSURL, options: [String : AnyObject]) -> Bool {
        let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
        var parameters: Parameters = [:]
        components?.queryItems?.forEach {
            guard let _ = $0.value else {
                return
            }
            parameters[$0.name] = $0.value
        }
        if let host = url.host {
            return dispatchAction(url, actionString: host, parameters: parameters)
        }
        return false
    }
    
    func dispatchAction(url: NSURL?, actionString: String, parameters: Parameters) -> Bool {
        guard let action = URLAction(rawValue: actionString) else {
            return false
        }
        return action.perform(url, parameters: parameters)
    }

}

enum URLAction: String {

    case ON = "on"
    case OFF = "off"
    case SWITCH = "switch"
    case XCALLBACK = "x-callback-url"

    func perform(url: NSURL?, parameters: Parameters, completion: (ErrorType? -> Void)? = nil) -> Bool {
        switch self {
        case .ON:
            Manager.sharedManager.startVPN({ (manager, error) in
                if error == nil {
                    self.autoClose(parameters)
                }
                completion?(error)
            })
        case .OFF:
            Manager.sharedManager.stopVPN()
            autoClose(parameters)
            completion?(nil)
        case .SWITCH:
            Manager.sharedManager.switchVPN({ (manager, error) in
                if error == nil {
                    self.autoClose(parameters)
                }
                completion?(error)
            })
        case .XCALLBACK:
            if let url = url {
                return Manager.sharedInstance.handleOpenURL(url)
            }
        }
        return true
    }

    func autoClose(parameters: Parameters) {
        var autoclose = false
        if let value = parameters["autoclose"] where value.lowercaseString == "true" || value.lowercaseString == "1" {
            autoclose = true
        }
        if autoclose {
            Async.main(after: 1, block: {
                UIControl().sendAction("suspend", to: UIApplication.sharedApplication(), forEvent: nil)
            })
        }
    }

}