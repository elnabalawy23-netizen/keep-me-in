import Combine
import Foundation

enum ActivityMode: String, CaseIterable, Identifiable {
    case mouse
    case keyboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mouse: return "Mouse nudge"
        case .keyboard: return "Keyboard (F15)"
        }
    }

    var detail: String {
        switch self {
        case .mouse:
            return "Moves the pointer 1 pixel and straight back. Invisible in practice and works everywhere."
        case .keyboard:
            return "Taps F15, a key no Mac keyboard has, so nothing reacts to it. Use this if an app dislikes pointer movement."
        }
    }
}

/// All user preferences. Persisted to UserDefaults on every change.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Key {
        static let isEnabled = "isEnabled"
        static let intervalSeconds = "intervalSeconds"
        static let mode = "mode"
        static let keepDisplayAwake = "keepDisplayAwake"
        static let onlyWhenTeamsRunning = "onlyWhenTeamsRunning"
        static let pauseWhenScreenLocked = "pauseWhenScreenLocked"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleStartMinutes = "scheduleStartMinutes"
        static let scheduleEndMinutes = "scheduleEndMinutes"
        static let scheduleWeekdays = "scheduleWeekdays"
        static let nudgeEnabled = "nudgeEnabled"
        static let stopAfterMinutes = "stopAfterMinutes"
    }

    /// Teams flips you to "Away" after 5 minutes without input. Anything under that works.
    static let teamsAwayThreshold: TimeInterval = 5 * 60

    /// Choices offered by the panel's "Move every" menu.
    static let intervalChoices: [Double] = [30, 60, 120, 180, 240]
    /// Choices offered by the panel's "Stop after" menu (minutes; 0 = until stopped).
    static let stopAfterChoices: [Int] = [0, 30, 60, 120, 240, 480]

    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Key.isEnabled) } }
    @Published var intervalSeconds: Double { didSet { defaults.set(intervalSeconds, forKey: Key.intervalSeconds) } }
    @Published var mode: ActivityMode { didSet { defaults.set(mode.rawValue, forKey: Key.mode) } }
    @Published var keepDisplayAwake: Bool { didSet { defaults.set(keepDisplayAwake, forKey: Key.keepDisplayAwake) } }
    @Published var onlyWhenTeamsRunning: Bool { didSet { defaults.set(onlyWhenTeamsRunning, forKey: Key.onlyWhenTeamsRunning) } }
    @Published var pauseWhenScreenLocked: Bool { didSet { defaults.set(pauseWhenScreenLocked, forKey: Key.pauseWhenScreenLocked) } }
    @Published var scheduleEnabled: Bool { didSet { defaults.set(scheduleEnabled, forKey: Key.scheduleEnabled) } }
    /// Minutes after midnight.
    @Published var scheduleStartMinutes: Int { didSet { defaults.set(scheduleStartMinutes, forKey: Key.scheduleStartMinutes) } }
    @Published var scheduleEndMinutes: Int { didSet { defaults.set(scheduleEndMinutes, forKey: Key.scheduleEndMinutes) } }
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    @Published var scheduleWeekdays: Set<Int> { didSet { defaults.set(Array(scheduleWeekdays).sorted(), forKey: Key.scheduleWeekdays) } }
    /// Whether idle time triggers a nudge at all. Off means "only keep the display awake".
    @Published var nudgeEnabled: Bool { didSet { defaults.set(nudgeEnabled, forKey: Key.nudgeEnabled) } }
    /// Auto-pause the session after this many minutes. 0 = until stopped manually.
    @Published var stopAfterMinutes: Int { didSet { defaults.set(stopAfterMinutes, forKey: Key.stopAfterMinutes) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.intervalSeconds: 60.0,
            Key.mode: ActivityMode.mouse.rawValue,
            Key.keepDisplayAwake: true,
            Key.onlyWhenTeamsRunning: false,
            Key.pauseWhenScreenLocked: false,
            Key.scheduleEnabled: false,
            Key.scheduleStartMinutes: 9 * 60,
            Key.scheduleEndMinutes: 18 * 60,
            Key.scheduleWeekdays: [1, 2, 3, 4, 5], // Sunday–Thursday
            Key.nudgeEnabled: true,
            Key.stopAfterMinutes: 0,
        ])

        isEnabled = defaults.bool(forKey: Key.isEnabled)
        intervalSeconds = defaults.double(forKey: Key.intervalSeconds)
        mode = ActivityMode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .mouse
        keepDisplayAwake = defaults.bool(forKey: Key.keepDisplayAwake)
        onlyWhenTeamsRunning = defaults.bool(forKey: Key.onlyWhenTeamsRunning)
        pauseWhenScreenLocked = defaults.bool(forKey: Key.pauseWhenScreenLocked)
        scheduleEnabled = defaults.bool(forKey: Key.scheduleEnabled)
        scheduleStartMinutes = defaults.integer(forKey: Key.scheduleStartMinutes)
        scheduleEndMinutes = defaults.integer(forKey: Key.scheduleEndMinutes)
        scheduleWeekdays = Set(defaults.array(forKey: Key.scheduleWeekdays) as? [Int] ?? [])
        nudgeEnabled = defaults.bool(forKey: Key.nudgeEnabled)
        stopAfterMinutes = defaults.integer(forKey: Key.stopAfterMinutes)
    }
}
