import Cocoa
import FlutterMacOS

/// Screen-capture exclusion is the shipping default (`.none`). The diagnostics
/// experiment can switch this to `.readOnly`, which is the ordinary AppKit
/// window (there is no `.normal`). The key-window observer has to follow the
/// same value, or the next focus change silently puts the exclusion back.
private var shobakiWindowSharing: NSWindow.SharingType = .none

private func applyShobakiWindowSharing() {
  NSApplication.shared.windows.forEach { $0.sharingType = shobakiWindowSharing }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    applyShobakiWindowSharing()
    NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: nil,
        queue: .main
    ) { notification in
        (notification.object as? NSWindow)?.sharingType = shobakiWindowSharing
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
      case "setSharingType":
        // Diagnostics only. "normal" is `.readOnly` (AppKit's default sharing);
        // anything else, including "none", restores the capture exclusion.
        let mode = call.arguments as? String ?? "none"
        shobakiWindowSharing = (mode == "normal") ? .readOnly : .none
        applyShobakiWindowSharing()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}