import Cocoa
import Foundation

private let recordingAppNames: Set<String> = [
    "obs",
    "screenflow",
    "camtasia",
    "snagit",
    "screenflick",
    "quicktime player",
    "kap",
    "giphy capture",
    "clean shot",
    "monosnap",
    "cloudapp",
    "recordit",
    "screencast-o-matic",
]

private var detectedApp = ""

func isRecordingSoftwareRunning() -> Bool {
    for app in NSWorkspace.shared.runningApplications {
        guard let name = app.localizedName?.lowercased() else { continue }
        if recordingAppNames.contains(where: { name.contains($0) }) {
            detectedApp = app.localizedName ?? ""
            return true
        }
    }
    detectedApp = ""
    return false
}

func getDetectedRecordingApp() -> String {
    return detectedApp
}
