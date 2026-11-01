import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ScheduleSettingsTab()
                .tabItem { Label("Schedule", systemImage: "calendar.badge.clock") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

struct GeneralSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: ActivityEngine
    @EnvironmentObject private var updater: Updater

    var body: some View {
        Form {
            Section("How to nudge") {
                Picker("Method", selection: $settings.mode) {
                    ForEach(ActivityMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text(settings.mode.detail).font(.caption).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $settings.intervalSeconds, in: 15...240, step: 15) {
                        Text("After idle for")
                    } minimumValueLabel: {
                        Text("15s")
                    } maximumValueLabel: {
                        Text("4m")
                    }
                    Text("Nudges once you've been idle for \(Formatting.duration(settings.intervalSeconds)). Teams shows Away after \(Formatting.duration(AppSettings.teamsAwayThreshold)), so anything below that keeps you green.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("When to run") {
                Toggle("Keep the display awake while active", isOn: $settings.keepDisplayAwake)
                Toggle("Only while Microsoft Teams is running", isOn: $settings.onlyWhenTeamsRunning)
                Toggle("Pause while the screen is locked", isOn: $settings.pauseWhenScreenLocked)
            }

            Section("Updates") {
                Picker("Check for updates", selection: $settings.updateCheckDays) {
                    Text("Daily").tag(1)
                    Text("Weekly").tag(7)
                    Text("Never").tag(0)
                }
                Toggle("Install updates automatically", isOn: $settings.autoInstallUpdates)
                LabeledContent("Installed version") {
                    Text("\(updater.currentVersion)\(updater.installedAt.map { ", updated \(Formatting.relativeDay($0))" } ?? "")")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Last checked") {
                    Text(updater.lastCheckedAt.map(Formatting.dateTime.string) ?? "Never").foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button("Check now") { Task { await updater.check(installIfFound: false) } }
                        .disabled(updater.state == .checking)
                    if case .available(let v) = updater.state {
                        Button("Update to \(v) now") { Task { await updater.install() } }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Text(updateStatusText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Link("Releases", destination: Updater.releasesPage).font(.caption)
                }
            }

            Section("System") {
                LaunchAtLoginToggle()
                LabeledContent("Accessibility access") {
                    if engine.accessibilityGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        HStack {
                            Button("Grant…") { engine.requestAccessibility() }
                            Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updateStatusText: String {
        switch updater.state {
        case .idle: return ""
        case .checking: return "Checking…"
        case .upToDate: return "You're on the latest version."
        case .available(let v): return "Version \(v) is available."
        case .downloading(let v): return "Downloading \(v)…"
        case .installing(let v): return "Installing \(v), the app will relaunch."
        case .failed(let message): return message
        }
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var enabled = LoginItem.isEnabled
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at login", isOn: Binding(
                get: { enabled },
                set: { newValue in
                    do {
                        try LoginItem.set(newValue)
                        errorText = nil
                    } catch {
                        errorText = error.localizedDescription
                    }
                    enabled = LoginItem.isEnabled
                }
            ))
            if LoginItem.requiresApproval {
                Text("Approve Keep Me In under System Settings → General → Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }
        }
    }
}

struct ScheduleSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings
    private let symbols = Calendar.current.shortWeekdaySymbols // index 0 = Sunday

    var body: some View {
        Form {
            Section {
                Toggle("Only keep me available on a schedule", isOn: $settings.scheduleEnabled)
            } footer: {
                Text("Outside these hours the app stays idle and lets Teams show your real status.")
            }

            Section("Hours") {
                DatePicker("From", selection: startBinding, displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: endBinding, displayedComponents: .hourAndMinute)
                if settings.scheduleStartMinutes > settings.scheduleEndMinutes {
                    Text("This window runs past midnight.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(!settings.scheduleEnabled)

            Section("Days") {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(symbols[day - 1], isOn: weekdayBinding(day))
                            .toggleStyle(.button)
                    }
                }
                if settings.scheduleWeekdays.isEmpty {
                    Text("No days selected, so the app will never run.").font(.caption).foregroundStyle(.red)
                }
            }
            .disabled(!settings.scheduleEnabled)
        }
        .formStyle(.grouped)
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { Formatting.minutesToDate(settings.scheduleStartMinutes) },
            set: { settings.scheduleStartMinutes = Formatting.dateToMinutes($0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { Formatting.minutesToDate(settings.scheduleEndMinutes) },
            set: { settings.scheduleEndMinutes = Formatting.dateToMinutes($0) }
        )
    }

    private func weekdayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { settings.scheduleWeekdays.contains(day) },
            set: { on in
                if on { settings.scheduleWeekdays.insert(day) } else { settings.scheduleWeekdays.remove(day) }
            }
        )
    }
}

struct AboutTab: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading) {
                    Text("Keep Me In").font(.title2.bold())
                    Text("Version \(version)").foregroundStyle(.secondary)
                }
            }

            Text("Keeps your Microsoft Teams presence on Available by posting a tiny, invisible bit of input whenever you've been quiet for a while, and keeps the display awake so the Mac never locks itself.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Teams marks you Away after 5 minutes without keyboard or mouse input.")
                bullet("Keep Me In watches the same idle clock and nudges before that happens.")
                bullet("While you're typing or moving the mouse it does nothing at all.")
                bullet("Nothing is sent anywhere and nothing is logged beyond a counter.")
            }
            .font(.callout)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
