//
//  QuickAddWidget.swift
//  FastTodoWidget
//

import WidgetKit
import SwiftUI

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), taskCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), taskCount: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        // Try to get today's task count from shared container
        var taskCount = 0
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gill.fasttodo"
        ) {
            // We could query SwiftData here, but keeping it simple for now
            taskCount = 0
        }

        let entry = SimpleEntry(date: Date(), taskCount: taskCount)
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let taskCount: Int
}

// MARK: - Small Widget (Tap to add)
struct QuickAddSmallView: View {
    var body: some View {
        Link(destination: URL(string: "fasttodo://add")!) {
            VStack(spacing: 8) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.orange.gradient)
                        .frame(width: 50, height: 50)

                    Image(systemName: "plus")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }

                Text("Add Task")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget (More info + tap to add)
struct QuickAddMediumView: View {
    var body: some View {
        Link(destination: URL(string: "fasttodo://add")!) {
            HStack(spacing: 16) {
                // Left side - branding
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)
                        Text("fasttodo")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    Text("Tap to add a task")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Right side - add button
                ZStack {
                    Circle()
                        .fill(.orange.gradient)
                        .frame(width: 56, height: 56)

                    Image(systemName: "plus")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct QuickAddWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickAddProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            QuickAddSmallView()
        case .systemMedium:
            QuickAddMediumView()
        default:
            QuickAddSmallView()
        }
    }
}

struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Add")
        .description("Tap to quickly add a task")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    QuickAddWidget()
} timeline: {
    SimpleEntry(date: .now, taskCount: 3)
}

#Preview(as: .systemMedium) {
    QuickAddWidget()
} timeline: {
    SimpleEntry(date: .now, taskCount: 3)
}
