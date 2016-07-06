//
//  Importer.swift
//  Potatso
//
//  Created by LEI on 4/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Async
import PotatsoModel
import PotatsoLibrary

struct Importer {
    
    weak var viewController: UIViewController?
    
    init(vc: UIViewController) {
        self.viewController = vc
    }
    
    func importConfigFromUrl() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Import Config From URL".localized(), message: nil, preferredStyle: .Alert)
        alert.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Input URL".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default, handler: { (action) in
            if let input = urlTextField?.text {
                self.onImportInput(input)
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel, handler: nil))
        viewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    func importConfigFromQRCode() {
        let vc = HMScannerViewController { (result) in
            self.onImportInput(result)
        }
        viewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onImportInput(result: String) {
        if result.lowercaseString.hasPrefix("ss://") {
            importSS(result)
        }else {
            importConfig(result, isURL: true)
        }
    }
    
    func importSS(source: String) {
        let base64String = source.substringFromIndex(source.startIndex.advancedBy(5))
        let padding = base64String.characters.count + (base64String.characters.count % 4 != 0 ? (4 - base64String.characters.count % 4) : 0)
        if let decodedData = NSData(base64EncodedString: base64String.stringByPaddingToLength(padding, withString: "=", startingAtIndex: 0), options:   NSDataBase64DecodingOptions(rawValue: 0)), decodedString = NSString(data: decodedData, encoding: NSUTF8StringEncoding) {
            do {
                let proxy = try Proxy(dictionary: ["name": "___scanresult", "uri": "ss://\(decodedString)"], inRealm: defaultRealm)
                var urlTextField: UITextField?
                let alert = UIAlertController(title: "Add a new proxy".localized(), message: "Please set name for the new proxy".localized(), preferredStyle: .Alert)
                alert.addTextFieldWithConfigurationHandler { (textField) in
                    textField.placeholder = "Input name".localized()
                    urlTextField = textField
                }
                alert.addAction(UIAlertAction(title: "OK".localized(), style: .Default){ (action) in
                    guard let text = urlTextField?.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) else {
                        self.onConfigSaveCallback(false, error: "Name can't be empty".localized())
                        return
                    }
                    proxy.name = text
                    do {
                        try proxy.validate(inRealm: defaultRealm)
                        try defaultRealm.write {
                            defaultRealm.add(proxy)
                        }
                        self.onConfigSaveCallback(true, error: nil)
                    }catch {
                        self.onConfigSaveCallback(false, error: error)
                    }
                    })
                alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .Cancel) { action in
                    })
                viewController?.presentViewController(alert, animated: true, completion: nil)
            }catch {
                self.onConfigSaveCallback(false, error: error)
            }
        }
        if let vc = viewController {
            Alert.show(vc, message: "Fail to parse proxy config".localized())
        }
    }
    
    func importConfig(source: String, isURL: Bool) {
        viewController?.showProgreeHUD("Importing Config...".localized())
        Async.background(after: 1) {
            let config = Config()
            do {
                if isURL {
                    if let url = NSURL(string: source) {
                        try config.setup(url: url)
                    }
                }else {
                    try config.setup(string: source)
                }
                try config.save()
                self.onConfigSaveCallback(true, error: nil)
            }catch {
                self.onConfigSaveCallback(false, error: error)
            }
        }
    }
    
    func onConfigSaveCallback(success: Bool, error: ErrorType?) {
        Async.main(after: 0.5) {
            self.viewController?.hideHUD()
            if !success {
                var errorDesc = ""
                if let error = error {
                    errorDesc = "(\(error))"
                }
                if let vc = self.viewController {
                    Alert.show(vc, message: "\("Fail to save config.".localized()) \(errorDesc)")
                }
            }else {
                self.viewController?.showTextHUD("Import Success".localized(), dismissAfterDelay: 1.5)
            }
        }
    }

}