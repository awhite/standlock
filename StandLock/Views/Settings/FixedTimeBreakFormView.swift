import SwiftUI
import StandLockCore

struct FixedTimeBreakFormView: View {
    let fixedBreak: FixedTimeBreak?
    let onSave: (FixedTimeBreak) -> Void
    let onCancel: () -> Void

    @Environment(\.locale) private var locale

    @State private var name: String = ""
    @State private var time: Date = Self.defaultTime
    @State private var dayPreset: DayPreset = .weekdays
    @State private var customDays: Set<Weekday> = []
    @State private var durationMinutes: Double = 2
    @State private var disciplineLevel: DisciplineLevel = .strict

    private var isEditing: Bool { fixedBreak != nil }

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Fixed-Time Break" : "New Fixed-Time Break")
                .font(.headline)
                .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameSection
                    timeSection
                    daysSection
                    durationSection
                    levelSection
                }
                .padding(20)
            }
            Divider()
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add Break") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 440, height: 500)
        .onAppear { load() }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.subheadline.weight(.medium))
            TextField("e.g. Lunch", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time")
                .font(.subheadline.weight(.medium))
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Days")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 8) {
                presetButton("Weekdays", preset: .weekdays)
                presetButton("Weekends", preset: .weekends)
                presetButton("Every Day", preset: .everyDay)
                presetButton("Custom", preset: .custom)
            }

            if dayPreset == .custom {
                HStack(spacing: 4) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let isSelected = customDays.contains(day)
                        Button(WeekdaySymbols(locale: locale).short(for: day)) {
                            if isSelected { customDays.remove(day) }
                            else { customDays.insert(day) }
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Break duration")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 4) {
                TextField("", value: $durationMinutes, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .onChange(of: durationMinutes) { newValue in
                        durationMinutes = max(0.1, min(60, newValue))
                    }
                Stepper("", value: $durationMinutes, in: 0.1...60, step: 1)
                    .labelsHidden()
                Text("min")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discipline Level")
                .font(.subheadline.weight(.medium))
            DisciplineLevelPicker(selection: $disciplineLevel)
        }
    }

    // MARK: - Helpers

    private func presetButton(_ label: LocalizedStringKey, preset: DayPreset) -> some View {
        Button(label) { dayPreset = preset }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(dayPreset == preset ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .foregroundStyle(dayPreset == preset ? .white : .primary)
    }

    private func load() {
        guard let existing = fixedBreak else { return }
        name = existing.name
        time = Calendar.current.date(
            bySettingHour: existing.hour, minute: existing.minute, second: 0, of: Date()
        ) ?? Self.defaultTime
        durationMinutes = existing.duration / 60
        disciplineLevel = existing.disciplineLevel
        switch existing.days {
        case .everyDay: dayPreset = .everyDay
        case .weekdays: dayPreset = .weekdays
        case .weekends: dayPreset = .weekends
        case .custom(let days):
            dayPreset = .custom
            customDays = days
        }
    }

    private func save() {
        let days: DaySelection = switch dayPreset {
        case .everyDay: .everyDay
        case .weekdays: .weekdays
        case .weekends: .weekends
        case .custom: .custom(customDays.isEmpty ? [.monday] : customDays)
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        onSave(FixedTimeBreak(
            id: fixedBreak?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            isEnabled: fixedBreak?.isEnabled ?? true,
            days: days,
            hour: parts.hour ?? 12,
            minute: parts.minute ?? 30,
            duration: (durationMinutes * 60).rounded(),
            disciplineLevel: disciplineLevel
        ))
    }
}

private enum DayPreset {
    case everyDay, weekdays, weekends, custom
}
