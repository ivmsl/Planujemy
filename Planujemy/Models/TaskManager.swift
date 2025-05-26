import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Private Task Manager
@MainActor
class PrivateTaskManager: ObservableObject {
    private let db = Firestore.firestore()
    private let modelContext: ModelContext
    
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Main Sync Functions
    
    /// Complete sync for private tasks and tags
    func syncAllPrivateData() async {
        guard let currentUser = Auth.auth().currentUser else {
            await updateError("User not authenticated")
            return
        }
        
        await updateLoadingState(true)
        
        do {
            // Sync in order: Tags first, then tasks (for proper linking)
            try await syncTags()
            try await syncPrivateTasks()
            await linkTasksWithTags()
            
            await updateSyncSuccess()
            print("✅ Private data sync completed successfully")
            
        } catch {
            await updateError("Sync failed: \(error.localizedDescription)")
            print("❌ Sync failed: \(error)")
        }
        
        await updateLoadingState(false)
    }
    
    /// Quick sync - only upload unsynced local changes
    func quickSync() async {
        guard Auth.auth().currentUser != nil else { return }
        
        do {
            try await uploadUnsyncedTags()
            try await uploadUnsyncedPrivateTasks()
            print("✅ Quick sync completed")
        } catch {
            print("❌ Quick sync failed: \(error)")
        }
    }
    
    // MARK: - Tag Management
    
    /// Sync all tags (upload unsynced + download from Firebase)
    private func syncTags() async throws {
        try await uploadUnsyncedTags()
        try await downloadTags()
    }
    
