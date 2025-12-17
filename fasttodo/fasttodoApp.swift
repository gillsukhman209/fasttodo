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
        let schema = Schema([TodoItem.self])

        // Try App Group container first (for widget access), fall back to default
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gill.fasttodo"
        ) {
            let storeURL = containerURL.appendingPathComponent("fasttodo.sqlite")
            let config = ModelConfiguration(schema: schema, url: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                print("Failed to create shared container: \(error)")
            }
        }

        // Fallback to default container
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        NotificationService.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    // Handle fasttodo://add URL from widget
                    if url.scheme == "fasttodo" && url.host == "add" {
                        AppState.shared.shouldFocusInput = true
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
