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

        // Local storage only - Firebase handles sync, CloudKit explicitly disabled
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Explicitly disable CloudKit sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        NotificationService.shared.requestPermission()
        FirebaseSyncService.shared.configure()
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
                .task {
                    await initializeFirebase()
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }

    @MainActor
    private func initializeFirebase() async {
        do {
            let firebaseSync = FirebaseSyncService.shared

            // Sign in with iCloud (same user ID across all devices)
            try await firebaseSync.signInWithiCloud()

            // Set the model context
            firebaseSync.setModelContext(sharedModelContainer.mainContext)

            // Start listening for remote changes
            firebaseSync.startListening()

            // Sync existing local todos to Firebase
            let descriptor = FetchDescriptor<TodoItem>()
            if let todos = try? sharedModelContainer.mainContext.fetch(descriptor) {
                await firebaseSync.syncAllTodos(todos)
            }
        } catch {
            print("[Firebase] Initialization error: \(error.localizedDescription)")
        }
    }
}
