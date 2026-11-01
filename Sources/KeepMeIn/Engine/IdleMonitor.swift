import CoreGraphics
import Foundation

/// Reads the same per-session idle clock that Teams (via Electron's powerMonitor) reads.
enum IdleMonitor {
    /// `kCGAnyInputEventType` has no Swift constant; it is `~0`.
    private static let anyInput = CGEventType(rawValue: ~0)

    /// Event types we sample individually when telling real input apart from our own.
    static let trackedTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseDragged, .otherMouseDown, .otherMouseDragged,
        .scrollWheel, .keyDown, .keyUp, .flagsChanged,
    ]

    static func idle(_ type: CGEventType) -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
    }

    /// Seconds since the last input of any kind, synthetic or not.
    static func systemIdleSeconds() -> TimeInterval {
        if let anyInput {
            return idle(anyInput)
        }
        return trackedTypes.map(idle).min() ?? 0
    }
}

/// Estimates how long the *person* has been idle by ignoring the events this app posted itself.
final class RealIdleTracker {
    private var lastRealActivity = Date()
    private var lastSynthetic: (at: Date, types: [CGEventType])?

    func noteSynthetic(types: [CGEventType]) {
        lastSynthetic = (Date(), types)
    }

    func secondsSinceRealInput() -> TimeInterval {
        let now = Date()
        var idles: [TimeInterval] = []

        for type in IdleMonitor.trackedTypes {
            let idle = IdleMonitor.idle(type)
            // If the newest event of this type lines up with our own synthetic one, it was ours.
            if let synthetic = lastSynthetic,
               synthetic.types.contains(type),
               abs(idle - now.timeIntervalSince(synthetic.at)) < 1.0 {
                continue
            }
            idles.append(idle)
        }

        if let newest = idles.min() {
            lastRealActivity = max(lastRealActivity, now.addingTimeInterval(-newest))
        }
        return now.timeIntervalSince(lastRealActivity)
    }
}
