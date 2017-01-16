//
//  KeyTalkProxy.swift
//  KeyTalk Client
//
//  Created by Remco on 30/12/2016.
//  Copyright © 2016 KeyTalk. All rights reserved.
//

import Foundation
import Starscream

class KeyTalkProxy: WebSocket {
  public init() {
    super.init(url: URL(string: "ws://127.0.0.1:8080/ws")!)
  }
  
  public func reload() throws {
    let data = try JSONSerialization.data(withJSONObject: ["type": "reload"], options: JSONSerialization.WritingOptions.prettyPrinted)
    self.write(data: data)
  }
  
  public func deleteCertificate() throws {
    let data = try JSONSerialization.data(withJSONObject: ["type": "delete-certificate"], options: JSONSerialization.WritingOptions.prettyPrinted)
    self.write(data: data)
  }
  
  public func retrieveRCCDs() throws {
    let data = try JSONSerialization.data(withJSONObject: ["type": "retrieve-rccds"], options: JSONSerialization.WritingOptions.prettyPrinted)
    self.write(data: data)
  }
  
  public func retrieveServiceURIs() throws {
    let data = try JSONSerialization.data(withJSONObject: ["type": "retrieve-service-uris"], options: JSONSerialization.WritingOptions.prettyPrinted)
    self.write(data: data)
  }
}
