//
//  SharedDataManager.swift
//  fasttodo
//

import SwiftData
import Foundation

class SharedDataManager {
    static let shared = SharedDataManager()
    static let appGroupIdentifier = "group.com.gill.fasttodo"

    let container: ModelContainer

    private init() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            fatalError("Could not find App Group container")
        }

        let storeURL = containerURL.appendingPathComponent("fasttodo.sqlite")
        let schema = Schema([TodoItem.self])
        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }

    func addTask(rawInput: String) throws {
        let parser = NaturalLanguageParser()
        let parsed = parser.parse(rawInput)

        let context = ModelContext(container)

        let task = TodoItem(
            title: parsed.title,
            rawInput: rawInput,
            scheduledDate: parsed.scheduledDate,
            hasSpecificTime: parsed.hasSpecificTime,
            recurrenceRule: parsed.recurrenceRule
        )

        context.insert(task)
        try context.save()
    }
}
