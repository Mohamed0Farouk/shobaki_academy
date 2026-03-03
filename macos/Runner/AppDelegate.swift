import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ notification: Notification) {
    
    if let window = NSApplication.shared.windows.first {
      window.setContentSize(NSSize(width: 1280, height: 720))
      window.minSize = NSSize(width: 1280, height: 720) // optional
      window.center()
      
      // If you want fixed size (no resizing), uncomment this:
      // window.styleMask.remove(.resizable)
    }

    //Method channel for open with picker

    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController

let channel = FlutterMethodChannel(
  name: "browser_picker",
  binaryMessenger: controller.engine.binaryMessenger
)

channel.setMethodCallHandler { (call, result) in
  
  if call.method == "openWithPicker" {
    
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result("Invalid arguments")
      return
    }

    let fileURL = URL(fileURLWithPath: path)
    var apps: [URL] = []

    if #available(macOS 12.0, *) {
      apps = NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
    } else {
      if let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: fileURL) {
        apps = [defaultApp]
      }
    }

    // ✅ فلترة المتصفحات فقط
    let allowedBrowsers = [
      "com.apple.Safari",
      "com.google.Chrome",
      "org.mozilla.firefox",
      "com.microsoft.edgemac"
    ]

    let browserApps = apps.filter { appURL in
      if let bundle = Bundle(url: appURL),
         let bundleID = bundle.bundleIdentifier {
        return allowedBrowsers.contains(bundleID)
      }
      return false
    }

    if browserApps.isEmpty {
      result("No browser found")
      return
    }

    let alert = NSAlert()
    alert.messageText = "Open With Browser"
    alert.informativeText = "Choose a browser"
    alert.alertStyle = .informational

    for app in browserApps {
      alert.addButton(withTitle: app.deletingPathExtension().lastPathComponent)
    }

    // ✅ إضافة زر Cancel
    alert.addButton(withTitle: "Cancel")

    // ✅ جعله sheet بدل modal blocking
    if let window = mainFlutterWindow {
      alert.beginSheetModal(for: window) { response in
        
        let index = response.rawValue - 1000
        
        if index >= 0 && index < browserApps.count {
          let selectedApp = browserApps[index]
          
          NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: selectedApp,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
          )
        }

        result("done")
      }
    }
  }
}
    
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