    /// Upload locally created/modified tags to Firebase
    private func uploadUnsyncedTags() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PrivateTaskError.notAuthenticated
        }
        
        // Fetch unsynced tags
        let unsyncedTagsDescriptor = FetchDescriptor<TaskTag>(
            predicate: #Predicate { $0.IsSynced == false }
        )
        
        let unsyncedTags = try modelContext.fetch(unsyncedTagsDescriptor)
        
        for tag in unsyncedTags {
            let tagRef: DocumentReference
            
            if let existingFID = tag.fID {
                // Update existing Firebase document
                tagRef = db.collection("users")
                    .document(currentUser.uid)
                    .collection("tags")
                    .document(existingFID)
            } else {
                // Create new Firebase document
                tagRef = db.collection("users")
                    .document(currentUser.uid)
                    .collection("tags")
                    .document()
                
                // Store Firebase ID in local model
                tag.fID = tagRef.documentID
            }
            
            try await tagRef.setData(tag.toFirebaseData())
            
            // Mark as synced
            tag.IsSynced = true
            print("📤 Uploaded tag: \(tag.name)")
        }
        
        if !unsyncedTags.isEmpty {
            try modelContext.save()
        }
    }
    
    /// Download tags from Firebase
    private func downloadTags() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PrivateTaskError.notAuthenticated
        }
        
        let snapshot = try await db.collection("users")
            .document(currentUser.uid)
            .collection("tags")
            .getDocuments()
        
        for document in snapshot.documents {
            if let firebaseTag = TaskTag.fromFirebaseData(document.data(), fID: document.documentID) {
                await handleIncomingTag(firebaseTag)
            }
        }
    }
    
    /// Handle incoming tag from Firebase
    private func handleIncomingTag(_ firebaseTag: TaskTag) async {
        // Check if tag exists locally by Firebase ID
        let firebaseFID = firebaseTag.fID
        let fetchDescriptor = FetchDescriptor<TaskTag>(
            predicate: #Predicate<TaskTag> { tag in
                tag.fID == firebaseFID
            }
        )
        
        do {
            let existingTags = try modelContext.fetch(fetchDescriptor)
            
            if let localTag = existingTags.first {
                // Tag exists - check for conflicts
                if !localTag.IsSynced {
                    // Local changes not synced - keep local version
                    print("⚠️ Tag conflict kept local: \(localTag.name)")
                } else {
                    // Update local with Firebase version
                    updateLocalTag(localTag, with: firebaseTag)
                    print("📥 Updated tag: \(localTag.name)")
                }
            } else {
                // New tag from Firebase
                modelContext.insert(firebaseTag)
                print("📥 Downloaded new tag: \(firebaseTag.name)")
            }
            
            try modelContext.save()
        } catch {
            print("❌ Error handling incoming tag: \(error)")
        }
    }
    
    /// Update local tag with Firebase data
    private func updateLocalTag(_ local: TaskTag, with remote: TaskTag) {
        local.name = remote.name
        local.col = remote.col
        local.symImage = remote.symImage
        local.owner_fID = remote.owner_fID
        local.IsSynced = true
    }
    
    // MARK: - Private Task Management
    
    /// Sync all private tasks (upload unsynced + download from Firebase)
    private func syncPrivateTasks() async throws {
        try await uploadUnsyncedPrivateTasks()
        try await downloadPrivateTasks()
    }
    
    /// Upload locally created/modified private tasks to Firebase
    private func uploadUnsyncedPrivateTasks() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PrivateTaskError.notAuthenticated
        }
        
        // Fetch unsynced private tasks
        let unsyncedTasksDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate {
                $0.IsSynced == false && $0.IsShared == false
            }
        )
        
        let unsyncedTasks = try modelContext.fetch(unsyncedTasksDescriptor)
        
        for task in unsyncedTasks {
            let taskRef: DocumentReference
            
            if let existingFID = task.fID {
                // Update existing Firebase document
                taskRef = db.collection("users")
                    .document(currentUser.uid)
                    .collection("personal_tasks")
                    .document(existingFID)
            } else {
                // Create new Firebase document
                taskRef = db.collection("users")
                    .document(currentUser.uid)
                    .collection("personal_tasks")
                    .document()
                
                // Store Firebase ID in local model
                task.fID = taskRef.documentID
            }
            
            try await taskRef.setData(task.toFirebaseDataPrivate())
            
            // Mark as synced
            task.IsSynced = true
            print("📤 Uploaded private task: \(task.title)")
        }
        
        if !unsyncedTasks.isEmpty {
            try modelContext.save()
        }
    }
    
    /// Download private tasks from Firebase
    private func downloadPrivateTasks() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PrivateTaskError.notAuthenticated
        }
        
        let snapshot = try await db.collection("users")
            .document(currentUser.uid)
            .collection("personal_tasks")
            .getDocuments()
        
        for document in snapshot.documents {
            if let firebaseTask = PTask.fromFirebaseDataPrivate(document.data(), fID: document.documentID) {
                await handleIncomingPrivateTask(firebaseTask)
            }
        }
    }
    
    /// Handle incoming private task from Firebase
    private func handleIncomingPrivateTask(_ firebaseTask: PTask) async {
        // Check if task exists locally by Firebase ID
        let firebaseFID = firebaseTask.fID
        let fetchDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate<PTask> { task in
                task.fID == firebaseFID
            }
        )
        
        do {
            let existingTasks = try modelContext.fetch(fetchDescriptor)
            
            if let localTask = existingTasks.first {
                // Task exists - check for conflicts
                if !localTask.IsSynced {
                    // Local changes not synced - keep local version
                    print("⚠️ Task conflict kept local: \(localTask.title)")
                } else {
                    // Update local with Firebase version
                    updateLocalPrivateTask(localTask, with: firebaseTask)
                    print("📥 Updated private task: \(localTask.title)")
                }
            } else {
                // New task from Firebase
                modelContext.insert(firebaseTask)
                print("📥 Downloaded new private task: \(firebaseTask.title)")
            }
            
            try modelContext.save()
        } catch {
            print("❌ Error handling incoming private task: \(error)")
        }
    }
    
    /// Update local private task with Firebase data
    private func updateLocalPrivateTask(_ local: PTask, with remote: PTask) {
        local.title = remote.title
        local.desc = remote.desc
        local.date = remote.date
        local.AutoReminder = remote.AutoReminder
        local.IsUrgent = remote.IsUrgent
        local.IsImportant = remote.IsImportant
        local.IsDone = remote.IsDone
        local.IsAutoComplete = remote.IsAutoComplete
        local.IsAutoFail = remote.IsAutoFail
        local.DateOfCompletion = remote.DateOfCompletion
        local.DateOfLastReminder = remote.DateOfLastReminder
        local.tagID = remote.tagID
        local.from_user_fID = remote.from_user_fID
        local.to_user_fID = remote.to_user_fID
        local.FromUserName = remote.FromUserName
        local.ToUserName = remote.ToUserName
        local.ReceivedDate = remote.ReceivedDate
        local.IsSynced = true
    }
    
    /// Link tasks with their tags after sync
    private func linkTasksWithTags() async {
        let allPrivateTasksDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate { $0.IsShared == false }
        )
        
        let allTagsDescriptor = FetchDescriptor<TaskTag>()
        
        do {
            let allPrivateTasks = try modelContext.fetch(allPrivateTasksDescriptor)
            let allTags = try modelContext.fetch(allTagsDescriptor)
            
            for task in allPrivateTasks {
                if let tagID = task.tagID,
                   let matchingTag = allTags.first(where: { $0.fID == tagID }) {
                    task.tag = matchingTag
                    print("🔗 Linked task '\(task.title)' with tag '\(matchingTag.name)'")
                }
            }
            
            try modelContext.save()
        } catch {
            print("❌ Error linking tasks with tags: \(error)")
        }
    }
    
    // MARK: - Individual Operations
    
    /// Create and sync new private task
    func createPrivateTask(title: String, date: Date, desc: String? = nil, tag: TaskTag? = nil, opt: [TaskOptions] = [.Usual]) async {
        let newTask = PTask(title: title, date: date, desc: desc, tag: tag, opt: opt)
        newTask.IsShared = false // Ensure it's private
        
        // Set tagID to Firebase ID if tag exists
        if let tag = tag {
            newTask.tagID = tag.fID
        }
        
        modelContext.insert(newTask)
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            try await uploadSinglePrivateTask(newTask)
            print("✅ Created and synced private task: \(title)")
        } catch {
            print("❌ Error creating private task: \(error)")
        }
    }
    
    /// Create and sync new tag
    func createTag(name: String, symImage: String? = nil) async {
        let newTag = TaskTag(name: name, symImage: symImage)
        
        modelContext.insert(newTag)
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            try await uploadSingleTag(newTag)
            print("✅ Created and synced tag: \(name)")
        } catch {
            print("❌ Error creating tag: \(error)")
        }
    }
    
    /// Mark task as modified and needs sync
    func markTaskForSync(_ task: PTask) {
        guard !task.IsShared else { return } // Only handle private tasks
        
        task.IsSynced = false
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error marking task for sync: \(error)")
        }
    }
    
    /// Mark tag as modified and needs sync
    func markTagForSync(_ tag: TaskTag) {
        tag.IsSynced = false
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Error marking tag for sync: \(error)")
        }
    }
    
    /// Delete private task (local and Firebase)
    func deletePrivateTask(_ task: PTask) async {
        guard !task.IsShared else { return } // Only handle private tasks
        
        // Delete from Firebase first if it has Firebase ID
        if let currentUser = Auth.auth().currentUser,
           let fID = task.fID {
            let taskRef = db.collection("users")
                .document(currentUser.uid)
                .collection("personal_tasks")
                .document(fID)
            
            do {
                try await taskRef.delete()
                print("🗑️ Deleted task from Firebase: \(task.title)")
            } catch {
                print("❌ Error deleting task from Firebase: \(error)")
            }
        }
        
        // Delete from local storage
        modelContext.delete(task)
        
        do {
            try modelContext.save()
            print("🗑️ Deleted task locally: \(task.title)")
        } catch {
            print("❌ Error deleting task locally: \(error)")
        }
    }
    
    /// Delete tag (local and Firebase)
    func deleteTag(_ tag: TaskTag) async {
        // Delete from Firebase first if it has Firebase ID
        if let currentUser = Auth.auth().currentUser,
           let fID = tag.fID {
            let tagRef = db.collection("users")
                .document(currentUser.uid)
                .collection("tags")
                .document(fID)
            
            do {
                try await tagRef.delete()
                print("🗑️ Deleted tag from Firebase: \(tag.name)")
            } catch {
                print("❌ Error deleting tag from Firebase: \(error)")
            }
        }
        
        // Remove tag from any tasks that use it
        let tagFID = tag.fID
        let tasksWithTagDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate<PTask> { task in
                task.tagID == tagFID
            }
        )
        
        do {
            let tasksWithTag = try modelContext.fetch(tasksWithTagDescriptor)
            for task in tasksWithTag {
                task.tag = nil
                task.tagID = nil
                task.IsSynced = false // Mark for sync to update Firebase
            }
        } catch {
            print("❌ Error updating tasks after tag deletion: \(error)")
        }
        
        // Delete from local storage
        modelContext.delete(tag)
        
        do {
            try modelContext.save()
            print("🗑️ Deleted tag locally: \(tag.name)")
        } catch {
            print("❌ Error deleting tag locally: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func uploadSinglePrivateTask(_ task: PTask) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PrivateTaskError.notAuthenticated
        }
        
        let taskRef: DocumentReference
        
        if let existingFID = task.fID {
            taskRef = db.collection("users")
                .document(currentUser.uid)
                .collection("personal_tasks")
                .document(existingFID)
        } else {
            taskRef = db.collection("users")
                .document(currentUser.uid)
                .collection("personal_tasks")
                .document()
            
            task.fID = taskRef.documentID
        }
        
        try await taskRef.setData(task.toFirebaseDataPrivate())
        task.IsSynced = true
        try modelContext.save()
    }
    
    private func uploadSingleTag(_ tag: TaskTag) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw PrivateTaskError.notAuthenticated
        }
        
        let tagRef: DocumentReference
        
        if let existingFID = tag.fID {
            tagRef = db.collection("users")
                .document(currentUser.uid)
                .collection("tags")
                .document(existingFID)
        } else {
            tagRef = db.collection("users")
                .document(currentUser.uid)
                .collection("tags")
                .document()
            
            tag.fID = tagRef.documentID
        }
        
        try await tagRef.setData(tag.toFirebaseData())
        tag.IsSynced = true
        try modelContext.save()
    }
    
    // MARK: - State Management
    
    private func updateLoadingState(_ isLoading: Bool) async {
        await MainActor.run {
            self.isLoading = isLoading
        }
    }
    
    private func updateError(_ error: String) async {
        await MainActor.run {
            self.syncError = error
        }
    }
    
    private func updateSyncSuccess() async {
        await MainActor.run {
            self.syncError = nil
            self.lastSyncDate = Date()
        }
    }
}

