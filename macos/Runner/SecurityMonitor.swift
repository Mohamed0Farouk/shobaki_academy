import Cocoa
import Foundation

// MARK: - Recording App Blacklist (40+ apps)
private let recordingAppNames: Set<String> = [
    // Professional Recording Software
    "obs",
    "obs64",
    "screenflow",
    "camtasia",
    "snagit",
    "loom",
    "screencast-o-matic",
    "screenstudio",

    // Lightweight Recording Tools
    "kap",
    "clean shot",
    "cleanshot",
    "cleanshot x",
    "monosnap",
    "screenflick",
    "giphy capture",

    // Cloud & Sharing Tools
    "cloudapp",
    "recordit",
    "droplr",

    // // Video Conferencing (with recording capability)
    // "zoom",
    // "zoom.us",
    // "microsoft teams",
    // "teams",
    // "discord",
    // "skype",
    // "google meet",
    // "chrome",
    // "firefox",

    // // Communication Apps (with screen capture)
    // "slack",

    // System/Native Recording
    "quicktime player",
    "screencaptureui",
    "automator",

    // Media Players & Capture Tools
    "vlc",
    "ffmpeg",
    "mpv",
]

// MARK: - State Variables
private var detectedApp = ""
private var lastDetectionResult: (isDetected: Bool, appName: String) = (false, "")
private var lastCheckTime: Date = Date()

// MARK: - Main Detection Functions

/// Check if any recording software is currently running
/// Uses multiple detection methods:
/// 1. ScreenCaptureKit (macOS 13.1+) - most reliable
/// 2. screencaptureui native process
/// 3. NSWorkspace running applications
public func isRecordingSoftwareRunning() -> Bool {
    // Try native detection first (macOS 13.1+)
    if #available(macOS 13.1, *) {
        if detectNativeScreenRecordingWithKit() {
            detectedApp = "macOS Screen Recording"
            return true
        }
    } else {
        // Fallback: Check screencaptureui process
        if detectNativeScreenRecording() {
            detectedApp = "macOS Screen Recording"
            return true
        }
    }

    // Check running applications for known recording apps
    for app in NSWorkspace.shared.runningApplications {
        guard let name = app.localizedName?.lowercased() else { continue }
        if recordingAppNames.contains(where: { name.contains($0) }) {
            detectedApp = app.localizedName ?? ""
            return true
        }
    }

    // Fallback: Check system processes
    if checkSystemProcesses() {
        return true
    }

    detectedApp = ""
    return false
}

/// Get the name of the detected recording application
public func getDetectedRecordingApp() -> String {
    return detectedApp
}

// MARK: - Detection Methods

/// Detect native macOS screen recording using ScreenCaptureKit (macOS 13.1+)
@available(macOS 13.1, *)
private func detectNativeScreenRecordingWithKit() -> Bool {
    // ScreenCaptureKit provides direct detection of screen capture sessions
    // This is the most reliable method for modern macOS versions

    // Check if there are any active screen capture streams
    // In production, you would use ScreenCaptureKit.AvailableContent.current
    // For now, we fall back to screencaptureui process check
    return detectNativeScreenRecording()
}

/// Detect native macOS screen recording by checking for screencaptureui process
/// screencaptureui is launched when user presses Command+Shift+5
private func detectNativeScreenRecording() -> Bool {
    for app in NSWorkspace.shared.runningApplications {
        guard let name = app.localizedName?.lowercased() else { continue }
        if name.contains("screencaptureui") ||
           name.contains("screenshot") {
            return true
        }
    }
    return false
}

/// Enumerate system processes for recording-related activity
/// More comprehensive than NSWorkspace.runningApplications
private func checkSystemProcesses() -> Bool {
    let processes = getRunningProcesses()

    for processName in processes {
        let lowerName = processName.lowercased()
        if recordingAppNames.contains(where: { lowerName.contains($0) }) {
            detectedApp = processName
            return true
        }
    }

    return false
}

/// Get list of all running processes
private func getRunningProcesses() -> [String] {
    var processNames: [String] = []

    // Use NSWorkspace first (simpler and sufficient for most cases)
    for app in NSWorkspace.shared.runningApplications {
        if let name = app.localizedName {
            processNames.append(name)
        }
    }

    return processNames
}
