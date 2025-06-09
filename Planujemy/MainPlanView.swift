//
//  MainPlanView.swift
//  Planujemy
//
//  Created by Ivan Maslov on 26/04/2025.
//

import SwiftUI
import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore




extension View {
    func Print(_ items: Any...) -> some View {
        for item in items {print(item)}
        
        return self
    }
    
    
}


struct MainPlanView: View {
    private let SyncTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var updatedAt: Date? = nil
    
    @Environment(\.modelContext) var context
    
    @State var IsNewTaskWindowVisible: Bool = false
    @State var IsTaskListVisible: Bool = false
    @State var IsAddingNewTag: Bool = false
    @State private var showingSignOutAlert = false
    
    @State private var showingFriendsList = false
    
    
    @State private var dzien: Date = Date.now
    @Query(sort: \PTask.date) var allTasks: [PTask]
//    @Query var tasks: [Task]
//    @Query var errtasks: [Task]
    
    @Query(sort: \TaskTag.name) var taskTagList: [TaskTag]
    @State private var selectedTask: PTask?
    @State private var selectedTag: TaskTag?
    @State private var selectedPredicate: Predicate<PTask>? = nil
    
    
    @State private var taskManager: PrivateTaskManager?
    @State private var friendManager: FriendManager?
    @State private var sharedTaskManager: SharedTaskManager?
    
    var tasks: [PTask] {
            guard let currentUser = Auth.auth().currentUser else { return [] }
        
            let startDate = Date.now
            let endDate = Date.now.addingTimeInterval(2.99 * 86400)
            
            return allTasks.filter { task in
                (task.owner_fID == currentUser.uid || task.to_user_fID == currentUser.uid) &&
                task.date >= startDate &&
                task.date <= endDate &&
                !task.IsDone
            }
        }
    
    private func performBackgroundSync() async {
            do {
                // Quick sync - only uploads changes, doesn't show loading
                await taskManager?.quickSync()
                try await sharedTaskManager?.syncSharedTasks()
                print("🔄 Background sync completed")
            } catch {
                print("❌ Background sync failed: \(error)")
                // Silent failure - don't show errors to user for background sync
            }
        }
        
