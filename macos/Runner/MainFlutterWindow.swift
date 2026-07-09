import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    NSApplication.shared.windows.forEach { $0.sharingType = .none }
    NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: nil,
        queue: .main
    ) { notification in
        (notification.object as? NSWindow)?.sharingType = .none
    }

    let channel = FlutterMethodChannel(
      name: "shobaki/security",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isRecordingDetected":
        result(isRecordingSoftwareRunning())
      case "getDetectedApp":
        result(getDetectedRecordingApp())
      case "getDetectedApps":
        result(getDetectedRecordingApps())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}