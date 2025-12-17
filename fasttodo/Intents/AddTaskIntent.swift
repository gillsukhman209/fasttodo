//
//  AddTaskIntent.swift
//  fasttodo
//

import AppIntents
import SwiftData

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to FastTodo")

    @Parameter(title: "Task", description: "What do you need to do? e.g. 'Buy milk tomorrow at 3pm'")
    var taskText: String

    init() {}

    init(taskText: String) {
        self.taskText = taskText
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try SharedDataManager.shared.addTask(rawInput: taskText)
        return .result(value: "Added: \(taskText)")
    }
}
