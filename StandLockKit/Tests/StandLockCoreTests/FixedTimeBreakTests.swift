import Foundation
import Testing
@testable import StandLockCore

@Suite("FixedTimeBreak")
struct FixedTimeBreakTests {
    @Test func roundTripsThroughJSON() throws {
        let original = FixedTimeBreak(
            name: "Lunch", isEnabled: false, days: .custom([.monday, .friday]),
            hour: 12, minute: 30, duration: 120, disciplineLevel: .firm
        )
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([FixedTimeBreak].self, from: data)
        #expect(decoded == [original])
    }

    @Test func decodingFillsDefaultsForMissingOptionalKeys() throws {
        let id = UUID()
        let json = #"[{"id":"\#(id.uuidString)","name":"Dinner","hour":18,"minute":15}]"#
        let decoded = try JSONDecoder().decode([FixedTimeBreak].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        #expect(decoded[0].isEnabled)
        #expect(decoded[0].days == .weekdays)
        #expect(decoded[0].duration == 120)
        #expect(decoded[0].disciplineLevel == .strict)
    }

    @Test func existingScheduleJSONStillDecodes() throws {
        // A schedule persisted before fixed-time breaks existed; the model must be unaffected.
        let json = """
        {"id":"\(UUID().uuidString)","name":"Work Hours","days":{"weekdays":{}},
         "windows":[{"startHour":9,"startMinute":0,"endHour":17,"endMinute":0}],
         "breakInterval":2700,"breakDuration":300}
        """
        let schedule = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
        #expect(schedule.name == "Work Hours")
        #expect(schedule.isEnabled)
    }
}
