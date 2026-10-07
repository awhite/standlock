import Foundation
import Testing
@testable import Scheduling
@testable import StandLockCore

// MARK: - Helpers

private func makeCalendar(_ zone: String = "UTC") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

private func makeDate(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
    var components = DateComponents()
    components.year = year; components.month = month; components.day = day
    components.hour = hour; components.minute = minute; components.second = second
    return calendar.date(from: components)!
}

private func makeEngine(_ breaks: [FixedTimeBreak], calendar: Calendar,
                        base: any SchedulingEngine = ScheduleEvaluator()) -> FixedTimeSchedulingEngine {
    FixedTimeSchedulingEngine(base: base, fixedBreaks: breaks, calendar: calendar)
}

private func lunch(days: DaySelection = .weekdays, hour: Int = 12, minute: Int = 30,
                   isEnabled: Bool = true) -> FixedTimeBreak {
    FixedTimeBreak(name: "Lunch", isEnabled: isEnabled, days: days, hour: hour, minute: minute)
}

private func next(_ engine: FixedTimeSchedulingEngine, _ fixed: FixedTimeBreak, after date: Date) -> Date? {
    engine.nextBreakTime(for: fixed.schedule, after: date, cycleIndex: 0)
}

// 2026-03-09 is a Monday; 2026-03-13 a Friday; 2026-03-14 a Saturday.

@Suite("FixedTimeSchedulingEngine")
struct FixedTimeSchedulingEngineTests {
    let cal = makeCalendar()

