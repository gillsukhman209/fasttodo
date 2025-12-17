//
//  QuickAddWidget.swift
//  FastTodoWidget
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Task Data for Widget
struct WidgetTask: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let hasTime: Bool
    let displayTime: String?
}

// MARK: - Timeline Entry
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let totalCount: Int
    let completedCount: Int
}

// MARK: - Timeline Provider
struct TaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            tasks: [
                WidgetTask(id: UUID(), title: "Sample task", isCompleted: false, hasTime: false, displayTime: nil)
            ],
            totalCount: 3,
            completedCount: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        let entry = fetchTasks()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let entry = fetchTasks()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchTasks() -> TaskEntry {
        var widgetTasks: [WidgetTask] = []
        var totalCount = 0
        var completedCount = 0

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gill.fasttodo"
        ) else {
            return TaskEntry(date: Date(), tasks: [], totalCount: 0, completedCount: 0)
        }

        let storeURL = containerURL.appendingPathComponent("fasttodo.sqlite")

        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: TodoItem.self, configurations: config)
            let context = ModelContext(container)

            // Fetch today's tasks
            let calendar = Calendar.current
            let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)

            let descriptor = FetchDescriptor<TodoItem>(
                sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
            )

            let allTasks = try context.fetch(descriptor)

            // Filter for today's tasks (no date, today, or overdue)
            let todayTasks = allTasks.filter { task in
                guard let date = task.scheduledDate else { return true }
                return date < startOfTomorrow
            }

            totalCount = todayTasks.count
            completedCount = todayTasks.filter { $0.isCompleted }.count

            // Get incomplete tasks for display (limit to 5)
            let incompleteTasks = todayTasks.filter { !$0.isCompleted }.prefix(5)

            widgetTasks = incompleteTasks.map { task in
                WidgetTask(
                    id: task.id,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    hasTime: task.hasSpecificTime,
                    displayTime: task.displayTime
                )
            }
        } catch {
            print("Widget: Failed to fetch tasks: \(error)")
        }

        return TaskEntry(
            date: Date(),
            tasks: widgetTasks,
            totalCount: totalCount,
            completedCount: completedCount
        )
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    var entry: TaskEntry

    var body: some View {
        Link(destination: URL(string: "fasttodo://add")!) {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                }

                if entry.tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("All done!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // Task list (show up to 3)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entry.tasks.prefix(3)) { task in
                            HStack(spacing: 6) {
                                Circle()
                                    .strokeBorder(.orange, lineWidth: 1.5)
                                    .frame(width: 14, height: 14)

                                Text(task.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    Spacer()

                    // Footer with count
                    if entry.totalCount > 3 {
                        Text("+\(entry.totalCount - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    var entry: TaskEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left side - Task list
            Link(destination: URL(string: "fasttodo://open")!) {
                VStack(alignment: .leading, spacing: 6) {
                    // Header
                    HStack {
                        Text("Today")
                            .font(.headline)
                            .fontWeight(.bold)

                        if entry.totalCount > 0 {
                            Text("\(entry.completedCount)/\(entry.totalCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if entry.tasks.isEmpty {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                            Text("All tasks done!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        // Task list (show up to 4)
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(entry.tasks.prefix(4)) { task in
                                HStack(spacing: 8) {
                                    Circle()
                                        .strokeBorder(.orange, lineWidth: 1.5)
                                        .frame(width: 16, height: 16)

                                    Text(task.title)
                                        .font(.subheadline)
                                        .lineLimit(1)

                                    Spacer()

                                    if let time = task.displayTime {
                                        Text(time)
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }

                        Spacer()

                        if entry.totalCount - entry.completedCount > 4 {
                            Text("+\(entry.totalCount - entry.completedCount - 4) more tasks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            // Right side - Add button
            Link(destination: URL(string: "fasttodo://add")!) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.orange.gradient)
                        .frame(width: 56)

                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Entry View
struct QuickAddWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TaskProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration
struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskProvider()) { entry in
            QuickAddWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("View your tasks and quickly add new ones")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    QuickAddWidget()
} timeline: {
    TaskEntry(
        date: .now,
        tasks: [
            WidgetTask(id: UUID(), title: "Buy groceries", isCompleted: false, hasTime: false, displayTime: nil),
            WidgetTask(id: UUID(), title: "Call mom", isCompleted: false, hasTime: true, displayTime: "3:00 PM"),
            WidgetTask(id: UUID(), title: "Finish report", isCompleted: false, hasTime: false, displayTime: nil)
        ],
        totalCount: 5,
        completedCount: 2
    )
}

#Preview(as: .systemMedium) {
    QuickAddWidget()
} timeline: {
    TaskEntry(
        date: .now,
        tasks: [
            WidgetTask(id: UUID(), title: "Buy groceries", isCompleted: false, hasTime: false, displayTime: nil),
            WidgetTask(id: UUID(), title: "Call mom", isCompleted: false, hasTime: true, displayTime: "3:00 PM"),
            WidgetTask(id: UUID(), title: "Finish report", isCompleted: false, hasTime: false, displayTime: nil),
            WidgetTask(id: UUID(), title: "Go to gym", isCompleted: false, hasTime: true, displayTime: "6:00 PM")
        ],
        totalCount: 6,
        completedCount: 2
    )
}
