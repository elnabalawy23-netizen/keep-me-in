import Foundation
import IOKit.pwr_mgt

/// Holds a "prevent display sleep" assertion while the engine is active, like `caffeinate -d`.
final class PowerAssertion {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isHeld = false

    func acquire() {
        guard !isHeld else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Keep Me In is keeping you available" as CFString,
            &assertionID
        )
        isHeld = result == kIOReturnSuccess
    }

    func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isHeld = false
    }

    deinit { release() }
}
