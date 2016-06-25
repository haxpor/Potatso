//
//  LoggerUtils.swift
//  Potatso
//
//  Created by LEI on 6/21/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

extension ErrorType {

    func log(message: String?) {
        let errorDesc = (self as NSError).localizedDescription
        if let message = message {
            DDLogError("\(message): \(errorDesc)")
        }else {
            DDLogError("\(errorDesc)")
        }
    }

}
