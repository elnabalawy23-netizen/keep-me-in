import AppKit
import SwiftUI

@main
struct KeepMeInApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var engine = ActivityEngine(settings: AppSettings.shared)
    @StateObject private var updater = Updater(settings: AppSettings.shared)

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(settings)
                .environmentObject(engine)
                .environmentObject(updater)
        } label: {
            Image(systemName: engine.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(engine)
                .environmentObject(updater)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only. The bundle's LSUIElement already does this, but `swift run` has no Info.plist.
        NSApp.setActivationPolicy(.accessory)
        DebugSnapshot.runIfRequested()
    }
}
