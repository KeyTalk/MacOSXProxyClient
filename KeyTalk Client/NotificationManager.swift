//
//  NotificationManager.swift
//  KeyTalk Client
//
//  Created by Remco on 30/12/2016.
//  Copyright © 2016 KeyTalk. All rights reserved.
//

import Foundation

private let _NotificationManager = NotificationManager()

class NotificationManager : NSObject, NSUserNotificationCenterDelegate {
  class func sharedManager() -> NotificationManager {
    return _NotificationManager
  }
  
  func showNotification(_ title: String, informativeText: String){
    let notification = NSUserNotification()
    
    notification.title = title
    notification.informativeText = informativeText
    notification.deliveryDate = Date()
    
    NSUserNotificationCenter.default.delegate = self
    
    NSUserNotificationCenter.default.scheduleNotification(notification)
  }
  
  func showNotification(_ title: String, errorText: String){
    let notification = NSUserNotification()
    
    notification.title = title
    notification.informativeText = errorText
    notification.deliveryDate = Date()
    
    NSUserNotificationCenter.default.delegate = self
    
    NSUserNotificationCenter.default.scheduleNotification(notification)
  }
  
  func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
    return true
  }
}
