//
//  AppDelegate.swift
//  KeyTalk Client
//
//  Created by Remco on 08/12/2016.
//  Copyright © 2016 KeyTalk. All rights reserved.
//

import Cocoa
import SystemConfiguration
import Security
import ServiceManagement
import zipzap
import AppKit
import Starscream

// todo(nl5887): show other icon when no connection with proxy
// todo(nl5887): show other icon when proxy not configured
extension Notification.Name {
  static let retrieveRCCDs = Notification.Name("retrieve-rccds")
  static let retrieveServiceURIs = Notification.Name("retrieve-service-uris")
  static let receiveServiceURIs = Notification.Name("receive-service-uris")
}

class AppMenu: NSMenu {
}

protocol UniqueArrayExtension
{
  func getUniqueValues<T: Equatable>(forArray: Array<T>) -> Array<T>
}

extension UniqueArrayExtension
{
  func getUniqueValues<T: Equatable>(forArray: Array<T>) -> Array<T>
  {
    var collection = Array<T>()
    
    for element: T in forArray
    {
      if collection.contains(element) {
        continue
      }

      collection.append(element)
    }
    
    return collection
  }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, WebSocketDelegate, UniqueArrayExtension {
  var task:Process!
  
  var osStatus: OSStatus?
  
  var startStopItem: NSMenuItem!
  var startAtLoginItem: NSMenuItem!
  var enableDisableProxyItem: NSMenuItem!
  var servicesItem: NSMenuItem!
  
  lazy var servicesMenu: NSMenu = {
    return NSMenu()
  }()
  
  lazy var userDefaults: UserDefaults =  {
    return UserDefaults.standard
  }()
  
  lazy var proxy: KeyTalkProxy = {
    return KeyTalkProxy()
  }()
  
  lazy var appMenu: AppMenu = {
    return AppMenu()
  }()
  
  lazy var authRef: AuthorizationRef? = {
    var authRef: AuthorizationRef?;
    self.osStatus = AuthorizationCreate(nil, nil, [.partialRights,  .extendRights, .interactionAllowed, .preAuthorize], &authRef)
    return authRef
  }()
  
  lazy var statusItem = {
    return NSStatusBar.system().statusItem(withLength: -1)
  }()
  
  lazy var statusImageRunning: NSImage = {
    let  statusImage: NSImage = NSImage(named:"AppIcon")!;
    statusImage.size = NSMakeSize(18.0, 18.0);
    return statusImage
  }()
  
  lazy var statusImageNotRunning: NSImage = {
    let  statusImage: NSImage = NSImage(named:"AppIcon")!;
    statusImage.size = NSMakeSize(18.0, 18.0);
    return statusImage
  }()
  
  func applicationWillTerminate(_ aNotification: Notification) {
    if (task == nil) {
    } else if (task.isRunning) {
      task.terminate()
    }
  }
  
  enum InstallCertificateError: Error {
    case FromData // "Could not create certificate from data."
  }
  
  func deleteRCCDFile(path: String) {
    do {
      if !FileManager.default.fileExists(atPath: path) {
        return
      }
      
      try FileManager.default.removeItem(atPath: path)
      
      try proxy.reload()
      
      NotificationCenter.default.post(name: Notification.Name.retrieveRCCDs, object: nil)
    } catch let err as NSError {
      print("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      dialogError(question: "KeyTalk Error", text: "\(err.localizedDescription)")
    }
  }
  
  func importRCCDFile(path: String) {
    // parse yaml file?
    // https://github.com/endash/yaml.swift
    
    do {
      let filename = URL(fileURLWithPath: path).lastPathComponent
      
      let archive = try ZZArchive.init(url: URL(fileURLWithPath: path))
      
      for entry in archive.entries as! [ZZArchiveEntry] {
        let filename = NSURL(fileURLWithPath: entry.fileName);
        
        var certificateData = Data()
        if filename.pathExtension! == "der" {
          certificateData = try entry.newData()
        } else if filename.pathExtension! == "pem" {
          var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("KeyTalk")
          
          var isDir : ObjCBool = false
          if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
          }
          
          url = url.appendingPathComponent(filename.lastPathComponent!)
          
          let data = try entry.newData()
          try data.write(to: url)
          
          if let aStreamReader = StreamReader(path: url.path) {
            var dataStr = ""
            
            while let line = aStreamReader.nextLine() {
              if (line == "-----BEGIN CERTIFICATE-----") {
                dataStr = ""
              } else if (line == "-----END CERTIFICATE-----") {
                certificateData = Data(base64Encoded: dataStr, options: .ignoreUnknownCharacters)!
                
                try loadCertificate(data: certificateData)
              } else if (line == "-----BEGIN RSA PRIVATE KEY-----") {
                dataStr = ""
              } else if (line == "-----END RSA PRIVATE KEY-----") {
              } else  {
                dataStr += line + "\n"
              }
            }
          }
        } else {
          continue
        }
      }
      
      if !FileManager.default.fileExists(atPath: getApplicationURL().appendingPathComponent(filename).path) {
        try FileManager.default.copyItem(atPath: path, toPath: getApplicationURL().appendingPathComponent(filename).path)
      }
      
      try proxy.reload()
      
      NotificationCenter.default.post(name: Notification.Name.retrieveRCCDs, object: nil)
    } catch let err as NSError {
      print("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      dialogError(question: "KeyTalk Error", text: "\(err.localizedDescription)")
    }
  }
  
  func application(_ sender: NSApplication, openFile path: String) -> Bool {
    importRCCDFile(path: path)
    
    let filename = URL(fileURLWithPath: path).lastPathComponent
    
    NotificationManager.sharedManager().showNotification("KeyTalk", informativeText: "KeyTalk RCCD \(filename) has been installed.")
    
    return true
  }
  
  func loadCertificate(data: Data) throws {
    do {
      let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData)
      
      if certificate == nil {
        throw InstallCertificateError.FromData
      }
      
      let kc = try Keychain.Open(path: getKeychainURL().path)
      
      let err = SecCertificateAddToKeychain(certificate!, kc._keychain)
      if err == errSecSuccess {
        SecTrustSettingsSetTrustSettings(certificate!, SecTrustSettingsDomain.user, nil)
      } else if err == errSecDuplicateItem {
      } else {
        throw make_sec_error(err, "Cannot create keychain")
      }
      
    } catch let err as NSError {
      print("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      dialogError(question: "KeyTalk Error", text: "\(err.localizedDescription)")
    }
  }
  
  func keytalkProxyURL() -> URL {
    print( Bundle.main.bundleURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("keytalk-proxy").path)
    return Bundle.main.bundleURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("keytalk-proxy");
  }
  
  func bootstrap() {
    // bootstrap first using keytalk binary
    let bootstrapTask = Process()
    
    // use applicationdata folder
    bootstrapTask.launchPath = keytalkProxyURL().path
    bootstrapTask.arguments = ["bootstrap"]
    bootstrapTask.launch()
    bootstrapTask.waitUntilExit()
    
    do {
      var certificateData = Data()
      
      if let aStreamReader = StreamReader(path: getApplicationURL().appendingPathComponent("ca.pem").path) {
        var dataStr = ""
        
        while let line = aStreamReader.nextLine() {
          if (line == "-----BEGIN CERTIFICATE-----") {
            dataStr = ""
          } else if (line == "-----END CERTIFICATE-----") {
            certificateData = Data(base64Encoded: dataStr, options: .ignoreUnknownCharacters)!

            try loadCertificate(data: certificateData)
          } else if (line == "-----BEGIN RSA PRIVATE KEY-----") {
            dataStr = ""
          } else if (line == "-----END RSA PRIVATE KEY-----") {
          } else  {
            dataStr += line + "\n"
          }
        }
      }
      
      NSLog("Installed ca certificate succesfully.")
    } catch let err as NSError {
      print("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      dialogError(question: "KeyTalk Error", text: "\(err.localizedDescription)")
    }
  }
  
  func checkAlreadyRunning() {
    let bundleID = Bundle.main.bundleIdentifier!
    
    if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1  {
      /* Activate the other instance and terminate this instance. */
      let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      for app in apps {
        if app != NSRunningApplication.current() {
          app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
          break
        }
      }
      
      NSApp.terminate(nil)
    }
  }
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    checkAlreadyRunning()
    
    bootstrap()
    
    statusItem.image = statusImageNotRunning
    statusItem.highlightMode = true
    statusItem.menu = appMenu
    
    enableDisableProxyItem = NSMenuItem(title: "", action: #selector(AppDelegate.enableProxy(_:)), keyEquivalent: "")
    
    appMenu.addItem(enableDisableProxyItem)
    
    appMenu.addItem(NSMenuItem(title: "Remove certificates", action: #selector(AppDelegate.deleteCertificates(_:)), keyEquivalent: ""))
    
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "Show logs", action: #selector(AppDelegate.openLog(_:)), keyEquivalent: ""))
    appMenu.addItem(NSMenuItem(title: "Configuration", action: #selector(AppDelegate.importRCCD(_:)), keyEquivalent: ""))
    
    servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
    appMenu.addItem(servicesItem)
    
    appMenu.setSubmenu(servicesMenu, for: servicesItem)
    
    startAtLoginItem = NSMenuItem(title: "Start at login", action: #selector(AppDelegate.startAtLoginItem(_:)), keyEquivalent: "")
    appMenu.addItem(startAtLoginItem)
    
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "About", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: ""))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "Quit KeyTalk", action: #selector(AppDelegate.quit(_:)), keyEquivalent: ""))
    
    addObservers()
    
    _ = Timer.scheduledTimer(timeInterval: 0, target: self, selector: #selector(startProxy), userInfo: nil, repeats: false)
    
    if (userDefaults.object(forKey: "launchAtLogin") == nil) {
      startAtLogin(enabled: true)
    }
  }
  
  func addObservers() {
    NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.updateNotificationSentLabel), name: Notification.Name.retrieveRCCDs, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.updateNotificationSentLabel), name: Notification.Name.retrieveServiceURIs, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.updateNotificationSentLabel), name: Notification.Name.receiveServiceURIs, object: nil)
  }
  
  func isProxyEnabled() -> Bool  {
    let prefRef = SCPreferencesCreate(nil, "KeyTalk Client" as CFString, nil)!
    
    var enabled = true;
    
    let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)!
    sets.allKeys!.forEach { (key) in
      let dict = sets.object(forKey: key)!
      
      let hardware = (dict as AnyObject).value(forKeyPath: "Interface.Hardware")
      
      if hardware != nil && ["AirPort","Wi-Fi","Ethernet"].contains(hardware as! String) {
        let b = SCPreferencesPathGetValue(prefRef, "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as CFString)!  as! Dictionary<NSObject, AnyObject>
        if (b[kCFNetworkProxiesHTTPSEnable  as NSString] == nil) {
          return
        }
        
        enabled = enabled && ((b[kCFNetworkProxiesHTTPSEnable  as NSString] as! NSNumber) == 1)
      }
    }
    
    return enabled
  }
  
  func toggleProxy(enable: Bool) {
    if(self.authRef == nil && self.osStatus != errAuthorizationSuccess) {
      return
    }
    
    let prefRef = SCPreferencesCreateWithAuthorization(nil, "KeyTalk Client" as CFString, nil, self.authRef)!
    let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)!
    
    var proxies = [NSObject: AnyObject]()
    if(enable) {
      proxies[kCFNetworkProxiesHTTPSEnable] = 1 as NSNumber
      proxies[kCFNetworkProxiesHTTPSProxy] = "127.0.0.1" as AnyObject?
      proxies[kCFNetworkProxiesHTTPSPort] = 8080 as NSNumber
      proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber
    } else {
      proxies[kCFNetworkProxiesHTTPSEnable] = 0 as NSNumber
    }
    
    sets.allKeys!.forEach { (key) in
      let dict = sets.object(forKey: key)!
      let hardware = (dict as AnyObject).value(forKeyPath: "Interface.Hardware")
      
      if hardware != nil && ["AirPort","Wi-Fi","Ethernet"].contains(hardware as! String) {
        SCPreferencesPathSetValue(prefRef, "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as CFString, proxies as CFDictionary)
      }
    }
    
    SCPreferencesCommitChanges(prefRef)
    SCPreferencesApplyChanges(prefRef)
    SCPreferencesSynchronize(prefRef)
  }
  
  @IBAction func openLog(_ sender:  AnyObject) {
    let task = Process()
    
    let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs").appendingPathComponent("keytalk.log")
    
    task.launchPath = "/Applications/Utilities/Console.app/Contents/MacOS/Console"
    task.arguments = [url.path]
    task.launch()
  }
  
  @IBAction func disableProxy(_ sender:  AnyObject) {
    toggleProxy(enable: false)
  }
  
  @IBAction func enableProxy(_ sender:  AnyObject) {
    toggleProxy(enable: true)
  }
  
  func getKeychainURL() -> URL {
    let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Keychains").appendingPathComponent("login.keychain")
    return(url)
  }
  
  func getApplicationURL() -> URL {
    let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("KeyTalk")
    return(url)
  }
  
  func dialogError(question: String, text: String) {
    let myPopup: NSAlert = NSAlert()
    myPopup.messageText = question
    myPopup.informativeText = text
    myPopup.alertStyle = NSAlertStyle.critical
    myPopup.addButton(withTitle: "OK")
    myPopup.runModal()
  }
  
  func deleteCertificates(forProvider: String) {
    do{
      let kc = try Keychain.Open(path: getKeychainURL().path)
      
      let identities  = try kc.SearchIdentities(maxResults: 1000)
      
      let defaults = UserDefaults.standard
      
      var certificates: [String: Any]=[String: Any]()
      
      if let v = defaults.dictionary(forKey: "certificates") {
        certificates = v
      }
      
      for identity in identities {
        let certificate = try identity.getCertificate();
        
        for provider in certificates.keys {
          if provider != forProvider {
            continue
          }
          
          var serviceCerts: [String] = []
          if let v = certificates[provider] {
            serviceCerts = v as! [String]
          }
          
          if !serviceCerts.contains(where: { certificate.fingerprint() == $0 }) {
            continue
          }
          
          serviceCerts = serviceCerts.filter{
            certificate.fingerprint() != $0
          }
          
          certificates[provider] = serviceCerts
          
          try kc.DeleteItem(item: certificate.ItemRef)
        }
      }
      
      defaults.set(certificates, forKey: "certificates")
      defaults.synchronize()
    }
    catch let err as NSError
    {
      NSLog("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      NotificationManager.sharedManager().showNotification("KeyTalk", errorText: "Error while deleting certificates: \(err.localizedDescription).")
    }
  }
  
  @IBAction func deleteCertificates(_ sender:  AnyObject) {
    do{
      let kc = try Keychain.Open(path: getKeychainURL().path)
      
      let identities  = try kc.SearchIdentities(maxResults: 1000)
      
      let defaults = UserDefaults.standard
      
      var certificates: [String: Any]=[String: Any]()
      
      if let v = defaults.dictionary(forKey: "certificates") {
        certificates = v
      }
      
      for identity in identities {
        let certificate = try identity.getCertificate();
        
        for provider in certificates.keys {
          var serviceCerts: [String] = []
          if let v = certificates[provider] {
            serviceCerts = v as! [String]
          }
          
          if !serviceCerts.contains(where: { certificate.fingerprint() == $0 }) {
            continue
          }
          
          serviceCerts = serviceCerts.filter{
            certificate.fingerprint() != $0
          }
          
          certificates[provider] = serviceCerts
          
          try kc.DeleteItem(item: certificate.ItemRef)
        }
      }
      
      defaults.set(certificates, forKey: "certificates")
      defaults.synchronize()
      
      try proxy.deleteCertificate()
      
      NotificationManager.sharedManager().showNotification("KeyTalk", informativeText: "KeyTalk certificates have been deleted.")
    }
    catch let err as NSError
    {
      NSLog("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      NotificationManager.sharedManager().showNotification("KeyTalk", errorText: "Error while deleting certificates: \(err.localizedDescription).")
    }
  }
  
  @IBAction func startProxy(_ sender: AnyObject) {
    task = Process()
    
    task.launchPath = keytalkProxyURL().path
    task.arguments = ["run"]
    
    let pipe:Pipe = Pipe()
    task.standardOutput = pipe
    
    let outHandle = pipe.fileHandleForReading
    
    outHandle.readabilityHandler = { pipe in
      if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8) {
        print("\(line)")
      } else {
        print("Error decoding data: \(pipe.availableData)")
      }
    }
    
    task.terminationHandler = {
      task in
      DispatchQueue.main.async(execute: {
        NotificationManager.sharedManager().showNotification("KeyTalk", informativeText: "KeyTalk daemon \(self.keytalkProxyURL().path) stopped with status: \(self.task.terminationStatus)")
        
        self.statusItem.image = self.statusImageNotRunning
        
        self.task = nil;
        
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.startProxy), userInfo: nil, repeats: false)
      })
    }
    
    task.launch()
    
    statusItem.image = statusImageRunning
    
    proxy.delegate = self
    
    _ = Timer.scheduledTimer(timeInterval: 0, target: self, selector: #selector(websocketConnect), userInfo: nil, repeats: false)
  }
  
  func websocketConnect() {
    proxy.connect()
  }
  
  func websocketDidConnect(socket: WebSocket) {
    NotificationCenter.default.post(name: Notification.Name.retrieveServiceURIs, object: nil)
  }
  
  func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
    // reconnect on failure after 1 second
    _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(websocketConnect), userInfo: nil, repeats: false)
  }
  
  func websocketDidReceiveMessage(socket: WebSocket, text: String) {
  }
  
  func websocketDidReceiveData(socket: WebSocket, data: Data) {
    do {
      let parsedData = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
      
      let type = parsedData["type"] as! String
      if type == "user_certificate" {
        
        var data = Data(base64Encoded: parsedData["public_key"] as! String)!
        
        let s = String(data:data, encoding: String.Encoding.utf8)!
          .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----\n", with: "")
          .replacingOccurrences(of: "-----END CERTIFICATE-----\n", with: "")

        data = Data(base64Encoded: s, options: .ignoreUnknownCharacters)!
        
        let certificate = KeychainCertificate(certificate: SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData)!)
        
        // save fingerprint
        let defaults = UserDefaults.standard
        
        var certificates: [String: Any]=[String: Any]()
      
        if let v = defaults.dictionary(forKey: "certificates") {
          certificates = v
        }
        
        let provider = parsedData["provider"] as! String
        deleteCertificates(forProvider: provider)
        
        var serviceCerts: [String] = []
        if let v = certificates[provider] {
          serviceCerts = v as! [String]
        }
        
        serviceCerts.append(certificate.fingerprint())
        certificates[provider] = serviceCerts
        
        defaults.set(certificates, forKey: "certificates")
        defaults.synchronize()
        
        NotificationManager.sharedManager().showNotification("KeyTalk", informativeText: "KeyTalk installed a new user certificate.")
      } else if type == "error" {
        NotificationManager.sharedManager().showNotification("KeyTalk", errorText: parsedData["error_message"]  as! String)
      } else if type == "receive-rccds" {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "receive-rccds"), object: parsedData["items"] as! [String])
        
        // retrieve services urls
        NotificationCenter.default.post(name: Notification.Name.retrieveServiceURIs, object: nil)
      } else if type == "receive-service-uris" {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "receive-service-uris"), object: parsedData["services"] as! [String])
      } else if type == "message" {
        NotificationManager.sharedManager().showNotification("KeyTalk", informativeText: parsedData["text"] as! String)
      }
    } catch let err as NSError {
      NSLog("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      dialogError(question: "KeyTalk Error", text: "\(err.localizedDescription)")
    }
  }
  
  func updateNotificationSentLabel(withNotification notification : NSNotification) {
    do {
      if notification.name == Notification.Name.retrieveRCCDs {
        try proxy.retrieveRCCDs()
      } else if notification.name == Notification.Name.retrieveServiceURIs {
        try proxy.retrieveServiceURIs()
      } else if notification.name == Notification.Name.receiveServiceURIs {
        let serviceURIs = notification.object as! [String]
        servicesMenu.removeAllItems()
        
        for serviceURI in self.getUniqueValues(forArray: serviceURIs) {
          servicesMenu.addItem(NSMenuItem(title: serviceURI, action: #selector(AppDelegate.startService(_:)), keyEquivalent: ""))
        }
      }
    } catch let err as NSError {
      print("Error \(err.code) in \(err.domain) : \(err.localizedDescription)")
      dialogError(question: "KeyTalk Error", text: "\(err.localizedDescription)")
    }
  }
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if(menuItem.action==#selector(AppDelegate.startAtLoginItem(_:))) {
      switch userDefaults.bool(forKey: "launchAtLogin") {
      case true:
        menuItem.state=NSOnState;
      case false:
        menuItem.state=NSOffState;
      }
      return true
    } else     if menuItem.action == #selector(AppDelegate.quit(_:)) {
      return true
    } else if menuItem.action == #selector(AppDelegate.openLog(_:)) {
      return true
    }
    
    if(menuItem ==  enableDisableProxyItem) {
      if isProxyEnabled() {
        enableDisableProxyItem.title = "De-activate KeyTalk Proxy Client"
        enableDisableProxyItem.action = #selector(AppDelegate.disableProxy(_:))
      } else {
        enableDisableProxyItem.title = "Activate KeyTalk Proxy Client"
        enableDisableProxyItem.action = #selector(AppDelegate.enableProxy(_:))
      }
    }
    
    return proxy.isConnected
  }
  
  @IBAction func startService(_ sender: NSMenuItem) {
    NSWorkspace.shared().open(URL(string:sender.title)!)
  }
  
  @IBAction func importRCCD(_ sender: NSMenuItem) {
    let rccdWindow = NSStoryboard(name: "RCCD", bundle: nil).instantiateInitialController() as! NSWindowController
    
    if let wordCountWindow = rccdWindow.window {
      let application = NSApplication.shared()
      application.runModal(for: wordCountWindow)
    }
  }
  
  func startAtLogin(enabled: Bool) {
    var url = Bundle.main.bundleURL
    
    url = url.appendingPathComponent("Contents", isDirectory: true)
    url = url.appendingPathComponent("Library", isDirectory: true)
    url = url.appendingPathComponent("LoginItems", isDirectory: true)
    url = url.appendingPathComponent("LaunchAtLoginHelperApp.app", isDirectory: false)
    
    if LSRegisterURL(url as CFURL, true)  != noErr {
      NSLog("KeyTalk LSRegisterURL failed")
    }
    
    let identifier = "com.keytalk.LaunchAtLoginHelperApp" as CFString
    
    userDefaults.set(enabled, forKey: "launchAtLogin")
    SMLoginItemSetEnabled(identifier, enabled)

    userDefaults.synchronize()
  }
  
  @IBAction func startAtLoginItem(_ sender: NSMenuItem) {
    switch sender.state {
    case 0:
      startAtLogin(enabled: true)
    default:
      startAtLogin(enabled: false)
    }
  }
  
  @IBAction func showAbout(_ sender: AnyObject) {
    let about = NSStoryboard(name: "About", bundle: nil).instantiateInitialController() as! NSWindowController
    
    let application = NSApplication.shared()
    application.runModal(for: about.window!)
  }
  
  func quit(_ sender: AnyObject) {
    NSApplication.shared().terminate(nil)
  }
}

