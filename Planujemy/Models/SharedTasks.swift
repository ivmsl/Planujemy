//
//  SharedTasks.swift
//  Planujemy
//
//  Created by Ivan Maslov on 02/06/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Shared Task Manager
@MainActor
class SharedTaskManager: ObservableObject {
    private let db = Firestore.firestore()
    private let modelContext: ModelContext
    
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var incomingTasks: [PTask] = []
    @Published var outgoingTasks: [PTask] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Main Operations
    
    /// Send a task to a friend
    func sendTaskToFriend(taskTitle: String, taskDesc: String?, taskDate: Date, friendUID: String, friendName: String, taskOptions: [TaskOptions] = [.Usual]) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        await updateLoadingState(true)
        defer { Task { await updateLoadingState(false) } }
        
        // Create the task locally first (as outgoing)
        let newTask = PTask(title: taskTitle, date: taskDate, desc: taskDesc, tag: nil, opt: taskOptions)
        newTask.IsShared = true
        newTask.from_user_fID = currentUser.uid
        newTask.to_user_fID = friendUID
        newTask.FromUserName = currentUser.displayName ?? currentUser.email ?? "Unknown"
        newTask.ToUserName = friendName
        newTask.ReceivedDate = Date()
        newTask.IsSynced = false
        
        // Insert locally
        modelContext.insert(newTask)
        
        do {
            try modelContext.save()
            
            // Send to Firebase - both outgoing and incoming collections
            try await uploadTaskToFirebase(newTask, as: .outgoing)
            try await uploadTaskToFirebase(newTask, as: .incoming, targetUID: friendUID)
            
            newTask.IsSynced = true
            try modelContext.save()
            
            print("✅ Task sent to \(friendName): \(taskTitle)")
            
        } catch {
            // If Firebase fails, remove from local storage
            modelContext.delete(newTask)
            try? modelContext.save()
            throw SharedTaskError.sendFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all shared tasks (incoming and outgoing)
    func syncSharedTasks() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        await updateLoadingState(true)
        
        do {
            // Sync incoming tasks (tasks sent to me)
            try await syncIncomingTasks()
            
            // Sync outgoing tasks (tasks I sent to others)
            try await syncOutgoingTasks()
            
            await updateSyncSuccess()
            print("✅ Shared tasks sync completed")
            
        } catch {
            await updateError("Sync failed: \(error.localizedDescription)")
            throw error
        }
        
        await updateLoadingState(false)
    }
    
    /// Update task status (for receivers) or content (for senders)
    func updateSharedTask(_ task: PTask, newStatus: TaskStatus? = nil, newTitle: String? = nil, newDesc: String? = nil, newDate: Date? = nil) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        guard task.IsShared else {
            throw SharedTaskError.invalidTask("Task is not shared")
        }
        
        let isReceiver = task.to_user_fID == currentUser.uid
        let isSender = task.from_user_fID == currentUser.uid
        
        guard isReceiver || isSender else {
            throw SharedTaskError.invalidTask("User not authorized to modify this task")
        }
        
        // Receivers can only update status
        if isReceiver && newStatus != nil {
            try await updateTaskStatus(task, status: newStatus!)
        }
        
