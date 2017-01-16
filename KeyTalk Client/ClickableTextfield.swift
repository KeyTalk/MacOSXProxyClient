//
//  ClickableTextfield.swift
//  KeyTalk

import Foundation
import AppKit

class ClickableTextfield: NSTextField {
  override func mouseDown(with theEvent: NSEvent) {
    self.sendAction(self.action, to: self.target)
  }
}
