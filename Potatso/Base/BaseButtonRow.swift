//
//  BaseButtonRow.swift
//  Potatso
//
//  Created by LEI on 6/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Eureka

public final class _BaseButtonRow<T: Equatable> : _ButtonRowOf<T>, RowType {

    public required init(tag: String?) {
        super.init(tag: tag)
    }

    public override func updateCell() {
        super.updateCell()
        let leftAligmnment = presentationMode != nil
        if (!leftAligmnment){
            cell.textLabel?.textColor = Color.Action
        }
    }

}

public typealias BaseButtonRow = _BaseButtonRow<String>
