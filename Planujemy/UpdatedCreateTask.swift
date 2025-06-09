//
//  CreateTask.swift
//  Planujemy
//
//  Created by Ivan Maslov on 26/04/2025.
//

import SwiftUI
import Foundation
import SwiftData
import FirebaseAuth

struct NewCreateTaskView: View {
    @Environment(\.modelContext) var context
    @Query var tagList: [TaskTag]
    
    @State var title: String = ""
    @State var desc: String = ""
    @State var date: Date = Date()
    
    @State var c_isImportant: Bool
    @State var c_isAutoComplete: Bool
    @State var c_isAutoFail: Bool
    private var c_isCompleted: Bool = false
    
    @State var taskData: PTask?
    @State var taskTags: TaskTag?
    @State var selectedFriend: Friends?
    @State var selectedFriendUID: String?
    
    @Binding var shouldClose: Bool
    @State private var taskManager: PrivateTaskManager?
    @State private var sharedTaskManager: SharedTaskManager?
    @State private var friendManager: FriendManager?
    
    // State for managing friend selection
    @State private var showingFriendSelection = false
    @State private var isSharedTask = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // ✅ New computed properties for incoming task handling
    private var isIncomingTask: Bool {
        guard let task = taskData,
              let currentUser = Auth.auth().currentUser else { return false }
        
        return task.IsShared && task.to_user_fID == currentUser.uid
    }
    
    private var isOutgoingTask: Bool {
        guard let task = taskData,
              let currentUser = Auth.auth().currentUser else { return false }
        
        return task.IsShared && task.from_user_fID == currentUser.uid
    }
    
    private var canEditContent: Bool {
        // Can edit if it's a new task, private task, or outgoing shared task
        return taskData == nil || !taskData!.IsShared || isOutgoingTask
    }
    
    init(shouldClose: Binding<Bool>, taskData: PTask? = nil) {
        self._shouldClose = shouldClose
        
        if let task = taskData {
            self._title = State(initialValue: task.title)
            self._date = State(initialValue: task.date)
            self._desc = State(initialValue: task.desc ?? "")
            self._taskData = State(initialValue: task)
            self._taskTags = State(initialValue: task.tag)
            self._c_isImportant = State(initialValue: task.IsImportant)
            self._c_isAutoFail = State(initialValue: task.IsAutoFail)
            self._c_isAutoComplete = State(initialValue: task.IsAutoComplete)
            self.c_isCompleted = task.IsDone
            
            // Check if this is a shared task
            self._isSharedTask = State(initialValue: task.IsShared)
            
        } else {
            self.title = ""
            self.date = Date()
            self.desc = ""
            
            self.c_isImportant = false
            self.c_isAutoComplete = true
            self.c_isAutoFail = false
            self._isSharedTask = State(initialValue: false)
        }
    }
    
