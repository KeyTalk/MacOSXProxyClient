//
//  AboutViewController.swift
//  KeyTalk
//

import Foundation
import AppKit

class AboutWindowController: NSWindowController {
}

extension AboutWindowController: NSWindowDelegate {
  func windowShouldClose(_ sender: Any) -> Bool {
    let application = NSApplication.shared()
    application.abortModal()
    return true
  }
}

class AboutViewController: NSViewController {
  override func viewDidAppear() {
    super.viewDidAppear()
  }
  
  @IBAction func gotoWebsite(_ sender: AnyObject) {
    NSWorkspace.shared().open(URL(string:"https://www.keytalk.com/")!)
  }

  @IBAction func gotoTwitter(_ sender: AnyObject) {
    NSWorkspace.shared().open(URL(string:"mailto:support@keytalk.com")!)
  }
}
