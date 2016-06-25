//
//  Aspects.swift
//  Aspects
//
//  Created by LEI on 12/12/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation

struct Aspect {
    
    
    
}

public enum AspectOptions {
    case Before
    case After
    case Instead
}

public extension NSObject {
    
   public class func aspectHook(originalSelector: Selector, swizzledSelector: Selector, options: AspectOptions = .Instead) {
        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        
        let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
    
}

