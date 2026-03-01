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
        let apps = NSWorkspace.shared.urlsForApplications(toOpen: fileURL)

        let alert = NSAlert()
        alert.messageText = "Open With"
        alert.informativeText = "Choose application"
        alert.alertStyle = .informational

        for app in apps {
          alert.addButton(withTitle: app.deletingPathExtension().lastPathComponent)
        }

        let response = alert.runModal()
        let index = response.rawValue - 1000

        if index >= 0 && index < apps.count {
          let selectedApp = apps[index]
          
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
    
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