        // Senders can update content but not status
        if isSender && (newTitle != nil || newDesc != nil || newDate != nil) {
            try await updateTaskContent(task, title: newTitle, desc: newDesc, date: newDate)
        }
    }
    
    /// Complete a task (receiver only)
    func completeSharedTask(_ task: PTask) async throws {
        try await updateSharedTask(task, newStatus: .completed)
    }
    
    /// Fail a task (receiver only)
    func failSharedTask(_ task: PTask) async throws {
        try await updateSharedTask(task, newStatus: .failed)
    }
    
    /// Delete a shared task (sender only)
    func deleteSharedTask(_ task: PTask) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        guard task.IsShared && task.from_user_fID == currentUser.uid else {
            throw SharedTaskError.invalidTask("Only sender can delete shared tasks")
        }
        
        guard let taskFID = task.fID else {
            throw SharedTaskError.invalidTask("Task has no Firebase ID")
        }
        
        do {
            // Delete from both collections
            if let toUID = task.to_user_fID {
                try await deleteTaskFromFirebase(taskFID, collection: .incoming, userUID: toUID)
            }
            try await deleteTaskFromFirebase(taskFID, collection: .outgoing, userUID: currentUser.uid)
            
            // Delete locally
            modelContext.delete(task)
            try modelContext.save()
            
            print("✅ Shared task deleted: \(task.title)")
            
        } catch {
            throw SharedTaskError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Sync Methods
    
    /// Sync incoming tasks from Firebase
    private func syncIncomingTasks() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        let snapshot = try await db.collection("users")
            .document(currentUser.uid)
            .collection("incoming_tasks")
            .getDocuments()
        
        for document in snapshot.documents {
            if let firebaseTask = PTask.fromFirebaseDataShared(document.data(), fID: document.documentID) {
                await handleIncomingSharedTask(firebaseTask)
            }
        }
        
        // Update local incoming tasks array
        let userUID = currentUser.uid
        let incomingDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate {
                $0.IsShared == true && $0.to_user_fID == userUID
            }
        )
        
        do {
            let localIncoming = try modelContext.fetch(incomingDescriptor)
            await MainActor.run {
                self.incomingTasks = localIncoming
            }
        } catch {
            print("❌ Error fetching local incoming tasks: \(error)")
        }
    }
    
    /// Sync outgoing tasks from Firebase
    private func syncOutgoingTasks() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        let snapshot = try await db.collection("users")
            .document(currentUser.uid)
            .collection("outgoing_tasks")
            .getDocuments()
        
        for document in snapshot.documents {
            if let firebaseTask = PTask.fromFirebaseDataShared(document.data(), fID: document.documentID) {
                await handleOutgoingSharedTask(firebaseTask)
            }
        }
        
        // Update local outgoing tasks array
        let userUID = currentUser.uid
        let outgoingDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate {
                $0.IsShared == true && $0.from_user_fID == userUID
            }
        )
        
        do {
            let localOutgoing = try modelContext.fetch(outgoingDescriptor)
            await MainActor.run {
                self.outgoingTasks = localOutgoing
            }
        } catch {
            print("❌ Error fetching local outgoing tasks: \(error)")
        }
    }
    
    /// Handle incoming shared task from Firebase
    private func handleIncomingSharedTask(_ firebaseTask: PTask) async {
        let firebaseFID = firebaseTask.fID
        let fetchDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate<PTask> { task in
                task.fID == firebaseFID && task.IsShared == true
            }
        )
        
        do {
            let existingTasks = try modelContext.fetch(fetchDescriptor)
            
            if let localTask = existingTasks.first {
                // Update existing task
                updateLocalSharedTask(localTask, with: firebaseTask)
                print("📥 Updated incoming task: \(localTask.title)")
            } else {
                // New incoming task
                modelContext.insert(firebaseTask)
                print("📥 New incoming task: \(firebaseTask.title)")
            }
            
            try modelContext.save()
        } catch {
            print("❌ Error handling incoming shared task: \(error)")
        }
    }
    
    /// Handle outgoing shared task from Firebase
    private func handleOutgoingSharedTask(_ firebaseTask: PTask) async {
        let firebaseFID = firebaseTask.fID
        let fetchDescriptor = FetchDescriptor<PTask>(
            predicate: #Predicate<PTask> { task in
                task.fID == firebaseFID && task.IsShared == true
            }
        )
        
        do {
            let existingTasks = try modelContext.fetch(fetchDescriptor)
            
            if let localTask = existingTasks.first {
                // Update existing task
                updateLocalSharedTask(localTask, with: firebaseTask)
                print("📥 Updated outgoing task: \(localTask.title)")
            } else {
                // New outgoing task (shouldn't happen often)
                modelContext.insert(firebaseTask)
                print("📥 New outgoing task: \(firebaseTask.title)")
            }
            
            try modelContext.save()
        } catch {
            print("❌ Error handling outgoing shared task: \(error)")
        }
    }
    
    /// Update local shared task with Firebase data
    private func updateLocalSharedTask(_ local: PTask, with remote: PTask) {
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
        local.from_user_fID = remote.from_user_fID
        local.to_user_fID = remote.to_user_fID
        local.FromUserName = remote.FromUserName
        local.ToUserName = remote.ToUserName
        local.ReceivedDate = remote.ReceivedDate
        local.IsSynced = true
    }
    
    // MARK: - Task Update Methods
    
    /// Update task status (completion/failure)
    private func updateTaskStatus(_ task: PTask, status: TaskStatus) async throws {
        guard let currentUser = Auth.auth().currentUser,
              let taskFID = task.fID,
              let senderUID = task.from_user_fID else {
            throw SharedTaskError.invalidTask("Missing required task data")
        }
        
        // Update local task
        switch status {
        case .completed:
            task.IsDone = true
            task.DateOfCompletion = Date()
        case .failed:
            task.IsDone = false
            task.DateOfCompletion = Date()
            // You might want to add a separate "failed" flag to your model
        }
        
        task.IsSynced = false
        
        do {
            try modelContext.save()
            
            // Update both Firebase collections
            let updateData: [String: Any] = [
                "IsDone": task.IsDone,
                "DateOfCompletion": task.DateOfCompletion != nil ? Timestamp(date: task.DateOfCompletion!) : NSNull(),
                "lastModified": Timestamp(date: Date())
            ]
            
            // Update in receiver's incoming_tasks
            try await db.collection("users")
                .document(currentUser.uid)
                .collection("incoming_tasks")
                .document(taskFID)
                .updateData(updateData)
            
            // Update in sender's outgoing_tasks
            try await db.collection("users")
                .document(senderUID)
                .collection("outgoing_tasks")
                .document(taskFID)
                .updateData(updateData)
            
            task.IsSynced = true
            try modelContext.save()
            
            print("✅ Task status updated: \(task.title)")
            
        } catch {
            throw SharedTaskError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Update task content (title, description, date)
    private func updateTaskContent(_ task: PTask, title: String?, desc: String?, date: Date?) async throws {
        guard let currentUser = Auth.auth().currentUser,
              let taskFID = task.fID,
              let receiverUID = task.to_user_fID else {
            throw SharedTaskError.invalidTask("Missing required task data")
        }
        
        // Update local task
        if let newTitle = title { task.title = newTitle }
        if let newDesc = desc { task.desc = newDesc }
        if let newDate = date { task.date = newDate }
        
        task.IsSynced = false
        
        do {
            try modelContext.save()
            
            // Prepare update data
            var updateData: [String: Any] = [
                "lastModified": Timestamp(date: Date())
            ]
            
            if let newTitle = title { updateData["title"] = newTitle }
            if let newDesc = desc { updateData["desc"] = newDesc }
            if let newDate = date { updateData["date"] = Timestamp(date: newDate) }
            
            // Update in sender's outgoing_tasks
            try await db.collection("users")
                .document(currentUser.uid)
                .collection("outgoing_tasks")
                .document(taskFID)
                .updateData(updateData)
            
            // Update in receiver's incoming_tasks
            try await db.collection("users")
                .document(receiverUID)
                .collection("incoming_tasks")
                .document(taskFID)
                .updateData(updateData)
            
            task.IsSynced = true
            try modelContext.save()
            
            print("✅ Task content updated: \(task.title)")
            
        } catch {
            throw SharedTaskError.updateFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Firebase Operations
    
    /// Upload task to Firebase collections
    private func uploadTaskToFirebase(_ task: PTask, as type: TaskDirection, targetUID: String? = nil) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SharedTaskError.notAuthenticated
        }
        
        let userUID = targetUID ?? currentUser.uid
        let collectionName = type == .incoming ? "incoming_tasks" : "outgoing_tasks"
        
        let taskRef: DocumentReference
        
        if let existingFID = task.fID {
            taskRef = db.collection("users")
                .document(userUID)
                .collection(collectionName)
                .document(existingFID)
        } else {
            taskRef = db.collection("users")
                .document(userUID)
                .collection(collectionName)
                .document()
            
            if type == .outgoing {
                task.fID = taskRef.documentID
            }
        }
        
        try await taskRef.setData(task.toFirebaseDataShared())
        print("📤 Uploaded \(type.rawValue) task: \(task.title)")
    }
    
    /// Delete task from Firebase collection
    private func deleteTaskFromFirebase(_ taskFID: String, collection: TaskDirection, userUID: String) async throws {
        let collectionName = collection == .incoming ? "incoming_tasks" : "outgoing_tasks"
        
        try await db.collection("users")
            .document(userUID)
            .collection(collectionName)
            .document(taskFID)
            .delete()
        
        print("🗑️ Deleted \(collection.rawValue) task from Firebase")
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

// MARK: - Supporting Types

enum TaskDirection: String {
    case incoming = "incoming"
    case outgoing = "outgoing"
}

enum TaskStatus {
    case completed
    case failed
}

enum SharedTaskError: Error, LocalizedError {
    case notAuthenticated
    case invalidTask(String)
    case sendFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidTask(let message):
            return "Invalid task: \(message)"
        case .sendFailed(let message):
            return "Failed to send task: \(message)"
        case .updateFailed(let message):
            return "Failed to update task: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete task: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - PTask Extensions for Shared Tasks

extension PTask {
    /// Convert shared task to Firebase format
    func toFirebaseDataShared() -> [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "date": Timestamp(date: date),
            "AutoReminder": AutoReminder,
            "IsUrgent": IsUrgent,
            "IsImportant": IsImportant,
            "IsAutoComplete": IsAutoComplete,
            "IsAutoFail": IsAutoFail,
            "IsDone": IsDone,
            "IsShared": true,
            "lastModified": Timestamp(date: Date())
        ]
        
        if let desc = desc { data["desc"] = desc }
        if let fromUserFID = from_user_fID { data["from_user_fID"] = fromUserFID }
        if let toUserFID = to_user_fID { data["to_user_fID"] = toUserFID }
        if let fromUserName = FromUserName { data["FromUserName"] = fromUserName }
        if let toUserName = ToUserName { data["ToUserName"] = toUserName }
        if let receivedDate = ReceivedDate {
            data["ReceivedDate"] = Timestamp(date: receivedDate)
        }
        if let completionDate = DateOfCompletion {
            data["DateOfCompletion"] = Timestamp(date: completionDate)
        }
        if let reminderDate = DateOfLastReminder {
            data["DateOfLastReminder"] = Timestamp(date: reminderDate)
        }
        
        return data
    }
    
    /// Create shared task from Firebase data
    static func fromFirebaseDataShared(_ data: [String: Any], fID: String) -> PTask? {
        guard let title = data["title"] as? String,
              let timestamp = data["date"] as? Timestamp else {
            return nil
        }
        
        let task = PTask(title: title, date: timestamp.dateValue())
        task.fID = fID
        task.IsShared = true
        task.desc = data["desc"] as? String
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
        
        task.IsSynced = true
        return task
    }
}
