import Foundation

@MainActor
final class ScreenLockWatcher {
    private(set) var isLocked = false
    private var tokens: [NSObjectProtocol] = []

    init() {
        let center = DistributedNotificationCenter.default()
        tokens.append(center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.isLocked = true }
        })
        tokens.append(center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.isLocked = false }
        })
    }

    deinit {
        let center = DistributedNotificationCenter.default()
        tokens.forEach(center.removeObserver)
    }
}
