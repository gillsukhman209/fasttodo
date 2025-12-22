import SwiftUI
import SwiftData
#if os(iOS)
import WidgetKit
import UIKit
#endif

struct TaskEditSheet: View {
    @Bindable var task: TodoItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var selectedDate: Date = Date()
    @State private var hasDate: Bool = false
    @State private var hasTime: Bool = false
    @State private var selectedRecurrence: RecurrenceOption = .none

    enum RecurrenceOption: String, CaseIterable {
        case none = "None"
        case daily = "Daily"
        case weekdays = "Weekdays"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var rule: RecurrenceRule? {
            switch self {
            case .none: return nil
            case .daily: return .daily
            case .weekdays: return .weekdays
            case .weekly: return .weekly
            case .monthly: return .monthly
            }
        }

        static func from(_ rule: RecurrenceRule?) -> RecurrenceOption {
            guard let rule = rule else { return .none }
            if rule.daysOfWeek == [2, 3, 4, 5, 6] { return .weekdays }
            switch rule.frequency {
            case .daily: return .daily
            case .weekly: return .weekly
            case .monthly: return .monthly
            case .yearly: return .none
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        // Title field
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("TITLE")
                                .font(Theme.Fonts.micro)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(1.5)

                            TextField("Task title", text: $title)
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .padding(Theme.Space.md)
                                .background {
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                        .fill(Theme.Colors.bgSecondary)
                                }
                        }

                        // Date toggle
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("SCHEDULE")
                                .font(Theme.Fonts.micro)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(1.5)

                            Toggle(isOn: $hasDate) {
                                HStack(spacing: Theme.Space.md) {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(Theme.Colors.accent)
                                    Text("Add date")
                                        .font(Theme.Fonts.body)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                            }
                            .tint(Theme.Colors.accent)
                            .padding(Theme.Space.md)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(Theme.Colors.bgSecondary)
                            }

                            if hasDate {
                                DatePicker(
                                    "Date",
                                    selection: $selectedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(Theme.Colors.accent)
                                .padding(Theme.Space.md)
                                .background {
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                        .fill(Theme.Colors.bgSecondary)
                                }

                                Toggle(isOn: $hasTime) {
                                    HStack(spacing: Theme.Space.md) {
                                        Image(systemName: "clock")
                                            .foregroundStyle(Theme.Colors.accent)
                                        Text("Add time")
                                            .font(Theme.Fonts.body)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                    }
                                }
                                .tint(Theme.Colors.accent)
                                .padding(Theme.Space.md)
                                .background {
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                        .fill(Theme.Colors.bgSecondary)
                                }

                                if hasTime {
                                    DatePicker(
                                        "Time",
                                        selection: $selectedDate,
                                        displayedComponents: .hourAndMinute
                                    )
                                    #if os(iOS)
                                    .datePickerStyle(.wheel)
                                    #endif
                                    .labelsHidden()
                                    .tint(Theme.Colors.accent)
                                    .padding(Theme.Space.md)
                                    .background {
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .fill(Theme.Colors.bgSecondary)
                                    }
                                }
                            }
                        }

                        // Recurrence
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text("REPEAT")
                                .font(Theme.Fonts.micro)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(1.5)

                            ForEach(RecurrenceOption.allCases, id: \.self) { option in
                                Button {
                                    selectedRecurrence = option
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                            .font(Theme.Fonts.body)
                                            .foregroundStyle(Theme.Colors.textPrimary)

                                        Spacer()

                                        if selectedRecurrence == option {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Theme.Colors.accent)
                                        }
                                    }
                                    .padding(Theme.Space.md)
                                    .background {
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .fill(selectedRecurrence == option
                                                  ? Theme.Colors.accent.opacity(0.1)
                                                  : Theme.Colors.bgSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer().frame(height: Theme.Space.xl)
                    }
                    .padding(Theme.Space.lg)
                }
            }
            .navigationTitle("Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .onAppear {
            loadTaskData()
        }
    }

    private func loadTaskData() {
        title = task.title
        hasDate = task.scheduledDate != nil
        hasTime = task.hasSpecificTime
        selectedDate = task.scheduledDate ?? Date()
        selectedRecurrence = RecurrenceOption.from(task.recurrenceRule)
    }

    private func saveChanges() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.scheduledDate = hasDate ? selectedDate : nil
        task.hasSpecificTime = hasDate && hasTime
        task.recurrenceRule = selectedRecurrence.rule
        task.updatedAt = Date()

        // Update notification (cancel old, schedule new if applicable)
        NotificationService.shared.updateNotification(for: task)

        // Save and refresh widget immediately
        try? modelContext.save()
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview {
    TaskEditSheet(task: TodoItem(
        title: "Call mom",
        rawInput: "Call mom at 7pm",
        scheduledDate: Date(),
        hasSpecificTime: true
    ))
    .modelContainer(for: TodoItem.self, inMemory: true)
}
