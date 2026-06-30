import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.sharingType = .none

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
      case "closeDetectedApp":
        if let appName = call.arguments as? String {
          closeDetectedApp(appName)
        }
        result(nil)
      case "closeAllDetectedApps":
        closeAllDetectedApps()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}