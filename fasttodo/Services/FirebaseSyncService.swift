import Foundation
import SwiftData
import CloudKit
import FirebaseCore
import FirebaseFirestore

// MARK: - Firebase Sync Service

@MainActor
final class FirebaseSyncService {
    static let shared = FirebaseSyncService()

    var isSyncing: Bool = false
    var isAuthenticated: Bool = false
    var lastSyncTime: Date?

    private var db: Firestore?
    private var listener: ListenerRegistration?
    private var userId: String?
    private var modelContext: ModelContext?
    private var isSyncingFromRemote: Bool = false

    private init() {}

    // MARK: - Setup

    func configure() {
        print("[Firebase] 🔧 configure() called")

        guard FirebaseApp.app() == nil else {
            print("[Firebase] ⚠️ Firebase already configured")
            return
        }

        FirebaseApp.configure()
        print("[Firebase] ✅ FirebaseApp.configure() completed")

        // Disable Firestore's local cache - we use SwiftData for local storage
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()  // Memory only, no disk persistence

        db = Firestore.firestore()
        db?.settings = settings
        print("[Firebase] ✅ Firestore initialized with memory-only cache")
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Authentication via iCloud

    func signInWithiCloud() async throws {
        print("[Firebase] 🔐 signInWithiCloud() called")

        let container = CKContainer.default()
        print("[Firebase] Using CloudKit container: \(container.containerIdentifier ?? "default")")

        let recordID = try await container.userRecordID()

        // Use the iCloud record name as the user ID (same across all devices with same Apple ID)
        userId = recordID.recordName
        isAuthenticated = true
        print("[Firebase] ✅ Authenticated with iCloud ID: \(recordID.recordName)")
        print("[Firebase] userId is now set: \(userId ?? "nil")")
    }

    // MARK: - Real-time Listener

    func startListening() {
        print("[Firebase] 👂 startListening() called")

        guard let userId = userId else {
            print("[Firebase] ❌ Cannot start listening - userId is nil")
            return
        }

        guard let db = db else {
            print("[Firebase] ❌ Cannot start listening - db is nil")
            return
        }

        // Remove existing listener
        listener?.remove()

        let path = "users/\(userId)/todos"
        print("[Firebase] 📡 Setting up listener at path: \(path)")

        // Listen to user's todos collection
        listener = db.collection("users").document(userId).collection("todos")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("[Firebase] ❌ Listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot = snapshot else {
                    print("[Firebase] ⚠️ Listener received nil snapshot")
                    return
                }

                print("[Firebase] 📥 Listener received \(snapshot.documents.count) documents, \(snapshot.documentChanges.count) changes")

                Task { @MainActor in
                    self.isSyncingFromRemote = true
                    await self.handleRemoteChanges(snapshot)
                    self.isSyncingFromRemote = false
                    self.lastSyncTime = Date()
                }
            }

        print("[Firebase] ✅ Started listening for changes")
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Force Fetch from Firestore

    func forceFetch() async {
        guard let userId = userId, let db = db, let modelContext = modelContext else {
            print("[Firebase] Cannot force fetch - not authenticated or no context")
            return
        }

        isSyncing = true
        print("[Firebase] Force fetching from Firestore...")

        do {
            // Force fetch from server, not cache
            let snapshot = try await db.collection("users").document(userId).collection("todos").getDocuments(source: .server)

            isSyncingFromRemote = true

            // Get all remote todo IDs
            var remoteTodoIds = Set<UUID>()

            for document in snapshot.documents {
                let data = document.data()
                if let idString = data["id"] as? String, let uuid = UUID(uuidString: idString) {
                    remoteTodoIds.insert(uuid)
                }
                await upsertLocalTodo(from: data, documentId: document.documentID)
            }

            // Delete local todos that don't exist on server (Firestore is source of truth)
            let descriptor = FetchDescriptor<TodoItem>()
            if let localTodos = try? modelContext.fetch(descriptor) {
                for localTodo in localTodos {
                    if !remoteTodoIds.contains(localTodo.id) {
                        // Check if this todo was recently created locally (within last 10 seconds)
                        // If so, push it to Firebase instead of deleting
                        let timeSinceCreation = Date().timeIntervalSince(localTodo.createdAt)
                        if timeSinceCreation < 10 {
                            // Recently created locally, push to Firebase
                            pushTodo(localTodo)
                        } else {
                            // Not in Firestore and not recent - delete locally
                            print("[Firebase] Deleting local todo not in Firestore: \(localTodo.title)")
                            // Cancel notification for deleted task
                            NotificationService.shared.cancelNotification(for: localTodo.id)
                            modelContext.delete(localTodo)
                        }
                    }
                }
            }

            try? modelContext.save()
            isSyncingFromRemote = false
            lastSyncTime = Date()
            print("[Firebase] Force fetch complete - \(snapshot.documents.count) todos")

        } catch {
            print("[Firebase] Force fetch error: \(error.localizedDescription)")
            isSyncingFromRemote = false
        }

        isSyncing = false
    }

    // MARK: - Handle Remote Changes

    private func handleRemoteChanges(_ snapshot: QuerySnapshot) async {
        guard let modelContext = modelContext else { return }

        for change in snapshot.documentChanges {
            let data = change.document.data()
            let documentId = change.document.documentID

            switch change.type {
            case .added, .modified:
                await upsertLocalTodo(from: data, documentId: documentId)
            case .removed:
                await deleteLocalTodo(documentId: documentId)
            }
        }

        try? modelContext.save()
    }

    private func upsertLocalTodo(from data: [String: Any], documentId: String) async {
        guard let modelContext = modelContext else { return }
        guard let idString = data["id"] as? String,
              let uuid = UUID(uuidString: idString) else { return }

        // Check if todo already exists
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
        let existing = try? modelContext.fetch(descriptor).first

        let remoteUpdatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast

        if let todo = existing {
            // Only update if remote is newer
            if remoteUpdatedAt > todo.updatedAt {
                updateTodoFromFirestore(todo, data: data)
                // Update notification for synced task
                NotificationService.shared.updateNotification(for: todo)
            }
        } else {
            // Create new todo from remote
            let todo = createTodoFromFirestore(data: data)
            modelContext.insert(todo)
            // Schedule notification for new synced task
            NotificationService.shared.scheduleNotification(for: todo)
            print("[Firebase] 🔔 Scheduled notification for synced task: \(todo.title)")
        }
    }

    private func deleteLocalTodo(documentId: String) async {
        guard let modelContext = modelContext else { return }
        guard let uuid = UUID(uuidString: documentId) else { return }

        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
        if let todo = try? modelContext.fetch(descriptor).first {
            // Cancel notification for deleted task
            NotificationService.shared.cancelNotification(for: todo.id)
            print("[Firebase] 🔕 Cancelled notification for deleted task: \(todo.title)")
            modelContext.delete(todo)
        }
    }

    // MARK: - Push Changes to Firebase

    func pushTodo(_ todo: TodoItem) {
        print("[Firebase] pushTodo called for: \(todo.title)")

        if isSyncingFromRemote {
            print("[Firebase] ⚠️ Skipping push - currently syncing from remote")
            return
        }

        guard let userId = userId else {
            print("[Firebase] ❌ Cannot push - userId is nil (not authenticated)")
            return
        }

        guard let db = db else {
            print("[Firebase] ❌ Cannot push - db is nil (not configured)")
            return
        }

        let data = todoToFirestore(todo)
        let path = "users/\(userId)/todos/\(todo.id.uuidString)"
        print("[Firebase] 📤 Pushing to path: \(path)")

        db.collection("users").document(userId).collection("todos")
            .document(todo.id.uuidString)
            .setData(data, merge: true) { error in
                if let error = error {
                    print("[Firebase] ❌ Error pushing todo: \(error.localizedDescription)")
                } else {
                    print("[Firebase] ✅ Successfully pushed todo: \(todo.title)")
                }
            }
    }

    func deleteTodo(_ todo: TodoItem) {
        print("[Firebase] 🗑️ deleteTodo called for: \(todo.title) (id: \(todo.id.uuidString))")

        guard let userId = userId else {
            print("[Firebase] ❌ Cannot delete - userId is nil (not authenticated)")
            return
        }

        guard let db = db else {
            print("[Firebase] ❌ Cannot delete - db is nil (not configured)")
            return
        }

        let path = "users/\(userId)/todos/\(todo.id.uuidString)"
        print("[Firebase] 🗑️ Deleting from path: \(path)")

        db.collection("users").document(userId).collection("todos")
            .document(todo.id.uuidString)
            .delete { error in
                if let error = error {
                    print("[Firebase] ❌ Error deleting todo: \(error.localizedDescription)")
                } else {
                    print("[Firebase] ✅ Successfully deleted todo: \(todo.title)")
                }
            }
    }

    func syncAllTodos(_ todos: [TodoItem]) async {
        isSyncing = true

        // Fetch from Firestore (source of truth)
        // This will also delete local todos not in Firestore
        // and push only recently created local todos
        await forceFetch()

        isSyncing = false
        lastSyncTime = Date()
    }

    // MARK: - Conversion Helpers

    private func todoToFirestore(_ todo: TodoItem) -> [String: Any] {
        var data: [String: Any] = [
            "id": todo.id.uuidString,
            "title": todo.title,
            "rawInput": todo.rawInput,
            "hasSpecificTime": todo.hasSpecificTime,
            "isCompleted": todo.isCompleted,
            "createdAt": Timestamp(date: todo.createdAt),
            "updatedAt": Timestamp(date: todo.updatedAt),
            "sortOrder": todo.sortOrder
        ]

        if let scheduledDate = todo.scheduledDate {
            data["scheduledDate"] = Timestamp(date: scheduledDate)
        }

        if let completedAt = todo.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        if let recurrenceData = todo.recurrenceData {
            data["recurrenceData"] = recurrenceData.base64EncodedString()
        }

        return data
    }

    private func createTodoFromFirestore(data: [String: Any]) -> TodoItem {
        let todo = TodoItem(
            title: data["title"] as? String ?? "",
            rawInput: data["rawInput"] as? String ?? ""
        )

        if let idString = data["id"] as? String, let uuid = UUID(uuidString: idString) {
            todo.id = uuid
        }

        updateTodoFromFirestore(todo, data: data)
        return todo
    }

    private func updateTodoFromFirestore(_ todo: TodoItem, data: [String: Any]) {
        todo.title = data["title"] as? String ?? todo.title
        todo.rawInput = data["rawInput"] as? String ?? todo.rawInput
        todo.hasSpecificTime = data["hasSpecificTime"] as? Bool ?? todo.hasSpecificTime
        todo.isCompleted = data["isCompleted"] as? Bool ?? todo.isCompleted
        todo.sortOrder = data["sortOrder"] as? Int ?? todo.sortOrder

        if let timestamp = data["scheduledDate"] as? Timestamp {
            todo.scheduledDate = timestamp.dateValue()
        }

        if let timestamp = data["completedAt"] as? Timestamp {
            todo.completedAt = timestamp.dateValue()
        }

        if let timestamp = data["createdAt"] as? Timestamp {
            todo.createdAt = timestamp.dateValue()
        }

        if let timestamp = data["updatedAt"] as? Timestamp {
            todo.updatedAt = timestamp.dateValue()
        }

        if let base64String = data["recurrenceData"] as? String,
           let recurrenceData = Data(base64Encoded: base64String) {
            todo.recurrenceData = recurrenceData
        }
    }
}
