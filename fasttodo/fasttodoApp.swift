//
//  fasttodoApp.swift
//  fasttodo
//
//  Created by Sukhman Singh on 12/15/25.
//

import SwiftUI
import SwiftData

@main
struct fasttodoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TodoItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Request notification permission on app launch
        NotificationService.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
