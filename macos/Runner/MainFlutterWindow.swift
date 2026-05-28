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
        result(self.isRecordingSoftwareRunning())
      case "getDetectedApp":
        result(self.getDetectedRecordingApp())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  private func isRecordingSoftwareRunning() -> Bool {
    let suspiciousApps = [
      "OBS",
      "QuickTime Player",
      "ScreenFlow",
      "Camtasia",
      "Loom",
    ]

    let runningApps = NSWorkspace.shared.runningApplications

    for app in runningApps {
      if let name = app.localizedName {
        if suspiciousApps.contains(where: {
          name.localizedCaseInsensitiveContains($0)
        }) {
          return true
        }
      }
    }

    return false
  }

  private func getDetectedRecordingApp() -> String {
    let suspiciousApps = [
      "OBS",
      "QuickTime Player",
      "ScreenFlow",
      "Camtasia",
      "Loom",
    ]

    let runningApps = NSWorkspace.shared.runningApplications

    for app in runningApps {
      if let name = app.localizedName {
        if suspiciousApps.contains(where: {
          name.localizedCaseInsensitiveContains($0)
        }) {
          return name
        }
      }
    }

    return "None"
  }
}
