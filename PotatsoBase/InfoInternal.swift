//
//  InfoInternal.swift
//  PotatsoBase
//
//  Created by Wasin Thonkaew on 1/6/18.
//  Copyright © 2018 TouchingApp. All rights reserved.
//

import Foundation

public class InfoInternal: NSObject {
    public static let shared = InfoInternal()
    var infoDict: Dictionary<String, Any>
    
    fileprivate override init() {
        infoDict = Bundle.main.infoDictionary!["PotatsoInternal"] as! Dictionary<String, Any>
    }
    
    public func getGroupIdentifier() -> String {
        return infoDict["GroupIdentifier"] as! String
    }
    
    public func getLogglyAPIKey() -> String {
        return infoDict["LogglyAPIKey"] as! String
    }
}
