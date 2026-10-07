import Foundation
import Testing
@testable import Coordination
@testable import StandLockCore
@testable import Scheduling

/// Stands in for `ScheduleEvaluator` so the repeating schedule's slot is exact.
private struct StubBaseEngine: SchedulingEngine {
    let slot: Date
    func nextBreakTime(for schedule: Schedule, after date: Date, cycleIndex: Int) -> Date? { slot }
    func breakDuration(for schedule: Schedule, breakIndex: Int) -> TimeInterval { schedule.breakDuration }
    func isWithinActiveWindow(_ schedule: Schedule, at date: Date) -> Bool { true }
}

/// Collects `.nextBreakScheduled` dates.
@MainActor
private func scheduledDates(_ coordinator: BreakCoordinator, _ body: () async -> Void) async -> [Date] {
    var dates: [Date] = []
    let listener = Task {
        for await event in coordinator.events {
            if case .nextBreakScheduled(let date) = event { dates.append(date) }
        }
    }
    await body()
    listener.cancel()
    return dates
}

@Suite("Fixed-time breaks with BreakCoordinator")
struct FixedTimeCoordinationTests {
    /// A fixed break whose next occurrence is between one and three minutes away.
    private func upcomingFixedBreak() -> FixedTimeBreak {
        let target = Date().addingTimeInterval(120)
        let c = Calendar.autoupdatingCurrent
        return FixedTimeBreak(name: "Soon", days: .everyDay,
                              hour: c.component(.hour, from: target), minute: c.component(.minute, from: target))
    }

    @Test @MainActor
    func fixedBreakWinsWhenItIsEarlierThanTheRepeatingSlot() async {
        let fixed = upcomingFixedBreak()
        let engine = FixedTimeSchedulingEngine(
            base: StubBaseEngine(slot: Date().addingTimeInterval(3600)), fixedBreaks: [fixed])
        let coordinator = BreakCoordinator(scheduler: engine, detector: MockDetector(), locker: MockLocker())
        let dates = await scheduledDates(coordinator) {
            coordinator.start(with: [makeSchedule(), fixed.schedule], preferences: AppPreferences())
            try? await Task.sleep(for: .milliseconds(100))
        }
        coordinator.stop()
        #expect(dates.first == engine.nextOccurrence(of: fixed, after: Date()))
    }

    @Test @MainActor
    func repeatingSlotWinsWhenItIsEarlierThanTheFixedBreak() async {
        let fixed = upcomingFixedBreak()
        let repeatingSlot = Date().addingTimeInterval(30)
        let engine = FixedTimeSchedulingEngine(base: StubBaseEngine(slot: repeatingSlot), fixedBreaks: [fixed])
        let coordinator = BreakCoordinator(scheduler: engine, detector: MockDetector(), locker: MockLocker())
        let dates = await scheduledDates(coordinator) {
            coordinator.start(with: [makeSchedule(), fixed.schedule], preferences: AppPreferences())
            try? await Task.sleep(for: .milliseconds(100))
        }
        coordinator.stop()
        #expect(dates.first == repeatingSlot)
    }

    @Test @MainActor
    func disabledFixedBreakIsNeverArmed() async {
        var fixed = upcomingFixedBreak()
        fixed.isEnabled = false
        let engine = FixedTimeSchedulingEngine(
            base: StubBaseEngine(slot: Date().addingTimeInterval(3600)), fixedBreaks: [fixed])
        let coordinator = BreakCoordinator(scheduler: engine, detector: MockDetector(), locker: MockLocker())
        let dates = await scheduledDates(coordinator) {
            coordinator.start(with: [fixed.schedule], preferences: AppPreferences())
            try? await Task.sleep(for: .milliseconds(100))
        }
        coordinator.stop()
        #expect(dates.isEmpty)
    }

    @Test @MainActor
    func fixedBreakUsesItsOwnDurationAndLevelWhenItFires() async {
        // The coordinator fires whatever slot the engine returns; a stub that returns "now" stands in for the clock.
        let fixed = FixedTimeBreak(name: "Lunch", hour: 12, minute: 30, duration: 120, disciplineLevel: .strict)
        let scheduler = MockScheduler()
        scheduler.nextBreakTimeToReturn = Date().addingTimeInterval(0.05)
        let locker = MockLocker()
        let coordinator = BreakCoordinator(scheduler: scheduler, detector: MockDetector(), locker: locker)
        coordinator.start(with: [fixed.schedule], preferences: AppPreferences())
        try? await Task.sleep(for: .milliseconds(300))
        #expect(locker.lastLevel == .strict)
        #expect(locker.lastDuration == 120)
        coordinator.stop()
    }
}
