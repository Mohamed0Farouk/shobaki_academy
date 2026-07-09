import Cocoa
import Foundation

// MARK: - Recording App Blacklist (executable names only, macOS)
// Each entry is the executable name (without .app) lowercased.
// Examples: "obs" matches OBS.app, "quicktime player" matches QuickTime Player.app
private let recordingAppNames: Set<String> = [
    // Professional Recording Software
    "obs",
    "screenflow",
    "camtasia",
    "snagit",
    "loom",
    "screencast-o-matic",
    "screenstudio",

    // Lightweight Recording Tools
    "kap",
    "cleanshot",
    "cleanshot x",
    "monosnap",
    "screenflick",
    "giphy capture",

    // Cloud & Sharing Tools
    "cloudapp",
    "recordit",
    "droplr",

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
private var detectedApps: [String] = []

// MARK: - Main Detection Functions

/// Check if any recording software is currently running
public func isRecordingSoftwareRunning() -> Bool {
    detectedApps.removeAll()

    // Check running applications by executable name
    for app in NSWorkspace.shared.runningApplications {
        guard let execURL = app.executableURL else { continue }
        let execName = execURL.lastPathComponent
        let nameOnly = execName.hasSuffix(".app")
            ? String(execName.dropLast(4))
            : execName
        let lower = nameOnly.lowercased()

        if recordingAppNames.contains(lower) {
            if !detectedApps.contains(nameOnly) {
                detectedApps.append(nameOnly)
            }
        }
    }

    // Native screen recording detection (screencaptureui)
    if detectNativeScreenRecording() {
        if !detectedApps.contains("screencaptureui") {
            detectedApps.append("screencaptureui")
        }
    }

    return !detectedApps.isEmpty
}

/// Get the name of the first detected recording application
public func getDetectedRecordingApp() -> String {
    _ = isRecordingSoftwareRunning()
    return detectedApps.first ?? ""
}

/// Get all detected recording application names
public func getDetectedRecordingApps() -> [String] {
    _ = isRecordingSoftwareRunning()
    return detectedApps
}

/// Force close a specific recording application by executable name
public func closeDetectedApp(_ appName: String) {
    if appName.isEmpty { return }

    for app in NSWorkspace.shared.runningApplications {
        guard let execURL = app.executableURL else { continue }
        let execName = execURL.lastPathComponent
        let nameOnly = execName.hasSuffix(".app")
            ? String(execName.dropLast(4))
            : execName
        if nameOnly == appName {
            app.forceTerminate()
            return
        }
    }
}

/// Force close all detected recording applications
public func closeAllDetectedApps() {
    for appName in detectedApps {
        closeDetectedApp(appName)
    }
}

// MARK: - Detection Methods

/// Detect native macOS screen recording by checking for screencaptureui process
/// screencaptureui is launched when user presses Command+Shift+5
private func detectNativeScreenRecording() -> Bool {
    for app in NSWorkspace.shared.runningApplications {
        guard let execURL = app.executableURL else { continue }
        let execName = execURL.lastPathComponent.lowercased()
        if execName.contains("screencaptureui") {
            return true
        }
    }
    return false
}