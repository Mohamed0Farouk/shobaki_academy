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
    
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
