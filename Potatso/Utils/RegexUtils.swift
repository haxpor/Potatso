//
//  RegexUtils.swift
//  Potatso
//
//  Created by LEI on 6/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class Regex {

    let internalExpression: NSRegularExpression
    let pattern: String

    init(_ pattern: String) throws {
        self.pattern = pattern
        self.internalExpression = try NSRegularExpression(pattern: pattern, options: .CaseInsensitive)
    }

    func test(input: String) -> Bool {
        let matches = self.internalExpression.matchesInString(input, options: NSMatchingOptions.ReportCompletion, range:NSMakeRange(0, input.characters.count))
        return matches.count > 0
    }

}
