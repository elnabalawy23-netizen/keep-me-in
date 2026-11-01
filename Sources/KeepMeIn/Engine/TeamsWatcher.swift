import AppKit

enum TeamsWatcher {
    /// New Teams is `com.microsoft.teams2`; classic Teams was `com.microsoft.teams`.
    private static let bundleIDs: Set<String> = ["com.microsoft.teams2", "com.microsoft.teams"]

    static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard let id = app.bundleIdentifier else { return false }
            return bundleIDs.contains(id)
        }
    }
}
