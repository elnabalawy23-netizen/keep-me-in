import AppKit
import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: ActivityEngine
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Toggle(isOn: $settings.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep me available").font(.headline)
                    Text(settings.isEnabled ? "Nudging whenever you go quiet" : "Not doing anything right now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if engine.status == .needsAccessibility {
                Callout(tint: .orange, symbol: "hand.raised.fill",
                        title: "Accessibility access needed",
                        message: "macOS only lets trusted apps simulate input. In Privacy & Security → Accessibility, switch Keep Me In on. If it is already listed and on, that entry belongs to an older build: select it, press −, then press + and add the app again.") {
                    Button("Grant access…") { engine.requestAccessibility() }
                    Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                    Button("Show app in Finder") { Permissions.revealAppInFinder() }
                }
            } else if engine.lastActionFailed && engine.status.isWorking {
                Callout(tint: .red, symbol: "exclamationmark.triangle.fill",
                        title: "Nudges aren't registering",
                        message: "Usually a stale Accessibility entry after a rebuild. Remove Keep Me In from the Accessibility list and add it again.") {
                    Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                }
            }

            Divider()
            stats
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Nudge after being idle for").font(.caption).foregroundStyle(.secondary)
                Picker("Interval", selection: $settings.intervalSeconds) {
                    Text("30s").tag(30.0)
                    Text("1m").tag(60.0)
                    Text("2m").tag(120.0)
                    Text("4m").tag(240.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            HStack {
                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: engine.menuBarSymbol)
                .font(.system(size: 28))
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep Me In").font(.title3.bold())
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(engine.status.title).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var stats: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            row("Idle", Formatting.duration(engine.realIdle))
            row("Next nudge", engine.nextActionIn.map(Formatting.duration) ?? "—")
            row("Last nudge", engine.lastActionAt.map(Formatting.time.string) ?? "Not yet")
            row("Today", "\(engine.actionsToday) nudge\(engine.actionsToday == 1 ? "" : "s")")
            row("Teams", engine.teamsRunning ? "Running" : "Not running")
            row("Display", engine.isHoldingDisplay ? "Kept awake" : "System default")
        }
        .font(.callout)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit().gridColumnAlignment(.trailing)
        }
    }

    private var statusColor: Color {
        if engine.lastActionFailed && engine.status.isWorking { return .red }
        switch engine.status {
        case .disabled: return .gray
        case .needsAccessibility: return .orange
        case .outsideSchedule, .teamsNotRunning, .screenLocked: return .yellow
        case .userActive, .keepingAlive: return .green
        }
    }
}

private struct Callout<Actions: View>: View {
    let tint: Color
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.subheadline.bold()).foregroundStyle(tint)
            Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack { actions }.controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