    @Test func beforeScheduledTimeFiresToday() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 9, 0))
        #expect(result == makeDate(cal, 2026, 3, 9, 12, 30))
    }

    @Test func exactlyAtScheduledTimeRollsToNextDay() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 12, 30))
        #expect(result == makeDate(cal, 2026, 3, 10, 12, 30))
    }

    @Test func afterScheduledTimeRollsToNextDay() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 12, 30, 1))
        #expect(result == makeDate(cal, 2026, 3, 10, 12, 30))
    }

    @Test func oneSecondBeforeStillFiresToday() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 12, 29, 59))
        #expect(result == makeDate(cal, 2026, 3, 9, 12, 30))
    }

    @Test func weekdayFilterSkipsWeekend() {
        let fixed = lunch(days: .weekdays)
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 13, 13, 0))
        #expect(result == makeDate(cal, 2026, 3, 16, 12, 30))
    }

    @Test func customDaysOnlyFireOnSelectedDays() {
        let fixed = lunch(days: .custom([.wednesday]))
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 8, 0))
        #expect(result == makeDate(cal, 2026, 3, 11, 12, 30))
    }

    @Test func singleDayPassedTodayFiresNextWeek() {
        let fixed = lunch(days: .custom([.monday]))
        let engine = makeEngine([fixed], calendar: cal)
        let result = next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 12, 31))
        #expect(result == makeDate(cal, 2026, 3, 16, 12, 30))
    }

    @Test func disabledBreakNeverFires() {
        let fixed = lunch(isEnabled: false)
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 9, 0)) == nil)
    }

    @Test func emptyCustomDaysNeverFires() {
        let fixed = lunch(days: .custom([]))
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 9, 0)) == nil)
    }

    @Test func outOfRangeTimeNeverFires() {
        let engine = makeEngine([], calendar: cal)
        #expect(engine.nextOccurrence(of: lunch(hour: 24), after: makeDate(cal, 2026, 3, 9)) == nil)
        #expect(engine.nextOccurrence(of: lunch(minute: 60), after: makeDate(cal, 2026, 3, 9)) == nil)
    }

    // MARK: once per day

    @Test func walkingForwardFiresOncePerSelectedDay() {
        let fixed = lunch(days: .weekdays)
        let engine = makeEngine([fixed], calendar: cal)
        var cursor = makeDate(cal, 2026, 3, 9, 0, 0)
        var fired: [Date] = []
        for _ in 0..<7 {
            guard let slot = next(engine, fixed, after: cursor) else { break }
            fired.append(slot)
            // Re-arm from just after the break begins, as the coordinator does.
            cursor = slot.addingTimeInterval(1)
        }
        let expectedDays = [9, 10, 11, 12, 13, 16, 17]
        #expect(fired == expectedDays.map { makeDate(cal, 2026, 3, $0, 12, 30) })
    }

    @Test func rearmingDuringTheScheduledMinuteDoesNotRepeat() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        let slot = makeDate(cal, 2026, 3, 9, 12, 30)
        for offset in [0.0, 0.001, 1, 30, 59.9] {
            let result = next(engine, fixed, after: slot.addingTimeInterval(offset))
            #expect(result == makeDate(cal, 2026, 3, 10, 12, 30))
        }
    }

    // MARK: multiple breaks

    @Test func eachBreakGetsItsOwnTime() {
        let a = lunch(hour: 12, minute: 30)
        let b = lunch(hour: 18, minute: 15)
        let engine = makeEngine([a, b], calendar: cal)
        let now = makeDate(cal, 2026, 3, 9, 13, 0)
        #expect(next(engine, a, after: now) == makeDate(cal, 2026, 3, 10, 12, 30))
        #expect(next(engine, b, after: now) == makeDate(cal, 2026, 3, 9, 18, 15))
    }

    @Test func duplicateIdsKeepTheFirstBreak() {
        let id = UUID()
        let first = FixedTimeBreak(id: id, name: "A", hour: 9, minute: 0)
        let second = FixedTimeBreak(id: id, name: "B", hour: 10, minute: 0)
        let engine = makeEngine([first, second], calendar: cal)
        #expect(next(engine, first, after: makeDate(cal, 2026, 3, 9, 0, 0)) == makeDate(cal, 2026, 3, 9, 9, 0))
    }

    // MARK: day boundaries

    @Test func midnightBreakFiresAtStartOfDay() {
        let fixed = lunch(days: .everyDay, hour: 0, minute: 0)
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 23, 59, 59)) == makeDate(cal, 2026, 3, 10, 0, 0))
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 10, 0, 0)) == makeDate(cal, 2026, 3, 11, 0, 0))
    }

    @Test func lateEveningBreakCrossesIntoNextWeekday() {
        let fixed = lunch(days: .everyDay, hour: 23, minute: 59)
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 23, 59)) == makeDate(cal, 2026, 3, 10, 23, 59))
    }

    @Test func monthAndYearBoundary() {
        let fixed = lunch(days: .everyDay, hour: 8, minute: 0)
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 12, 31, 9, 0)) == makeDate(cal, 2027, 1, 1, 8, 0))
    }

    // MARK: launch / sleep / wake

    @Test func launchJustBeforeSlotStillFires() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 12, 29, 58)) == makeDate(cal, 2026, 3, 9, 12, 30))
    }

    @Test func launchJustAfterSlotSkipsToNextDay() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        #expect(next(engine, fixed, after: makeDate(cal, 2026, 3, 9, 12, 30, 5)) == makeDate(cal, 2026, 3, 10, 12, 30))
    }

    @Test func wakingHoursAfterMissedSlotDoesNotFireStaleBreak() {
        let fixed = lunch()
        let engine = makeEngine([fixed], calendar: cal)
        let wake = makeDate(cal, 2026, 3, 9, 15, 0)
        let result = next(engine, fixed, after: wake)
        #expect(result == makeDate(cal, 2026, 3, 10, 12, 30))
        #expect(result! > wake)
    }

    @Test func editedTimeTakesEffectFromTheNewValue() {
        var fixed = lunch(hour: 12, minute: 30)
        let now = makeDate(cal, 2026, 3, 9, 12, 29)
        #expect(next(makeEngine([fixed], calendar: cal), fixed, after: now) == makeDate(cal, 2026, 3, 9, 12, 30))
        fixed.hour = 18; fixed.minute = 0
        #expect(next(makeEngine([fixed], calendar: cal), fixed, after: now) == makeDate(cal, 2026, 3, 9, 18, 0))
    }

    // MARK: timezone and DST

    @Test func resultFollowsTheCalendarTimezone() {
        let fixed = lunch(days: .everyDay)
        let tokyo = makeCalendar("Asia/Tokyo")
        let engine = makeEngine([fixed], calendar: tokyo)
        let result = next(engine, fixed, after: makeDate(tokyo, 2026, 3, 9, 9, 0))
        #expect(result == makeDate(tokyo, 2026, 3, 9, 12, 30))
        #expect(result != makeDate(cal, 2026, 3, 9, 12, 30))
    }

    @Test func springForwardGapFiresAtFirstValidInstant() {
        // 02:30 does not exist on 2026-03-08 in New York; clocks jump from 02:00 to 03:00.
        let ny = makeCalendar("America/New_York")
        let fixed = lunch(days: .everyDay, hour: 2, minute: 30)
        let engine = makeEngine([fixed], calendar: ny)
        let result = next(engine, fixed, after: makeDate(ny, 2026, 3, 7, 3, 0))
        #expect(result == makeDate(ny, 2026, 3, 8, 3, 0))
        // Once per day: the next one is a normal 02:30 on the 9th.
        #expect(next(engine, fixed, after: result!) == makeDate(ny, 2026, 3, 9, 2, 30))
    }

    @Test func fallBackRepeatedHourFiresOnlyOnce() {
        // 01:30 happens twice on 2026-11-01 in New York. Only the first occurrence fires.
        let ny = makeCalendar("America/New_York")
        let fixed = lunch(days: .everyDay, hour: 1, minute: 30)
        let engine = makeEngine([fixed], calendar: ny)
        let first = next(engine, fixed, after: makeDate(ny, 2026, 10, 31, 12, 0))!
        #expect(first == Date(timeIntervalSince1970: makeDate(makeCalendar("UTC"), 2026, 11, 1, 5, 30).timeIntervalSince1970))
        let second = next(engine, fixed, after: first.addingTimeInterval(1))!
        #expect(second == makeDate(ny, 2026, 11, 2, 1, 30))
    }

    @Test func ordinaryDayAcrossDSTKeepsWallClockTime() {
        let ny = makeCalendar("America/New_York")
        let fixed = lunch(days: .everyDay)
        let engine = makeEngine([fixed], calendar: ny)
        // 24h after the 7th's slot is not 12:30 on the 8th once the clocks have moved.
        let result = next(engine, fixed, after: makeDate(ny, 2026, 3, 7, 12, 30))
        #expect(result == makeDate(ny, 2026, 3, 8, 12, 30))
    }

    // MARK: coexistence with repeating schedules

    @Test func repeatingSchedulesAreDelegatedUnchanged() {
        let repeating = Schedule(
            name: "Work", days: .everyDay,
            windows: [TimeWindow(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
            breakInterval: 2400, breakDuration: 300
        )
        let base = ScheduleEvaluator()
        let engine = makeEngine([lunch()], calendar: cal, base: base)
        let now = makeDate(Calendar.current, 2026, 5, 4, 10, 0)
        #expect(engine.nextBreakTime(for: repeating, after: now, cycleIndex: 0)
                == base.nextBreakTime(for: repeating, after: now, cycleIndex: 0))
        #expect(engine.breakDuration(for: repeating, breakIndex: 0) == base.breakDuration(for: repeating, breakIndex: 0))
        #expect(engine.isWithinActiveWindow(repeating, at: now) == base.isWithinActiveWindow(repeating, at: now))
    }

    @Test func fixedBreakDoesNotAffectRepeatingScheduleTiming() {
        let repeating = Schedule(
            name: "Work", days: .everyDay,
            windows: [TimeWindow(startHour: 0, startMinute: 0, endHour: 23, endMinute: 59)],
            breakInterval: 600, breakDuration: 60
        )
        let now = makeDate(Calendar.current, 2026, 5, 4, 10, 0)
        let withFixed = makeEngine([lunch()], calendar: cal)
        let without = makeEngine([], calendar: cal)
        #expect(withFixed.nextBreakTime(for: repeating, after: now, cycleIndex: 0)
                == without.nextBreakTime(for: repeating, after: now, cycleIndex: 0))
    }

    @Test func fixedScheduleProjectionCarriesDurationLevelAndId() {
        let fixed = FixedTimeBreak(name: "Lunch", hour: 12, minute: 30, duration: 120, disciplineLevel: .strict)
        let schedule = fixed.schedule
        #expect(schedule.id == fixed.id)
        #expect(schedule.breakDuration == 120)
        #expect(schedule.disciplineLevel == .strict)
        #expect(schedule.isEnabled)
        #expect(schedule.repetitionRule == nil)
    }
}
