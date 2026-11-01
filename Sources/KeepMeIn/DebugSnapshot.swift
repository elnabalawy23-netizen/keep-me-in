import AppKit
import SwiftUI

/// Developer aid: `KEEPMEIN_SNAPSHOT_DIR=/some/dir .build/debug/KeepMeIn` renders every screen to PNG and exits.
/// Lets the UI be reviewed on machines where screenshots are not possible.
enum DebugSnapshot {
    static var isRequested: Bool { ProcessInfo.processInfo.environment["KEEPMEIN_SNAPSHOT_DIR"] != nil }

    @MainActor
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["KEEPMEIN_SNAPSHOT_DIR"] else { return }
        let outDir = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let settings = AppSettings.shared
        let engine = ActivityEngine(settings: settings)
        let updater = Updater(settings: settings)

        func env<V: View>(_ view: V) -> some View {
            view.environmentObject(settings).environmentObject(engine).environmentObject(updater)
        }

        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            write(env(MenuPanelView()), appearance: appearance, to: outDir.appendingPathComponent("menu-panel-\(name).png"))
            write(env(GeneralSettingsTab()).frame(width: 460), appearance: appearance, to: outDir.appendingPathComponent("settings-general-\(name).png"))
            write(env(ScheduleSettingsTab()).frame(width: 460), appearance: appearance, to: outDir.appendingPathComponent("settings-schedule-\(name).png"))
            write(env(AboutTab()).frame(width: 460), appearance: appearance, to: outDir.appendingPathComponent("settings-about-\(name).png"))
        }
        print("Snapshots written to \(outDir.path)")
        exit(0)
    }

    @MainActor
    private static func write<V: View>(_ view: V, appearance: NSAppearance.Name, to url: URL) {
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hosting.appearance = NSAppearance(named: appearance)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        // Let SwiftUI flush pending platform-view updates (switch states etc.) before capturing.
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