// MARK: - Error Types
enum PrivateTaskError: Error, LocalizedError {
    case notAuthenticated
    case syncFailed(String)
    case invalidTask
    case invalidTag
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .invalidTask:
            return "Invalid task data"
        case .invalidTag:
            return "Invalid tag data"
        }
    }
}

// MARK: - Extensions for Firebase Data Conversion

extension PTask {
    /// Convert private task to Firebase format
    func toFirebaseDataPrivate() -> [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "date": Timestamp(date: date),
            "AutoReminder": AutoReminder,
            "IsUrgent": IsUrgent,
            "IsImportant": IsImportant,
            "IsAutoComplete": IsAutoComplete,
            "IsAutoFail": IsAutoFail,
            "IsDone": IsDone,
            "IsShared": false,
            "lastModified": Timestamp(date: Date())
        ]
        
        if let desc = desc { data["desc"] = desc }
        if let owner = owner_fID { data["owner_fID"] = owner }
        if let tagID = tagID { data["tagID"] = tagID }
        if let fromUser = from_user_fID { data["from_user_fID"] = fromUser }
        if let toUser = to_user_fID { data["to_user_fID"] = toUser }
        if let fromUserName = FromUserName { data["FromUserName"] = fromUserName }
        if let toUserName = ToUserName { data["ToUserName"] = toUserName }
        if let completionDate = DateOfCompletion {
            data["DateOfCompletion"] = Timestamp(date: completionDate)
        }
        if let reminderDate = DateOfLastReminder {
            data["DateOfLastReminder"] = Timestamp(date: reminderDate)
        }
        if let receivedDate = ReceivedDate {
            data["ReceivedDate"] = Timestamp(date: receivedDate)
        }
        
