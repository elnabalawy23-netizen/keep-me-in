import AppKit
import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: ActivityEngine
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 26)
            statusBlock
                .padding(.bottom, 14)
            stats
                .padding(.bottom, 20)

            if engine.status == .needsAccessibility {
                accessibilityCard.padding(.bottom, 16)
            } else if engine.lastActionFailed && engine.status.isWorking {
                failureCard.padding(.bottom, 16)
            }

            sessionButton
                .padding(.bottom, 18)
            optionsCard
                .padding(.bottom, 8)
            stopAfterRow
            separator
            launchAtLoginRow
            separator
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .frame(width: 400)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                Image(systemName: "cup.and.heat.waves.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 44, height: 44)

            Text("Keep Me In")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)

            Spacer()

            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.icon)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    // MARK: Status

    private var statusBlock: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Circle().fill(statusColor).frame(width: 10, height: 10)
                    Text(statusTitle)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                }
                Text(Formatting.clock(engine.sessionElapsed))
                    .font(.system(size: 54, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "cup.and.heat.waves.fill")
                .font(.system(size: 66))
                .foregroundStyle(Theme.accent)
                .padding(.trailing, 8)
        }
    }

    private var stats: some View {
        HStack(spacing: 32) {
            stat("Idle for", Formatting.clock(engine.realIdle))
            stat("Last nudge", engine.lastActionAt.map(Formatting.time.string) ?? "Not yet")
            Spacer()
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        }
    }

    private var statusTitle: String {
        switch engine.status {
        case .disabled: return "Session paused"
        case .needsAccessibility: return "Waiting for Accessibility access"
        case .outsideSchedule: return "Outside your schedule"
        case .teamsNotRunning: return "Waiting for Teams"
        case .screenLocked: return "Paused while screen is locked"
        case .userActive, .keepingAlive: return "Session active"
        }
    }

    private var statusColor: Color {
        switch engine.status {
        case .disabled: return Theme.muted
        case .needsAccessibility, .outsideSchedule, .teamsNotRunning, .screenLocked: return Theme.warning
        case .userActive, .keepingAlive: return engine.lastActionFailed ? Theme.danger : Theme.accent
        }
    }

    private var subtitle: String {
        guard settings.isEnabled else { return "Not keeping you in right now" }
        switch engine.status {
        case .needsAccessibility: return "Grant access below to start"
        case .outsideSchedule, .teamsNotRunning, .screenLocked: return "Resumes automatically"
        default: break
        }
        var text: String
        switch (settings.keepDisplayAwake, settings.nudgeEnabled) {
        case (true, true): text = "Keeping your Mac awake"
        case (true, false): text = "Keeping the display awake only"
        case (false, true): text = "Keeping you available"
        case (false, false): text = "Turn on an option below"
        }
        if let endsAt = engine.sessionEndsAt {
            text += " · stops at \(Formatting.shortTime.string(from: endsAt))"
        }
        return text
    }

    // MARK: Callouts

    private var accessibilityCard: some View {
        InfoCard(tint: Theme.warning, symbol: "hand.raised.fill",
                 title: "Accessibility access needed",
                 message: "macOS only lets trusted apps simulate input. In Privacy & Security → Accessibility, switch Keep Me In on. If it is already listed and on, that entry belongs to an older build: select it, press −, then press + and add the app again.") {
            PillButton("Grant access…") { engine.requestAccessibility() }
            PillButton("System Settings") { Permissions.openAccessibilitySettings() }
            PillButton("Show in Finder") { Permissions.revealAppInFinder() }
        }
    }

    private var failureCard: some View {
        InfoCard(tint: Theme.danger, symbol: "exclamationmark.triangle.fill",
                 title: "Nudges aren't registering",
                 message: "Usually a stale Accessibility entry. Remove Keep Me In from the list and add it again.") {
            PillButton("System Settings") { Permissions.openAccessibilitySettings() }
        }
    }

    // MARK: Session button

    private var sessionButton: some View {
        Button {
            settings.isEnabled.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: settings.isEnabled ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(settings.isEnabled ? "Pause session" : "Resume session")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Options

    private var optionsCard: some View {
        VStack(spacing: 0) {
            toggleRow(symbol: "display", title: "Keep Mac awake", isOn: $settings.keepDisplayAwake)
            separator
            toggleRow(symbol: settings.mode == .mouse ? "computermouse" : "keyboard",
                      title: settings.mode == .mouse ? "Move mouse" : "Tap F15 key",
                      isOn: $settings.nudgeEnabled)
            HStack {
                Text("Move every")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 40)
                Spacer()
                DropdownMenu(title: intervalLabel(settings.intervalSeconds),
                             options: AppSettings.intervalChoices.map { value in
                                 DropdownOption(title: intervalLabel(value)) { settings.intervalSeconds = value }
                             })
            }
            .padding(.top, 2)
            .padding(.bottom, 14)
            .opacity(settings.nudgeEnabled ? 1 : 0.45)
            .disabled(!settings.nudgeEnabled)
        }
        .padding(.horizontal, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleRow(symbol: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Theme.icon)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(AccentSwitchStyle())
        }
        .frame(height: 50)
    }

    private var stopAfterRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundStyle(Theme.icon)
                .frame(width: 26)
            Text("Stop after")
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer()
            DropdownMenu(title: stopAfterLabel(settings.stopAfterMinutes),
                         options: AppSettings.stopAfterChoices.map { minutes in
                             DropdownOption(title: stopAfterLabel(minutes)) { settings.stopAfterMinutes = minutes }
                         })
        }
        .frame(height: 58)
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "person")
                .font(.system(size: 18))
                .foregroundStyle(Theme.icon)
                .frame(width: 26)
            Text("Launch at login")
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            Spacer()
            LaunchAtLoginSwitch()
        }
        .frame(height: 58)
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Spacer()
            Rectangle().fill(Theme.separator).frame(width: 1, height: 22)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .keyboardShortcut("q")
        }
        .frame(height: 44)
    }

    private var separator: some View {
        Rectangle().fill(Theme.separator).frame(height: 1)
    }

    private func intervalLabel(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s < 120 ? "\(s) seconds" : "\(s / 60) minutes"
    }

    private func stopAfterLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "Until stopped"
        case ..<60: return "\(minutes) minutes"
        case 60: return "1 hour"
        default: return "\(minutes / 60) hours"
        }
    }
}

