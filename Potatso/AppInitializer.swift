//
//  AppInitilizer.swift
//  Potatso
//
//  Created by LEI on 12/27/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

import Foundation
import ICSMainFramework
import Appirater
import Fabric
import Crashlytics

let appID = "1070901416"

class AppInitializer: NSObject, AppLifeCycleProtocol {
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        configLogging()
        Fabric.with([Answers.self, Crashlytics.self])
        configAppirater()
        return true
    }

    func configAppirater() {
        Appirater.setAppId(appID)
        Appirater.setUsesUntilPrompt(100)
        Appirater.setDaysUntilPrompt(0)
        Appirater.setTimeBeforeReminding(100)
        Appirater.setSignificantEventsUntilPrompt(200)
        Appirater.setDebug(false)
        Appirater.appLaunched(true)
    }

    func configLogging() {
        DDLog.addLogger(DDTTYLogger.sharedInstance()) // TTY = Xcode console
        DDLog.addLogger(DDASLLogger.sharedInstance()) // ASL = Apple System Logs

        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = 60*60*24*3  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(fileLogger)
        #if DEBUG
            DDLog.setLevel(DDLogLevel.All, forClass: DDTTYLogger.self)
            DDLog.setLevel(DDLogLevel.All, forClass: DDASLLogger.self)
        #else

        #endif
    }
    
}