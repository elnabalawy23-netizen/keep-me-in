import AppKit
import Combine
import Foundation
import os

/// Ticks once a second, decides whether a nudge is due, and publishes everything the UI shows.
@MainActor
final class ActivityEngine: ObservableObject {
    enum Status: Equatable {
        case disabled
        case needsAccessibility
        case outsideSchedule
        case teamsNotRunning
        case screenLocked
        case userActive
        case keepingAlive

        var title: String {
            switch self {
            case .disabled: return "Paused"
            case .needsAccessibility: return "Needs Accessibility access"
            case .outsideSchedule: return "Outside your schedule"
            case .teamsNotRunning: return "Waiting for Teams to open"
            case .screenLocked: return "Paused while screen is locked"
            case .userActive: return "You're active"
            case .keepingAlive: return "Keeping you available"
            }
        }

        /// True when the engine would nudge if the idle clock ran out.
        var isWorking: Bool { self == .userActive || self == .keepingAlive }
    }

    @Published private(set) var status: Status = .disabled
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var teamsRunning = false
    @Published private(set) var systemIdle: TimeInterval = 0
    @Published private(set) var realIdle: TimeInterval = 0
    @Published private(set) var lastActionAt: Date?
    @Published private(set) var actionsToday = 0
    @Published private(set) var lastActionFailed = false
    @Published private(set) var isHoldingDisplay = false

    let settings: AppSettings

    private let power = PowerAssertion()
    private let lock = ScreenLockWatcher()
    private let tracker = RealIdleTracker()
    private let simulator = InputSimulator()
    private let log = Logger(subsystem: "com.omarelnabalawy.KeepMeIn", category: "engine")
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var verifyAfter: Date?
    private var lastAttemptAt: Date?
    private var counterDay = 0

    init(settings: AppSettings) {
        self.settings = settings

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // objectWillChange fires before the value lands; re-evaluate on the next turn.
                DispatchQueue.main.async { self?.tick() }
            }
            .store(in: &cancellables)

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        tick()
        if settings.isEnabled && !accessibilityGranted && !DebugSnapshot.isRequested {
            Permissions.requestAccessibility()
        }
    }

    var menuBarSymbol: String {
        if lastActionFailed && status.isWorking { return "person.crop.circle.badge.exclamationmark" }
        switch status {
        case .disabled: return "person.crop.circle"
        case .needsAccessibility: return "person.crop.circle.badge.exclamationmark"
        case .outsideSchedule, .teamsNotRunning, .screenLocked: return "person.crop.circle.badge.moon"
        case .userActive, .keepingAlive: return "person.crop.circle.badge.checkmark"
        }
    }

    /// Seconds until the next nudge, or nil when the engine is parked.
    var nextActionIn: TimeInterval? {
        guard status.isWorking else { return nil }
        return max(0, settings.intervalSeconds - systemIdle)
    }

    func requestAccessibility() {
        Permissions.requestAccessibility()
        tick()
    }

    // MARK: - Loop

    private func tick() {
        let now = Date()
        accessibilityGranted = Permissions.isAccessibilityTrusted
        teamsRunning = TeamsWatcher.isRunning
        systemIdle = IdleMonitor.systemIdleSeconds()
        realIdle = tracker.secondsSinceRealInput()
        rollDailyCounter(now)
        verifyLastActionIfDue(now)

        guard settings.isEnabled else { return park(.disabled) }
        guard accessibilityGranted else { return park(.needsAccessibility) }
        guard Schedule.isActive(at: now, settings: settings) else { return park(.outsideSchedule) }
        if settings.onlyWhenTeamsRunning && !teamsRunning { return park(.teamsNotRunning) }
        if settings.pauseWhenScreenLocked && lock.isLocked { return park(.screenLocked) }

        if settings.keepDisplayAwake { power.acquire() } else { power.release() }
        isHoldingDisplay = power.isHeld

        let interval = settings.intervalSeconds
        let sinceAttempt = lastAttemptAt.map { now.timeIntervalSince($0) } ?? .infinity
        if systemIdle >= interval && sinceAttempt >= min(interval, 10) && !InputSimulator.userIsHoldingInput {
            perform(now: now)
        }

        status = realIdle < interval ? .userActive : .keepingAlive
    }

    private func park(_ parked: Status) {
        power.release()
        isHoldingDisplay = false
        status = parked
    }

    private func perform(now: Date) {
        lastAttemptAt = now
        let posted: Bool
        switch settings.mode {
        case .mouse:
            posted = simulator.nudgeMouse()
            tracker.noteSynthetic(types: [.mouseMoved])
        case .keyboard:
            posted = simulator.pressF15()
            tracker.noteSynthetic(types: [.keyDown, .keyUp])
        }

        if posted {
            lastActionAt = now
            actionsToday += 1
            verifyAfter = now.addingTimeInterval(1.5)
            log.info("Posted \(self.settings.mode.rawValue, privacy: .public) activity")
        } else {
            lastActionFailed = true
            log.error("Could not create synthetic event")
        }
    }

    /// If the nudge registered, the system idle clock restarted when we posted it.
    private func verifyLastActionIfDue(_ now: Date) {
        guard let verifyAfter, now >= verifyAfter, let lastActionAt else { return }
        self.verifyAfter = nil
        let expectedAtMost = now.timeIntervalSince(lastActionAt) + 1.0
        lastActionFailed = systemIdle > expectedAtMost
        if lastActionFailed {
            log.error("Synthetic input did not register; idle is \(self.systemIdle, privacy: .public)s")
        }
    }

    private func rollDailyCounter(_ now: Date) {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        if day != counterDay {
            counterDay = day
            actionsToday = 0
        }
    }
}
