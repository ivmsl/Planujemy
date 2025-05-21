//
//  MainPlanView.swift
//  Planujemy
//
//  Created by Ivan Maslov on 26/04/2025.
//

import SwiftUI
import Foundation
import SwiftData




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
    
    @State var IsNewTaskWindowVisible: Bool
    @State var IsTaskListVisible: Bool
    @State var IsAddingNewTag: Bool
    
    
    @State private var dzien: Date
    @Query var tasks: [Task]
    @Query var errtasks: [Task]
    
    @Query(sort: \TaskTag.name) var taskTagList: [TaskTag]
    @State private var selectedTask: Task?
    @State private var selectedTag: TaskTag?
    @State private var selectedPredicate: Predicate<Task>? = nil
    
    init() {
        IsNewTaskWindowVisible = false
        IsTaskListVisible = false
        IsAddingNewTag = false
        dzien = Date.now
        
        let startDate = Date.now
        let endDate = Date.now.addingTimeInterval(2.99 * 86400)
        
        let pred = #Predicate<Task>{
                $0.date >= startDate && $0.date <= endDate && !$0.IsDone
            }
        let err_pred = #Predicate<Task>{
            $0.date < startDate && $0.IsAutoFail == true && $0.IsDone == false
        }
        
        _tasks = Query(filter: pred, sort: \Task.date)
        _errtasks = Query(filter:err_pred, sort: \Task.date)
        
        }

    
    private func updateTasks() {
        let isnotDone = #Predicate<Task>{!$0.IsDone && $0.IsAutoComplete}
        let startDate = Date.now
        
        let fetchDesc = FetchDescriptor<Task>(
            predicate: isnotDone
        )
        let isnotDoneTasks = try! context.fetch(fetchDesc)
        
        for tsk in isnotDoneTasks {
            if tsk.date < startDate {
                tsk.IsDone = true
                tsk.DateOfCompletion = startDate
            }
        }
    }

    
    var body: some View {
            ZStack {
                VStack {}
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                    .background(
                        Color("ApplColor")
                    )
                
                ScrollView(.vertical) {
                        VStack(spacing: 15) {
                            
                            Spacer().frame(height:20)
                            //Date Headline
                            HStack {
                                Text(dzien, format: .dateTime.day().month(.wide))
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                    .shadow(radius: 30)
                                //                        .frame(
                                //                            width: UIScreen.main.bounds.width - 20,
                                //                            alignment: .leading
                                //                        )
                                Spacer()
                                Text(dzien, format: .dateTime.year())
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                    .opacity(0.4)
                                    .shadow(radius: 30)
                            }
                            .padding()
                        
                            if !self.IsNewTaskWindowVisible && !IsTaskListVisible {
                                //Most important Tasks
                                ScrollView (.vertical) {
                                    VStack(spacing: 5) {
                                        
                                        ForEach(errtasks) { errtsk in
                                            SmallTaskCard(tData: errtsk, col: Color.red)
                                            .onTapGesture {
                                                    self.selectedTask = errtsk
                                                    self.IsNewTaskWindowVisible = true
                                            }
                                            
                                        }
                                        
                                        ForEach(tasks) { task in
                                            SmallTaskCard(
                                                tData: task
                                            )
                                            .onTapGesture {
                                                self.selectedTask = task
                                                //                                            print(task.title)
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
                                
                                
                                Spacer().frame(height: 20)
                                
                                Divider()
                                
                                
                                ForEach(taskTagList) { tTag in
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
                                        selectedPredicate = #Predicate<Task> {
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
                                    NewTagInput(isPresented: $IsAddingNewTag)
                                }
                                
                                
                                Button(action: {
                                    IsAddingNewTag = true
                                }) {
                                    Text("Add new tag")
                                        .font(.subheadline)
                                }
                                
                                Divider()
                                DropTasksButton()
                                if updatedAt != nil {
                                    Text("Updated at \(updatedAt!.description)")
                                        .font(.footnote)
                                        .padding(.bottom)
                                }
                                
                            }
                            
                            
                        
                        Spacer()
                        
                    }
                }
                
                if IsNewTaskWindowVisible
                {
                    CreateTaskView(shouldClose: $IsNewTaskWindowVisible, taskData: selectedTask)
                    

                }
                if IsTaskListVisible {
                    ShowTaskList(tagInfo: selectedTag, predicate: selectedPredicate, isVisible: $IsTaskListVisible)
                    
                }
                
                
                
                
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(SyncTimer) { tm in
                updateTasks()
                updatedAt = Date()
            }
    }
        
}

#Preview {
    MainPlanView()
}