        return data
    }
    
    /// Create private task from Firebase data
    static func fromFirebaseDataPrivate(_ data: [String: Any], fID: String) -> PTask? {
        guard let title = data["title"] as? String,
              let timestamp = data["date"] as? Timestamp else {
            return nil
        }
        
        let task = PTask(title: title, date: timestamp.dateValue())
        task.fID = fID // Set Firebase ID
        task.desc = data["desc"] as? String
        task.owner_fID = data["owner_fID"] as? String
        task.tagID = data["tagID"] as? String
        task.from_user_fID = data["from_user_fID"] as? String
        task.to_user_fID = data["to_user_fID"] as? String
        task.FromUserName = data["FromUserName"] as? String
        task.ToUserName = data["ToUserName"] as? String
        
        // Set boolean properties
        task.AutoReminder = data["AutoReminder"] as? Bool ?? false
        task.IsUrgent = data["IsUrgent"] as? Bool ?? false
        task.IsImportant = data["IsImportant"] as? Bool ?? false
        task.IsDone = data["IsDone"] as? Bool ?? false
        task.IsAutoComplete = data["IsAutoComplete"] as? Bool ?? true
        task.IsAutoFail = data["IsAutoFail"] as? Bool ?? false
        task.IsShared = false // Always false for private tasks
        
        // Set date properties
        if let completionTimestamp = data["DateOfCompletion"] as? Timestamp {
            task.DateOfCompletion = completionTimestamp.dateValue()
        }
        if let reminderTimestamp = data["DateOfLastReminder"] as? Timestamp {
            task.DateOfLastReminder = reminderTimestamp.dateValue()
        }
        if let receivedTimestamp = data["ReceivedDate"] as? Timestamp {
            task.ReceivedDate = receivedTimestamp.dateValue()
        }
        
        task.IsSynced = true // Coming from Firebase means it's synced
        return task
    }
}

extension TaskTag {
    func toFirebaseData() -> [String: Any] {
        return [
            "name": name,
            "col": [
                "r": col.r,
                "g": col.g,
                "b": col.b,
                "a": col.a
            ],
            "symImage": symImage ?? "",
            "owner_fID": owner_fID ?? "",
            "createdAt": Timestamp(date: Date())
        ]
    }
    
    static func fromFirebaseData(_ data: [String: Any], fID: String) -> TaskTag? {
        guard let name = data["name"] as? String,
              let colData = data["col"] as? [String: Double] else {
            return nil
        }
        
        let tag = TaskTag(name: name)
        tag.fID = fID // Set Firebase ID
        tag.owner_fID = data["owner_fID"] as? String
        tag.symImage = data["symImage"] as? String
        
        // Reconstruct color
        tag.col = RGBA(
            r: colData["r"] ?? 0,
            g: colData["g"] ?? 0,
            b: colData["b"] ?? 0,
            a: colData["a"] ?? 1
        )
        
        tag.IsSynced = true
        return tag
    }
}
