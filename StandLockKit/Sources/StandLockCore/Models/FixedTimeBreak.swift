import Foundation

/// A break that fires at a fixed local clock time on selected weekdays, rather than on a
/// repeating interval. Stored apart from `Schedule` so existing persisted schedules are untouched.
public struct FixedTimeBreak: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var days: DaySelection
    public var hour: Int
    public var minute: Int
    public var duration: TimeInterval
    public var disciplineLevel: DisciplineLevel

    public init(
        id: UUID = UUID(), name: String, isEnabled: Bool = true,
        days: DaySelection = .weekdays, hour: Int, minute: Int,
        duration: TimeInterval = 120, disciplineLevel: DisciplineLevel = .strict
    ) {
        self.id = id; self.name = name; self.isEnabled = isEnabled
        self.days = days; self.hour = hour; self.minute = minute
        self.duration = duration; self.disciplineLevel = disciplineLevel
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, days, hour, minute, duration, disciplineLevel
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        days = try c.decodeIfPresent(DaySelection.self, forKey: .days) ?? .weekdays
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 120
        disciplineLevel = try c.decodeIfPresent(DisciplineLevel.self, forKey: .disciplineLevel) ?? .strict
    }

    /// The form `BreakCoordinator` consumes. It keeps this break's `id`, which is how
    /// `FixedTimeSchedulingEngine` recognises it; `windows` and `breakInterval` carry no meaning here.
    public var schedule: Schedule {
        Schedule(
            id: id, name: name, isEnabled: isEnabled, days: days, windows: [],
            breakInterval: 24 * 60 * 60, breakDuration: duration, disciplineLevel: disciplineLevel
        )
    }
}
