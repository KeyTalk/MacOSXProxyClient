//
//  RCCDViewController.swift
//  KeyTalk Client
//
//  Created by Remco on 29/12/2016.
//  Copyright © 2016 KeyTalk. All rights reserved.
//

import Foundation
import AppKit

class RCCDWindowController: NSWindowController {
  
  
}

extension RCCDWindowController: NSWindowDelegate {
  func windowShouldClose(_ sender: Any) -> Bool {
    let application = NSApplication.shared()
    application.abortModal()
    return true
  }
}

class RCCDViewController: NSViewController {
  @IBOutlet var tableView: NSTableView!
  
  var items : [String] = []
  
  override func viewDidAppear() {
    super.viewDidAppear()
    
    NotificationCenter.default.addObserver(self, selector: #selector(RCCDViewController.updateNotificationSentLabel), name: NSNotification.Name(rawValue: "receive-rccds"), object: nil)
    
    NotificationCenter.default.post(name: Notification.Name(rawValue: "retrieve-rccds"), object: nil)
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func updateNotificationSentLabel(withNotification notification : NSNotification) {
    self.items = notification.object as! [String]
    tableView.reloadData()
  }
  
  @IBAction func deleteRCCD(_ sender: AnyObject) {
    if (tableView.selectedRow == -1) {
      return
    }
    
    
    let path  = items[tableView.selectedRow]
    let appDelegate = NSApplication.shared().delegate as! AppDelegate
    
    appDelegate.deleteRCCDFile(path: path)
  }
  
  @IBAction func importRCCD(_ sender: AnyObject) {
    let myFileDialog: NSOpenPanel = NSOpenPanel()
    myFileDialog.runModal()
    
    // Get the path to the file chosen in the NSOpenPanel
    let path = myFileDialog.url?.path
    
    // Make sure that a path was chosen
    if (path == nil) {
      return
    }
    
    let appDelegate = NSApplication.shared().delegate as! AppDelegate
    appDelegate.importRCCDFile(path: path!)
  }
  
  @IBAction func closeWindow(_ sender: AnyObject) {
    let application = NSApplication.shared()
    application.abortModal()
  }
  
}

extension RCCDViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return items.count
  }
}

extension RCCDViewController: NSTableViewDelegate {
  fileprivate enum CellIdentifiers {
    static let NameCell = "NameCellID"
  }
  
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
    var text: String = ""
    var cellIdentifier: String = ""
    
    let item = items[row]
    if tableColumn == tableView.tableColumns[0] {
      text = item
      cellIdentifier = CellIdentifiers.NameCell
    }
    
    if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
      cell.textField?.stringValue = text
      return cell
    }
    return nil
  }
}
