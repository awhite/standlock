import SwiftUI
import StandLockCore

/// Fixed-time breaks, listed under the repeating schedules on the Schedules tab.
struct FixedTimeBreaksSection: View {
    @ObservedObject var store: FixedTimeBreakStore
    @EnvironmentObject private var languageStore: LanguageStore
    @State private var sheetMode: SheetMode?
    @State private var pendingDelete: FixedTimeBreak?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fixed-Time Breaks")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    sheetMode = .add
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if store.breaks.isEmpty {
                Text("Interrupt yourself at a set time, such as lunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.breaks) { fixedBreak in
                            FixedTimeBreakRow(
                                fixedBreak: fixedBreak,
                                onToggle: { enabled in
                                    var updated = fixedBreak
                                    updated.isEnabled = enabled
                                    store.update(updated)
                                },
                                onEdit: { sheetMode = .edit(fixedBreak) },
                                onDelete: { pendingDelete = fixedBreak }
                            )
                        }
                    }
                }
                .frame(maxHeight: 130)
            }
        }
        .padding(12)
        .sheet(item: $sheetMode) { mode in
            LocalizedRoot(store: languageStore) {
                FixedTimeBreakFormView(
                    fixedBreak: mode.fixedBreak,
                    onSave: { fixedBreak in
                        switch mode {
                        case .add: store.add(fixedBreak)
                        case .edit: store.update(fixedBreak)
                        }
                        sheetMode = nil
                    },
                    onCancel: { sheetMode = nil }
                )
            }
        }
        .confirmationDialog(
            "Delete \"\(pendingDelete?.name ?? "")\"?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { fixedBreak in
            Button("Delete", role: .destructive) { store.delete(fixedBreak) }
        }
    }
}

private enum SheetMode: Identifiable {
    case add
    case edit(FixedTimeBreak)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let fixedBreak): fixedBreak.id.uuidString
        }
    }

    var fixedBreak: FixedTimeBreak? {
        switch self {
        case .add: nil
        case .edit(let fixedBreak): fixedBreak
        }
    }
}

private struct FixedTimeBreakRow: View {
    let fixedBreak: FixedTimeBreak
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var checker: PermissionChecker
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { fixedBreak.isEnabled }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .tint(.green)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(fixedBreak.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(fixedBreak.isEnabled ? .primary : .secondary)
                HStack(spacing: 8) {
                    Text(timeSummary)
                    Text("•")
                    Text(daysSummary)
                    Text("•")
                    Text(durationSummary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if checker.strictIsInactive(for: fixedBreak.schedule) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Strict inactive, running as Firm")
                        Button("Grant") { checker.requestStrictPermission() }
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            Menu {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                Divider()
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var timeSummary: String {
        var components = DateComponents()
        components.hour = fixedBreak.hour
        components.minute = fixedBreak.minute
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    private var daysSummary: String {
        let symbols = WeekdaySymbols(locale: locale)
        switch fixedBreak.days {
        case .everyDay: return languageStore.string("Every day")
        case .weekdays: return "\(symbols.short(for: .monday))-\(symbols.short(for: .friday))"
        case .weekends: return "\(symbols.short(for: .saturday))-\(symbols.short(for: .sunday))"
        case .custom(let days):
            return days.sorted().map(symbols.short(for:)).joined(separator: ", ")
        }
    }

    private var durationSummary: String {
        let minutes = fixedBreak.duration / 60
        let value = minutes.formatted(.number.precision(.fractionLength(0...1)))
        return "\(value) \(languageStore.string("min"))"
    }
}
