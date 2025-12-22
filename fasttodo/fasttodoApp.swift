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

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.gill.fasttodo")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
