//
//  RequestModel.swift
//  Potatso
//
//  Created by LEI on 4/20/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import RealmSwift
import PotatsoLibrary
import PotatsoBase

enum HTTPMethod: String {
    case GET = "GET"
    case HEAD = "HEAD"
    case CONDITIONAL_GET = "CONDITIONAL"
    case CONNECT = "CONNECT"
    case POST = "POST"
    case PUT = "PUT"
    case OPTIONS = "OPTIONS"
    case DELETE = "DELETE"
}

extension HTTPMethod: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .CONNECT:
            return "HTTPS"
        default:
            return rawValue
        }
    }
}

enum HTTPResponseCode: Int {
    case CODE_200 = 200
    case CODE_201 = 201
    case CODE_202 = 202
    case CODE_203 = 203
    case CODE_204 = 204
    case CODE_205 = 205
    case CODE_206 = 206
    case CODE_301 = 301
    case CODE_302 = 302
    case CODE_303 = 303
    case CODE_304 = 304
    case CODE_305 = 305
    case CODE_306 = 306
    case CODE_307 = 307
    case CODE_400 = 400
    case CODE_401 = 401
    case CODE_402 = 402
    case CODE_403 = 403
    case CODE_404 = 404
    case CODE_405 = 405
    case CODE_406 = 406
    case CODE_407 = 407
    case CODE_408 = 408
    case CODE_409 = 409
    case CODE_410 = 410
    case CODE_411 = 411
    case CODE_412 = 412
    case CODE_413 = 413
    case CODE_414 = 414
    case CODE_415 = 415
    case CODE_416 = 416
    case CODE_417 = 417
    case CODE_500 = 500
    case CODE_501 = 501
    case CODE_502 = 502
    case CODE_503 = 503
    case CODE_504 = 504
    case CODE_505 = 505

}

extension HTTPResponseCode: CustomStringConvertible {
    
    var color: UIColor {
        switch self.rawValue {
        case 200..<300:
            return "1ABC9C".color
        case 300..<400:
            return "9B59B6".color
        case 400..<500:
            return "E74C3C".color
        case 500..<600:
            return "000000".color
        default:
            return UIColor.blackColor()
        }
    }
    
    var description: String {
        return "\(rawValue)"
    }
}

enum RequestEventType: Int {
    case Init = 0
    case DNS
    case Remote
    case Open
    case Closed
}

struct RequestEvent {
    let type: RequestEventType
    let timestamp: NSTimeInterval
    var duration: NSTimeInterval = -1
    
    init(type: RequestEventType, timestamp: NSTimeInterval) {
        self.type = type
        self.timestamp = timestamp
    }
}

struct Request {
    
    static let statusCount = 7
    
    var events: [RequestEvent] = []
    var url: String
    var method: HTTPMethod = .GET
    var rule: Rule?
    var version: String?
    var responseCode: HTTPResponseCode?
    var headers: String?
    var defaultToProxy: Bool = false
    
    init?(dict: [String: AnyObject]) {
        guard let _ = dict["time0"] as? Double, url = dict["url"] as? String, m = dict["method"] as? String, method = HTTPMethod(rawValue: m) else {
            return nil
        }
        var unnormalizedEvents: [RequestEvent] = []
        for i in 0..<Request.statusCount {
            if let t = dict["time\(i)"] as? Double, e = RequestEventType(rawValue: i) where t > 0{
                unnormalizedEvents.append(RequestEvent(type: e, timestamp: t))
            }
        }
        unnormalizedEvents.sortInPlace { (event1, event2) -> Bool in
            return event1.timestamp < event2.timestamp
        }
        var lastEvent: RequestEvent?
        for event in unnormalizedEvents {
            if let e = lastEvent {
                lastEvent?.duration = event.timestamp - e.timestamp
                events.append(lastEvent!)
            }
            lastEvent = event
        }
        if let e = lastEvent {
            events.append(e)
        }
        self.url = url
        self.method = method
        if let v = dict["version"] as? String {
            self.version = v
        }
        self.headers = dict["headers"] as? String
        if let ruleTypeIntValue = dict["ruleType"] as? Int, ruleType = RuleType.fromInt(ruleTypeIntValue), actionIntValue = dict["ruleAction"] as? Int, action = RuleAction.fromInt(actionIntValue),value = dict["ruleValue"] as? String {
            self.rule = Rule(type: ruleType, action: action, value: value)
        }
        if let c = dict["responseCode"] as? Int, code = HTTPResponseCode(rawValue: c) {
            self.responseCode = code
        }
    }
}
