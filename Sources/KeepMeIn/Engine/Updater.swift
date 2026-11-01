import AppKit
import Foundation
import Security
import os

/// Checks GitHub Releases for a newer build, downloads it, verifies it is signed with the same certificate as
/// the running app, swaps the bundle in place and relaunches.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case downloading(String)
        case installing(String)
        case failed(String)
    }

    enum UpdateError: LocalizedError {
        case badResponse
        case noAsset
        case signature(String)
        case tool(String, Int32)

        var errorDescription: String? {
            switch self {
            case .badResponse: return "GitHub did not return a release."
            case .noAsset: return "The release has no KeepMeIn-*.zip asset."
            case .signature(let why): return "Downloaded app rejected: \(why)"
            case .tool(let name, let code): return "\(name) failed (\(code))."
            }
        }
    }

    static let repo = "elnabalawy23-netizen/keep-me-in"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckedAt: Date?
    /// First launch time of the version currently running, i.e. when the last update (or install) happened.
    @Published private(set) var installedAt: Date?
    @Published private(set) var latestVersion: String?

    let currentVersion: String

    private let settings: AppSettings
    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "com.omarelnabalawy.KeepMeIn", category: "updater")
    private var latestAssetURL: URL?
    private var timer: Timer?

    private enum Key {
        static let lastChecked = "updateLastCheckedAt"
        static let installedAt = "updateInstalledAt"
        static let lastRunVersion = "updateLastRunVersion"
    }

    /// True when running from a real .app bundle (not `swift run`).
    private var isBundled: Bool { Bundle.main.bundlePath.hasSuffix(".app") }

    init(settings: AppSettings) {
        self.settings = settings
        let env = ProcessInfo.processInfo.environment
        currentVersion = env["KEEPMEIN_FAKE_VERSION"]
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
        lastCheckedAt = defaults.object(forKey: Key.lastChecked) as? Date
        installedAt = defaults.object(forKey: Key.installedAt) as? Date

        if defaults.string(forKey: Key.lastRunVersion) != currentVersion {
            // A different version is running for the first time: that is when the update landed.
            defaults.set(currentVersion, forKey: Key.lastRunVersion)
            installedAt = Date()
            defaults.set(installedAt, forKey: Key.installedAt)
        }

        guard !DebugSnapshot.isRequested else { return }
        let delay = Double(env["KEEPMEIN_UPDATE_CHECK_DELAY"] ?? "") ?? 20
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.checkIfDue() }
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkIfDue() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Scheduling

    func checkIfDue() {
        guard isBundled, settings.updateCheckDays > 0 else { return }
        if let last = lastCheckedAt,
           Date().timeIntervalSince(last) < Double(settings.updateCheckDays) * 86_400,
           ProcessInfo.processInfo.environment["KEEPMEIN_UPDATE_CHECK_DELAY"] == nil {
            return
        }
        Task { await check(installIfFound: settings.autoInstallUpdates) }
    }

    // MARK: - Check

    func check(installIfFound: Bool) async {
        switch state {
        case .checking, .downloading, .installing: return
        default: break
        }
        state = .checking
        do {
            let (version, assetURL) = try await fetchLatestRelease()
            recordCheck()
            latestVersion = version
            latestAssetURL = assetURL
            if Self.isVersion(version, newerThan: currentVersion) {
                log.info("Update available: \(version, privacy: .public) (running \(self.currentVersion, privacy: .public))")
                state = .available(version)
                if installIfFound { await install() }
            } else {
                state = .upToDate
            }
        } catch {
            recordCheck()
            log.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    private func recordCheck() {
        lastCheckedAt = Date()
        defaults.set(lastCheckedAt, forKey: Key.lastChecked)
    }

    private func fetchLatestRelease() async throws -> (version: String, asset: URL) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("KeepMeIn/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { throw UpdateError.badResponse }

        let assets = json["assets"] as? [[String: Any]] ?? []
        guard let urlString = assets
            .first(where: { ($0["name"] as? String)?.hasPrefix("KeepMeIn-") == true && ($0["name"] as? String)?.hasSuffix(".zip") == true })?["browser_download_url"] as? String,
              let url = URL(string: urlString)
        else { throw UpdateError.noAsset }

        return (tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url)
    }

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Install

    func install() async {
        guard let version = latestVersion, let assetURL = latestAssetURL, isBundled else { return }
        state = .downloading(version)
        do {
            let fm = FileManager.default
            let bundleURL = Bundle.main.bundleURL
            // Same volume as the bundle so the final swap is an atomic rename.
            let work = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: bundleURL, create: true)
            defer { try? fm.removeItem(at: work) }

            let (downloaded, _) = try await URLSession.shared.download(from: assetURL)
            let zip = work.appendingPathComponent("update.zip")
            try fm.moveItem(at: downloaded, to: zip)

            let unzipped = work.appendingPathComponent("unzipped", isDirectory: true)
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, unzipped.path])
            guard let newApp = try fm.contentsOfDirectory(at: unzipped, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }) else { throw UpdateError.noAsset }
            try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            try verifySignature(of: newApp)

            state = .installing(version)
            try swapBundle(at: bundleURL, with: newApp)
            log.info("Installed \(version, privacy: .public); relaunching")
            relaunch(bundleURL)
        } catch {
            log.error("Update failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    /// The downloaded bundle must satisfy the running app's designated requirement: same identifier, same
    /// signing certificate. Anything else is refused, however it got into the release.
    private func verifySignature(of app: URL) throws {
        var selfCode: SecCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode else {
            throw UpdateError.signature("cannot inspect the running app")
        }
        var selfStatic: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic else {
            throw UpdateError.signature("cannot inspect the running app")
        }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess, let requirement else {
            throw UpdateError.signature("the running app has no designated requirement")
        }
        var newCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &newCode) == errSecSuccess, let newCode else {
            throw UpdateError.signature("cannot read its code signature")
        }
        let status = SecStaticCodeCheckValidity(newCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement)
        guard status == errSecSuccess else {
            throw UpdateError.signature("not signed by the same certificate as this app (\(status))")
        }
    }

    private func swapBundle(at current: URL, with newApp: URL) throws {
        let fm = FileManager.default
        let parked = current.deletingLastPathComponent().appendingPathComponent(".\(current.lastPathComponent).previous")
        try? fm.removeItem(at: parked)
        try fm.moveItem(at: current, to: parked)
        do {
            try fm.moveItem(at: newApp, to: current)
        } catch {
            try? fm.moveItem(at: parked, to: current)
            throw error
        }
        try? fm.removeItem(at: parked)
    }

    private func relaunch(_ bundleURL: URL) {
        let script = "sleep 1; /usr/bin/open \"$0\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw UpdateError.tool((tool as NSString).lastPathComponent, task.terminationStatus) }
    }
}
