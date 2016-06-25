//
//  PotatsoLibraryTests.swift
//  PotatsoLibraryTests
//
//  Created by LEI on 4/8/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import XCTest
import RealmSwift
import PotatsoModel
@testable import PotatsoLibrary

class PotatsoLibraryTests: XCTestCase {
    
    let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "test"))
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEmptyString() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        let config = Config()
//        do {
//            try config.setup(string: "")
//        }catch ProxyError.InvalidConfig {
//            
//        }catch {
//        }
    }
    
    func testSyntaxError() {
        let config = Config()
        do {
            try config.setup(string:"ss-1s: xx \nsds" )
            assert(false)
        }catch ConfigError.SyntaxError {
            
        }catch {
            assert(false)
        }

    }
    
    // MARK - Proxy
    
    func testInvalidProxy() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let config = Config()
        do {
            try config.setup(string: [
                "proxies:\n",
                "- name: vultr",
                "  type: shadowsocks",
                "  host: 10.0.0.0",
                "  port: 9000",
                "  encryption: rc4-md5"].joinWithSeparator("\n"))
            assert(false)
        }catch ProxyError.InvalidPassword {
            
        }catch {
            assert(false)
        }
    }
    
    func testSingle() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let config = Config()
        do {
            try config.setup(string: [
                "proxies:\n",
                "- name: vultr",
                "  type: shadowsocks",
                "  host: 10.0.0.0",
                "  port: 9000",
                "  encryption: rc4-md5",
                "  password: 12345"].joinWithSeparator("\n"))
            assert(config.proxies.count == 1)
            let proxy = config.proxies[0]
            assert(proxy.name == "vultr")
            assert(proxy.type == .Shadowsocks)
            assert(proxy.host == "10.0.0.0")
            assert(proxy.port == 9000)
            assert(proxy.authscheme == "rc4-md5")
            assert(proxy.password == "12345")
        }catch {
            assert(false)
        }
    }

    func testMultiple() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let config = Config()
        do {
            try config.setup(string: [
                "proxies:\n",
                "- name: vultr",
                "  type: shadowsocks",
                "  host: 10.0.0.0",
                "  port: 9000",
                "  encryption: rc4-md5",
                "  password: 12345",
                "- name: vultr2",
                "  type: shadowsocks",
                "  host: 10.0.0.0",
                "  port: 9000",
                "  encryption: rc4-md5",
                "  password: 12345"].joinWithSeparator("\n"))
            assert(config.proxies.count == 2)
        }catch {
            assert(false)
        }
    }
    
    func testMultipleSameName() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let config = Config()
        do {
            try config.setup(string: [
                "proxies:\n",
                "- name: vultr",
                "  type: shadowsocks",
                "  host: 10.0.0.0",
                "  port: 9000",
                "  encryption: rc4-md5",
                "  password: 12345",
                "- name: vultr",
                "  type: shadowsocks",
                "  host: 10.0.0.0",
                "  port: 9000",
                "  encryption: rc4-md5",
                "  password: 12345"].joinWithSeparator("\n"))
            assert(false)
        }catch ProxyError.NameAlreadyExists {
            
        }catch {
            assert(false)
        }
    }
    
    func testUri() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let config = Config()
        do {
            try config.setup(string: [
                "proxies:\n",
                "- name: vultr",
                "  uri: ss://salsa20:%%%%$$$:@@10.0.0.0:443"].joinWithSeparator("\n"))
            assert(config.proxies.count == 1)
            let proxy = config.proxies[0]
            assert(proxy.name == "vultr")
            assert(proxy.type == .Shadowsocks)
            assert(proxy.host == "10.0.0.0")
            assert(proxy.port == 443)
            assert(proxy.authscheme == "salsa20")
            assert(proxy.password == "%%%%$$$:@")
        }catch {
            assert(false)
        }
    }
    
    func testInvalidUri() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let config = Config()
        do {
            try config.setup(string: [
                "proxies:\n",
                "- name: vultr",
                "  uri: ss://salsa20:%%%%$$$:@@10.0.0.0"].joinWithSeparator("\n"))
            assert(false)
        }catch {
        }
    }
    
    // MARK: - Rule
    
    func testRule() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        do {
            var rule = try Rule(str: "DOMAIN-MATCH, google, DIRECT")
            assert(rule.action == .Direct)
            assert(rule.type == .DomainMatch)
            assert(rule.value == "google")
            
            rule = try Rule(str: "DOMAIN-MATCH, google, PROXY")
            assert(rule.action == .Proxy)
            
            rule = try Rule(str: "DOMAIN-MATCH, baidu, REJECT")
            assert(rule.action == .Reject)
            assert(rule.value == "baidu")
            
            rule = try Rule(str: "DOMAIN-SUFFIX, baidu.com, REJECT")
            assert(rule.type == .DomainSuffix)
            
            rule = try Rule(str: "DOMAIN, www.baidu.com, REJECT")
            assert(rule.type == .Domain)
            
            rule = try Rule(str: "URL, www.baidu.com, REJECT")
            assert(rule.type == .URL)
            
            rule = try Rule(str: "URL-MATCH, ^(https?:\\/\\/)?api\\.xiachufang\\.com\\/v\\d\\/ad\\/show\\.json, REJECT")
            assert(rule.type == .URLMatch)
            assert(rule.value == "^(https?:\\/\\/)?api\\.xiachufang\\.com\\/v\\d\\/ad\\/show\\.json")
            
            rule = try Rule(str: "IP-CIDR, 17.0.0.0/8, PROXY")
            assert(rule.type == .IPCIDR)
            
            rule = try Rule(str: "GEOIP, cn, PROXY")
            assert(rule.type == .GeoIP)
        }catch {
            assert(false)
        }
    }
    
}
