import CoreGraphics
import Foundation

/// Generates the tiny bits of HID input that reset the system idle clock Teams (and the display sleep timer) watch.
///
/// Two things matter here beyond "post an event":
/// 1. The source is the *combined session* state, not the HID system state, so the event is treated as app
///    input and never rewrites the hardware modifier/button tables.
/// 2. Local event suppression is disabled. By default macOS mutes the real mouse and trackpad for 250 ms after
///    every synthetic event, which can swallow half of a click the user makes at that moment (the symptom is
///    phantom double clicks or a context menu where a normal click was meant).
final class InputSimulator {
    private static let f15: CGKeyCode = 113 // kVK_F15

    private let source: CGEventSource? = {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return nil }
        source.localEventsSuppressionInterval = 0
        let permitAll: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateSuppressionInterval)
        source.setLocalEventsFilterDuringSuppressionState(permitAll, state: .eventSuppressionStateRemoteMouseDrag)
        return source
    }()

    static var pointerLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// True when the person is physically holding a modifier or mouse button right now. Nudging in that state
    /// risks interleaving with their input, so the engine waits for the next tick instead.
    static var userIsHoldingInput: Bool {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]
        if !flags.intersection(modifiers).isEmpty { return true }
        return CGEventSource.buttonState(.combinedSessionState, button: .left)
            || CGEventSource.buttonState(.combinedSessionState, button: .right)
    }

    /// Moves the pointer one pixel sideways and immediately back to where it was.
    func nudgeMouse() -> Bool {
        let origin = Self.pointerLocation
        let dx: CGFloat = origin.x > 2 ? -1 : 1
        let nudged = CGPoint(x: origin.x + dx, y: origin.y)

        guard
            let away = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: nudged, mouseButton: .left),
            let back = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: origin, mouseButton: .left)
        else { return false }

        // A pointer move carries no modifiers. Never let a stale flag ride along on our event.
        away.flags = []
        back.flags = []
        away.post(tap: .cghidEventTap)
        usleep(15_000)
        back.post(tap: .cghidEventTap)
        return true
    }

    /// Taps F15. No Mac keyboard has that key, so nothing on screen reacts.
    func pressF15() -> Bool {
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: Self.f15, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: Self.f15, keyDown: false)
        else { return false }

        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        usleep(10_000)
        up.post(tap: .cghidEventTap)
        return true
    }
}
