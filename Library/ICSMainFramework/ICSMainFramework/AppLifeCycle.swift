//
//  AppInitialize.swift
//  ICSMainFramework
//
//  Created by LEI on 5/14/15.
//  Copyright (c) 2015 TouchingApp. All rights reserved.
//

import Foundation

@objc public protocol AppLifeCycleProtocol: UIApplicationDelegate {
    
}


public struct AppLifeCycleItem {
    
    public var object: AppLifeCycleProtocol?
    
    init?(dictionary: [String: AnyObject]) {
        if let objectString = dictionary["object"] as? String {
            object = OBJCObjectFactory.create(objectString) as? AppLifeCycleProtocol
        }
        if object == nil {
            return nil
        }
    }
    
}