    var errtasks: [PTask] {
        
            guard let currentUser = Auth.auth().currentUser else { return [] }
        
            let startDate = Date.now
            return allTasks.filter { task in
                task.owner_fID == currentUser.uid &&
                task.date < startDate &&
                task.IsAutoFail == true &&
                task.IsDone == false
            }
        }
//    init() {
//        print("MainPlanView initialized - this should happen less frequently now")
//    }
    
//    func asinit() {
//        IsNewTaskWindowVisible = false
//        IsTaskListVisible = false
//        IsAddingNewTag = false
//        dzien = Date.now
//        
//        let startDate = Date.now
//        let endDate = Date.now.addingTimeInterval(2.99 * 86400)
//        
//        let pred = #Predicate<Task>{
//                $0.date >= startDate && $0.date <= endDate && !$0.IsDone
//            }
//        let err_pred = #Predicate<Task>{
//            $0.date < startDate && $0.IsAutoFail == true && $0.IsDone == false
//        }
//        
//        _tasks = Query(filter: pred, sort: \Task.date)
//        _errtasks = Query(filter:err_pred, sort: \Task.date)
//        
//        print("Current user: ", Auth.auth().currentUser?.uid ?? "brak uzytkownika", "Username: ", Auth.auth().currentUser?.displayName ?? "User")
//        
//        }

    
    private func updateTasks() {
        let isnotDone = #Predicate<PTask>{!$0.IsDone && $0.IsAutoComplete}
        let startDate = Date.now
        
        let fetchDesc = FetchDescriptor<PTask>(
            predicate: isnotDone
        )
        let isnotDoneTasks = try! context.fetch(fetchDesc)
        
        for tsk in isnotDoneTasks {
            if tsk.date < startDate {
                tsk.IsDone = true
                tsk.DateOfCompletion = startDate
                
                if tsk.IsShared {
                    Task {
                        try? await sharedTaskManager?.updateSharedTask(tsk, newStatus: .completed)
                        }
                } else {
                        taskManager?.markTaskForSync(tsk)
                }
            }
        }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            // State listener will automatically navigate to LoginView
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    

    
    var body: some View {
            ZStack {
                VStack {}
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                    .background(
                        Color("LightCol")
                    )
                // MARK: - MAIN SCROLL VIEW
                
                ScrollView(.vertical) {
                        VStack(spacing: 15) {
                            
                            Spacer().frame(height:20)
                            ///Date Headline
                            HStack {
                                Text(dzien, format: .dateTime.day().month(.wide))
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.black)
                                    .shadow(radius: 30)
                                Spacer()
                                Text(dzien, format: .dateTime.year())
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.black)
                                    .opacity(0.4)
                                    .shadow(radius: 30)
                            }
                            .padding()
                        
                            if !IsTaskListVisible {
                                //MARK: - Most important Tasks — SCROLL VIEW
                                ScrollView (.vertical) {
                                    VStack(spacing: 5) {
                                        
                                        ForEach(errtasks) { errtsk in
                                            SmallTaskCard(tData: errtsk, col: Color.red)
                                            .onTapGesture {
                                                    self.selectedTask = errtsk
                                                    self.IsNewTaskWindowVisible = true
                                                print("Tapped on task...")
                                            }
                                            
                                        }
                                        
                                        ForEach(tasks) { task in
                                            SmallTaskCard(
                                                tData: task
                                            )
                                            .onTapGesture {
                                                self.selectedTask = task
                                                self.IsNewTaskWindowVisible = true
                                            }
                                        }

                                    }
                                    .padding()
                                    
                                }
                                .frame(maxHeight: 300)
                                
                                Divider()
                                
                                
                                BigButton(closure: {
                                    IsNewTaskWindowVisible.toggle()
                                    self.selectedTask = nil
                                }, text: "Add new task")
                                .sheet(isPresented: $IsNewTaskWindowVisible) {
                                    NewCreateTaskView(shouldClose: $IsNewTaskWindowVisible, taskData: selectedTask)
                                }
                                
                                
                                
                                Spacer().frame(height: 20)
                                
                                Divider()
                                
                                
                                ForEach(taskTagList) { tTag in
//                                    Print(tTag.name)
                                    HStack {
                                        Circle()
                                            .fill(tTag.col.color)
                                            .frame(width: 15, height: 15)
                                        Button(action: {
                                            selectedTag = tTag
                                            IsTaskListVisible.toggle()
                                        }) {
                                            Text(tTag.name)
                                                .foregroundStyle(.black)
                                        }
                                        Spacer()
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width - 50, height: 50)
                                .font(.title2)
                                
                                
                                HStack {
                                    Image(systemName: "star.fill")
                                        .frame(width: 15, height: 15)

                                    Button(action: {
                                        IsTaskListVisible.toggle()
                                        selectedTag = nil
                                        selectedPredicate = #Predicate<PTask> {
                                            $0.IsImportant == true
                                        }
                                        
                                    }) {
                                        Text("Important")
                                            .foregroundStyle(.black)
                                    }
                                    
                                    Spacer()
                                    
                                    
                                }
                                .frame(width: UIScreen.main.bounds.width - 50, height: 50)
                                .font(.title2)
                                
                                
                                
                                HStack {
                                    Image(systemName: "wallet.pass")
                                        .frame(width: 15, height: 15)

                                    Button(action: {
                                        IsTaskListVisible.toggle()
                                        selectedTag = nil
                                        selectedPredicate = nil
                                    }) {
                                        Text("All")
                                            .foregroundStyle(.black)
                                    }
                                    
                                    Spacer()
                                    
                                    
                                }
                                .frame(width: UIScreen.main.bounds.width - 50, height: 50)
                                .font(.title2)
                                
                                if IsAddingNewTag {
                                    NewTagInput(isPresented: $IsAddingNewTag, taskManager: taskManager)
                                }
                                
                                
                                Button(action: {
                                    IsAddingNewTag = true
                                }) {
                                    Text("Add new tag")
                                        .font(.subheadline)
                                }
                                
                                Divider()
                                VStack(spacing:20){
//                                    HStack{
//                                        Text("Friends")
//                                            .font(.title)
//                                            .bold()
//                                        Spacer()
//                                    }
//                                    .padding(.leading, 20)
                                    
                                    Button("Friends") {
                                                showingFriendsList = true
                                            }
                                            .sheet(isPresented: $showingFriendsList) {
                                                FriendListView(modelContext: context)
                                            }
                                }
                                
                                
                                
                                Divider()
                                DropTasksButton()
                                if updatedAt != nil {
                                    Text("Updated at \(updatedAt!.description)")
                                        .font(.footnote)
                                        .padding(.bottom)
                                }
                                
                                Button("Sign Out") {
                                    showingSignOutAlert = true
                                }
                                .alert("Sign Out", isPresented: $showingSignOutAlert) {
                                    Button("Cancel", role: .cancel) { }
                                    Button("Sign Out", role: .destructive) {
                                        signOut()
                                    }
                                } message: {
                                    Text("Are you sure you want to sign out?")
                                }

                                
                            }
                            
                            
                        
                        Spacer()
                        
                    }
                }
                
                if IsTaskListVisible {
                    ShowTaskList(tagInfo: selectedTag, predicate: selectedPredicate, isVisible: $IsTaskListVisible)
                    
                }
                
                
                
                
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(SyncTimer) { tm in
                updateTasks()
                updatedAt = Date()
            Task {
                await performBackgroundSync()
            }
        }
        .onAppear {
            Print(taskTagList)
            if taskManager == nil {
                taskManager = PrivateTaskManager(modelContext: context)
            }
            
            if friendManager == nil {
                        friendManager = FriendManager(modelContext: context)
                    }
                    
                    
            if sharedTaskManager == nil {
                        sharedTaskManager = SharedTaskManager(modelContext: context)
                    }
            
            Task {
                                await taskManager?.syncAllPrivateData()
                    try await friendManager?.fetchPendingFriendRequests()
                    try await sharedTaskManager?.syncSharedTasks()
            }
        
        
        }
    }
        
}

#Preview {
    MainPlanView()
}
