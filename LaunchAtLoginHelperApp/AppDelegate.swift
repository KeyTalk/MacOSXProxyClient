//
//  AppDelegate.swift
//  LaunchAtLoginHelperApp
//
//  Created by Remco on 02/01/2017.
//  Copyright © 2017 KeyTalk. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!


  func applicationDidFinishLaunching(_ aNotification: Notification) {
    var url = Bundle.main.bundleURL
    url = url.deletingLastPathComponent()
    url = url.deletingLastPathComponent()
    url = url.deletingLastPathComponent()
    url = url.appendingPathComponent("MacOS", isDirectory: true)
    url = url.appendingPathComponent("KeyTalk Client", isDirectory: false)
    NSWorkspace.shared().launchApplication(url.path)
    NSApp.terminate(nil)
  }

  func applicationWillTerminate(_ aNotification: Notification) {
  }
}

