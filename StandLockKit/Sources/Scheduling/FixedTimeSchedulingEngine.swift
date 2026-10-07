import Foundation
import StandLockCore

/// Adds `FixedTimeBreak` support to any `SchedulingEngine`. A schedule whose id matches a fixed
/// break gets the next wall-clock occurrence of that break; every other schedule goes to `base`
/// unchanged, so repeating schedules behave exactly as before.
///
/// Semantics:
/// - The result is always strictly after `date`, so an occurrence that has already passed is
///   never returned. There is no missed-trigger grace: `BreakCoordinator` re-arms from the current
///   time after sleep, wake, screen unlock, pause and launch, so a slot missed in the meantime is
///   skipped rather than fired late. Re-arming just before a slot still fires it.
/// - Strictly-after also makes each slot fire once. A re-arm after the break (completion, skip,
///   edit) lands on the next matching day, never on the slot that just fired.
/// - One candidate per calendar day, built from that day's wall-clock time. A time inside a DST
///   gap fires at the first valid instant after it; a time that occurs twice fires at the first.
public struct FixedTimeSchedulingEngine: SchedulingEngine {
    private let base: any SchedulingEngine
    private let fixedBreaks: [UUID: FixedTimeBreak]
    private let calendar: Calendar

    /// `autoupdatingCurrent` so a timezone change is picked up without rebuilding the engine.
    public init(base: any SchedulingEngine, fixedBreaks: [FixedTimeBreak],
                calendar: Calendar = .autoupdatingCurrent) {
        self.base = base
        self.fixedBreaks = Dictionary(fixedBreaks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.calendar = calendar
    }

    public func nextBreakTime(for schedule: Schedule, after date: Date, cycleIndex: Int) -> Date? {
        guard let fixed = fixedBreaks[schedule.id] else {
            return base.nextBreakTime(for: schedule, after: date, cycleIndex: cycleIndex)
        }
        return nextOccurrence(of: fixed, after: date)
    }

    public func breakDuration(for schedule: Schedule, breakIndex: Int) -> TimeInterval {
        base.breakDuration(for: schedule, breakIndex: breakIndex)
    }

    public func isWithinActiveWindow(_ schedule: Schedule, at date: Date) -> Bool {
        base.isWithinActiveWindow(schedule, at: date)
    }

    public func nextOccurrence(of fixed: FixedTimeBreak, after date: Date) -> Date? {
        let activeDays = fixed.days.activeDays
        guard fixed.isEnabled, !activeDays.isEmpty,
              (0..<24).contains(fixed.hour), (0..<60).contains(fixed.minute) else { return nil }

        let startOfDay = calendar.startOfDay(for: date)
        // Today plus a full week: if today's slot has passed, the same weekday next week is the
        // furthest a single selected day can be.
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                  let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)),
                  activeDays.contains(weekday),
                  let candidate = calendar.date(
                      bySettingHour: fixed.hour, minute: fixed.minute, second: 0, of: day,
                      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward
                  ),
                  candidate > date else { continue }
            return candidate
        }
        return nil
    }
}
