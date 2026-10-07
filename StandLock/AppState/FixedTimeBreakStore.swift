import Foundation
import Combine
import Coordination
import StandLockCore

/// Owns the user's fixed-time breaks and their persistence. Lives beside `AppCoordinator`'s
/// `schedules` rather than inside them: its own defaults key means schedules persisted by
/// upstream builds are never read, rewritten or migrated here.
@MainActor
final class FixedTimeBreakStore: ObservableObject {
    private static let defaultsKey = "fixedTimeBreaks"

    @Published private(set) var breaks: [FixedTimeBreak] = []

    /// Fired after the list is edited, so the owner can rebuild the coordinator.
    var onChange: (() -> Void)?
    /// Fired when the wall clock or timezone changes. A slot armed before the change was computed
    /// in the old zone, so it has to be recomputed.
    var onClockChange: (() -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([FixedTimeBreak].self, from: data) {
            breaks = decoded
        }
        for name in [Notification.Name.NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onClockChange?()
                }
            }
        }
    }

    /// The coordinator-facing form of every break; the coordinator skips disabled ones itself.
    var schedules: [Schedule] { breaks.map(\.schedule) }

    var hasEnabled: Bool { breaks.contains(where: \.isEnabled) }

    func add(_ fixedBreak: FixedTimeBreak) {
        breaks.append(fixedBreak)
        commit()
    }

    func update(_ fixedBreak: FixedTimeBreak) {
        guard let index = breaks.firstIndex(where: { $0.id == fixedBreak.id }) else { return }
        breaks[index] = fixedBreak
        commit()
    }

    func delete(_ fixedBreak: FixedTimeBreak) {
        breaks.removeAll { $0.id == fixedBreak.id }
        commit()
    }

    /// A rebuilt coordinator re-arms the slot it inherits if that slot is still in the future.
    /// For a fixed break that slot is stale after an edit (the time may have moved), and it is
    /// cheap to recompute, so it is never carried over.
    func discardingFixedSlot(from state: EnforcementState) -> EnforcementState {
        guard let id = state.pendingBreakScheduleID, breaks.contains(where: { $0.id == id }) else { return state }
        var result = state
        result.pendingBreakScheduleID = nil
        result.pendingBreakDate = nil
        return result
    }

    private func commit() {
        if let data = try? JSONEncoder().encode(breaks) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        onChange?()
    }
}