// MARK: - Pieces

struct DropdownOption {
    let title: String
    let action: () -> Void
}

/// A compact dark pill that opens a native menu. Drawn by us so it matches the panel exactly.
private struct DropdownMenu: View {
    let title: String
    let options: [DropdownOption]

    var body: some View {
        Button(action: present) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.icon)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func present() {
        let menu = NSMenu()
        let target = MenuTarget()
        for option in options {
            let item = NSMenuItem(title: option.title, action: #selector(MenuTarget.fire(_:)), keyEquivalent: "")
            item.target = target
            item.representedObject = MenuAction(option.action)
            item.state = option.title == title ? .on : .off
            menu.addItem(item)
        }
        // popUp blocks until the menu closes, so the target only needs to live for this call.
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        withExtendedLifetime(target) {}
    }
}

private final class MenuAction: NSObject {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

private final class MenuTarget: NSObject {
    @objc func fire(_ sender: NSMenuItem) {
        (sender.representedObject as? MenuAction)?.run()
    }
}

/// Tan switch with a white knob, sized like the mockup. Pure SwiftUI so it looks the same whether or not the
/// panel is the key window (AppKit switches drop their colour when it isn't).
struct AccentSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { configuration.isOn.toggle() }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(configuration.isOn ? Theme.accent.opacity(0.88) : Color.white.opacity(0.16))
                    .frame(width: 48, height: 28)
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .padding(2)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LaunchAtLoginSwitch: View {
    @State private var enabled = LoginItem.isEnabled

    var body: some View {
        Toggle("", isOn: Binding(
            get: { enabled },
            set: { newValue in
                try? LoginItem.set(newValue)
                enabled = LoginItem.isEnabled
            }
        ))
        .labelsHidden()
        .toggleStyle(AccentSwitchStyle())
        .onAppear { enabled = LoginItem.isEnabled }
    }
}

private struct InfoCard<Actions: View>: View {
    let tint: Color
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) { actions }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PillButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.control, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
