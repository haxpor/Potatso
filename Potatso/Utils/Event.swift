//
//  Event.swift
//  Potatso
//
//  Created by LEI on 7/5/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

enum Event: String {

    case ReceiptValidation = "ReceiptValidation"
    case ReceiptValidationResult = "ReceiptValidationResult"
    case ReceiptValidationBuy = "ReceiptValidationBuy"
    case ReceiptValidationCancel = "ReceiptValidationCancel"

}

func logEvent(event: Event, attributes: [String: AnyObject]?) {
    #if DEBUG
        // Don't log
    #else
        Answers.logCustomEventWithName(event.rawValue, customAttributes: attributes)
    #endif
}