    private func SaveTask() async -> Void {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let task = self.taskData {
                // Editing existing task
                await updateExistingTask(task)
            } else {
                // Creating new task
                await createNewTask()
            }
            
            await MainActor.run {
                shouldClose = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func updateExistingTask(_ task: PTask) async {
        // ✅ Only update content if user can edit it
        if canEditContent {
            task.title = self.title
            task.desc = self.desc
            task.date = self.date
            task.IsAutoComplete = self.c_isAutoComplete
            task.IsAutoFail = self.c_isAutoFail
            task.IsImportant = self.c_isImportant
        }
        
        // Update tag for private tasks only
        if !task.IsShared && canEditContent {
            if let ttgs = taskTags {
                task.tag = ttgs
            }
            task.tagID = taskTags?.fID
            taskManager?.markTaskForSync(task)
            
            await taskManager?.quickSync()
        } else if task.IsShared && canEditContent {
            // For outgoing shared tasks, use SharedTaskManager
            do {
                try await sharedTaskManager?.updateSharedTask(
                    task,
                    newTitle: title,
                    newDesc: desc.isEmpty ? nil : desc,
                    newDate: date
                )
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update shared task: \(error.localizedDescription)"
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func createNewTask() async {
        if isSharedTask && selectedFriend != nil {
            // Create shared task
            guard let friendUID = getFriendUID(for: selectedFriend!) else {
                await MainActor.run {
                    errorMessage = "Friend UID not available. Please refresh friends list."
                    isLoading = false
                }
                return
            }
            
            do {
                let taskOptions = buildTaskOptions()
                
                print("🔄 Creating shared task for friend: \(selectedFriend!.FriendName)")
                print("🔄 Friend UID: \(friendUID)")
                print("🔄 Task title: \(title)")
                
                try await sharedTaskManager?.sendTaskToFriend(
                    taskTitle: title,
                    taskDesc: desc.isEmpty ? nil : desc,
                    taskDate: date,
                    friendUID: friendUID,
                    friendName: selectedFriend!.FriendName,
                    taskOptions: taskOptions
                )
                
                print("✅ Shared task created successfully")
                
                await MainActor.run {
                    isLoading = false
                }
                
            } catch {
                print("❌ Failed to create shared task: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to send task to friend: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        } else {
            // Create private task
            print("🔄 Creating private task: \(title)")
            let taskOptions = buildTaskOptions()
            
            await taskManager?.createPrivateTask(
                title: title,
                date: date,
                desc: desc.isEmpty ? nil : desc,
                tag: taskTags,
                opt: taskOptions
            )
            
            print("✅ Private task created successfully")
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func buildTaskOptions() -> [TaskOptions] {
        var options: [TaskOptions] = [.Usual]
        
        if c_isImportant {
            options.append(.IsImportant)
        }
        
        if c_isAutoFail {
            options.append(.IsAutoFail)
        }
        
        return options
    }
    
    private func completeTask() async {
        guard let task = taskData else { return }
        
        isLoading = true
        
        if task.IsShared {
            // Complete shared task
            do {
                try await sharedTaskManager?.completeSharedTask(task)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to complete shared task: \(error.localizedDescription)"
                }
            }
        } else {
            // Complete private task
            task.IsDone = true
            task.DateOfCompletion = Date.now
            try! context.save()
            taskManager?.markTaskForSync(task)
            await taskManager?.quickSync()
        }
        
        await MainActor.run {
            isLoading = false
            shouldClose = false
        }
    }
    
    private func deleteTask() async {
        guard let task = taskData else {
            shouldClose = false
            return
        }
        
        // ✅ Only allow deletion if user can edit (senders can delete, receivers cannot)
        guard canEditContent || isIncomingTask else {
            await MainActor.run {
                errorMessage = "You cannot delete this task"
                isLoading = false
            }
            return
        }
        
        isLoading = true
        
        if task.IsShared {
            // Delete shared task
            do {
                try await sharedTaskManager?.deleteSharedTask(task)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete shared task: \(error.localizedDescription)"
                }
                return
            }
        } else {
            // Delete private task
            await taskManager?.deletePrivateTask(task)
        }
        
        await MainActor.run {
            isLoading = false
            shouldClose = false
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            
            // ✅ Updated header to show task type
            HStack {
                VStack(alignment: .leading) {
                    Text(taskData != nil ? "Edit task" : "Create new task")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    
                    // ✅ Show task type indicator for existing tasks
                    if let task = taskData {
                        if isIncomingTask {
                            Text("📨 Received from \(task.FromUserName ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if isOutgoingTask {
                            Text("📤 Sent to \(task.ToUserName ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("🔒 Private task")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .background(Color("LightCol"))
            
            Divider()
                .foregroundStyle(Color("BorderGray"))
            
            // ✅ Title field - disabled for incoming tasks
            HStack {
                VStack {
                    if canEditContent {
                        TextField("Title", text: $title)
                            .font(.title)
                            .padding(.horizontal, 10)
                    } else {
                        Text(title)
                            .font(.title)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading,2)
                Spacer()
                VStack {
                    if canEditContent {
                        CustomCheckboxBorderless(
                            isChecked: $c_isImportant,
                            color: Color(.yellow),
                            size: 30
                        )
                    } else {
                        Image(systemName: c_isImportant ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundColor(c_isImportant ? .yellow : .gray)
                    }
                }
                .padding(.trailing, 10)
            }
            
            // ✅ Date picker - disabled for incoming tasks
            HStack {
                if canEditContent {
                    DatePicker(selection: $date,
                               displayedComponents: [.date, .hourAndMinute])
                    {
                        Text("")
                    }
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .labelsHidden()
                } else {
                    Text(date, format: .dateTime.day().month(.wide).year().hour().minute())
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // ✅ Auto-fail and auto-complete indicators (read-only for incoming)
                if canEditContent {
                    if (!c_isAutoComplete) {
                        CustomCheckboxBorderless(
                            isChecked: $c_isAutoFail,
                            color: .red,
                            bckColor: Color(hue: 1.0, saturation: 0.658, brightness: 0.47),
                            size: 30,
                            imgName: "calendar.badge.exclamationmark",
                            imgPressed: "calendar.badge.exclamationmark"
                        )
                    }
                    else {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 30))
                            .foregroundStyle(Color(.systemGray))
                    }
                    
                    if (!c_isAutoFail) {
                        CustomCheckboxBorderless(
                            isChecked: $c_isAutoComplete,
                            color: Color(.green),
                            bckColor: Color(#colorLiteral(red: 0.360394299, green: 0.5548041463, blue: 0.2798731923, alpha: 1)),
                            size: 30,
                            imgName: "calendar.badge.checkmark.rtl",
                            imgPressed: "calendar.badge.checkmark.rtl"
                        )
                    } else {
                        Image(systemName: "calendar.badge.checkmark.rtl")
                            .font(.system(size: 30))
                            .foregroundStyle(Color(.systemGray))
                    }
                } else {
                    // Read-only indicators for incoming tasks
                    HStack(spacing: 10) {
                        if c_isAutoFail {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 30))
                                .foregroundColor(.red)
                        }
                        
                        if c_isAutoComplete {
                            Image(systemName: "calendar.badge.checkmark.rtl")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                        }
                        
                        if !c_isAutoFail && !c_isAutoComplete {
                            Image(systemName: "calendar")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(alignment: .leading)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            
            Divider()
            
            // ✅ Description field - disabled for incoming tasks
            if canEditContent {
                TextField(
                    "Task description",
                    text: $desc,
                    axis: .vertical
                )
                .multilineTextAlignment(.leading)
                .lineLimit(10...10)
                .padding(.horizontal)
                .padding(.top, 10)
                .background(Color.gray.opacity(0.2))
            } else {
                ScrollView {
                    Text(desc.isEmpty ? "No description" : desc)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
                .frame(minHeight: 60, maxHeight: 120)
                .background(Color.gray.opacity(0.1))
            }
            
            Divider()
            
            // ✅ Tag and Friend Selection Section - conditional based on task type
            VStack(spacing: 10) {
                // Task Type Selection (only for new tasks)
                if taskData == nil {
                    HStack {
                        Button(action: {
                            isSharedTask = false
                            selectedFriend = nil
                            selectedFriendUID = nil
                        }) {
                            HStack {
                                Image(systemName: isSharedTask ? "circle" : "circle.fill")
                                Text("Private Task")
                            }
                            .foregroundStyle(isSharedTask ? .gray : .buttonBckg)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isSharedTask = true
                            taskTags = nil // Clear tag selection for shared tasks
                        }) {
                            HStack {
                                Image(systemName: isSharedTask ? "circle.fill" : "circle")
                                Text("Shared Task")
                            }
                            .foregroundStyle(isSharedTask ? .buttonBckg : .gray)
                        }
                        
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                HStack {
                    // ✅ Conditional display based on task type and edit permissions
                    if taskData == nil || (!taskData!.IsShared && canEditContent) {
                        // New task or editable private task - show tag selection
                        if !isSharedTask {
                            Menu {
                                Button("No Tag") {
                                    taskTags = nil
                                }
                                
                                ForEach(tagList) { taskEl in
                                    Button(action: {
                                        taskTags = taskEl
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill(Color(
                                                    red: taskEl.col.r,
                                                    green: taskEl.col.g,
                                                    blue: taskEl.col.b,
                                                    opacity: taskEl.col.a
                                                ))
                                                .frame(width: 12, height: 12)
                                            Text(taskEl.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "tag")
                                    Text(taskTags?.name ?? "Select tag")
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .font(.title3)
                                .foregroundStyle(.black)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            // Friend Selection for new shared tasks
                            Menu {
                                if friendManager?.friends.isEmpty != false {
                                    Button("No friends available") { }
                                        .disabled(true)
                                } else {
                                    ForEach(friendManager?.friends ?? []) { friend in
                                        Button(action: {
                                            selectedFriend = friend
                                            selectedFriendUID = getFriendUID(for: friend)
                                        }) {
                                            HStack {
                                                Image(systemName: "person.circle")
                                                Text(friend.FriendName)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.2")
                                    Text(selectedFriend?.FriendName ?? "Select friend")
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .font(.title3)
                                .foregroundStyle(.black)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    } else if let task = taskData, taskTags != nil {
                        // ✅ Private task with tag - show tag info (read-only)
                        HStack {
                            Image(systemName: "tag")
                            Text(taskTags?.name ?? "No tag")
                            Spacer()
                        }
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            if !self.c_isCompleted {
                HStack(spacing: 20) {
                    
                    // ✅ Save button - only show if content can be edited
                    if canEditContent {
                        Button(action: {
                            Task {
                                await SaveTask()
                            }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 20, height: 20)
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(isLoading || title.trimmingCharacters(in: .whitespaces).isEmpty || (isSharedTask && selectedFriend == nil))
                        .buttonStyle(MediumButtonStyle(color: .black))
                    } else {
                        Button(action: {
                            shouldClose = false
                        }) {
                            Text("Back")
                        }
                        .buttonStyle(MediumButtonStyle(color: .black))
                    }
                    
                    // ✅ Complete button - always available for incomplete tasks
                    if let _ = self.taskData {
                        Button(action: {
                            Task {
                                await completeTask()
                            }
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 20, height: 20)
                            } else {
                                Text("Complete")
                            }
                        }
                        .disabled(isLoading)
                        .buttonStyle(MediumButtonStyle(color: .green))
                    }
                    
                    // ✅ Delete button - conditional based on permissions
                    if canEditContent || isIncomingTask {
                        Button(action: {
                            Task {
                                await deleteTask()
                            }
                        }) {
                            Image(systemName: "trash.fill")
                        }
                        .disabled(isLoading)
                        .buttonStyle(MediumButtonStyle(color: .red))
                    }
//                    .padding(.bottom)
                }
                .padding()
            }
            else {
                if let task = self.taskData {
                    if let taskDateCmp = task.DateOfCompletion {
                        HStack {
                            Text("Date of completion: ")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(taskDateCmp, format: .dateTime.day().month(.wide).year().hour().minute())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Button(action: {
                            shouldClose = false
                        }) {
                            Text("OK")
                        }
                        .buttonStyle(MediumButtonStyle(color: .green))
                        .padding(.bottom)
                    }
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width - 20, height: 600)
        .background(.white)
        .padding(.horizontal, 10)
        .onAppear {
            if taskManager == nil {
                taskManager = PrivateTaskManager(modelContext: context)
            }
            if sharedTaskManager == nil {
                sharedTaskManager = SharedTaskManager(modelContext: context)
            }
            if friendManager == nil {
                friendManager = FriendManager(modelContext: context)
                Task {
                    try await friendManager?.fetchFriends()
                }
            }
        }
    }
    
    // Helper function to get friend UID
    private func getFriendUID(for friend: Friends) -> String? {
        return friend.friendFirebaseUID
    }
}

// Custom ButtonStyle to match your MediumButton
struct MediumButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    @Previewable @State var toggle = false
    NewCreateTaskView(shouldClose: $toggle)
}
