//
//  CreateTask.swift
//  Planujemy
//
//  Created by Ivan Maslov on 26/04/2025.
//

import SwiftUI
import Foundation
import SwiftData

struct CreateTaskView: View {
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
//    @State var taskOptions: [TaskOptions]
    
    @Binding var shouldClose: Bool
    @State private var taskManager: PrivateTaskManager?
     
    
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
            
//            print(c_isImportant, c_isAutoFail, c_isAutoComplete)
            
        } else {
            self.title = ""
            self.date = Date()
            self.desc = ""
            
            self.c_isImportant = false
            self.c_isAutoComplete = true
            self.c_isAutoFail = false
//            self.taskOptions = []
}
        
        
    }
    
    
    
    private func SaveTask() -> Void {
        if let task = self.taskData {
            task.title = self.title
            task.desc = self.desc
            task.date = self.date
            task.IsAutoComplete = self.c_isAutoComplete
            task.IsAutoFail = self.c_isAutoFail
            task.IsImportant = self.c_isImportant
            
            if let ttgs = taskTags {
                task.tag = ttgs
            }
            task.tagID = taskTags?.fID
            taskManager?.markTaskForSync(task)
            
            Task {
                        await taskManager?.quickSync()
            }

        } else {
            
            
            let taskOptions = buildTaskOptions()

            Task {
                await taskManager?.createPrivateTask(
                    title: title,
                    date: date,
                    desc: desc.isEmpty ? nil : desc,
                    tag: taskTags,
                    opt: taskOptions
                )
            }
            
            //            let task = PTask(title: title,
            //                            date: date,
            //                            desc: desc)
            //            task.IsAutoComplete = self.c_isAutoComplete
            //            task.IsAutoFail = self.c_isAutoFail
            //            task.IsImportant = self.c_isImportant
            //            if let ttgs = taskTags {
            //                task.tag = ttgs
            //            }
            //
            //            context.insert(task)
            //        }
            //        try! context.save()
        }
        shouldClose = !true
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

    var body: some View {

            VStack(spacing: 10) {
                
                HStack {
                    Text(taskData != nil ? "Edit task" : "Create new task")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .padding(.horizontal, 10)
                    Spacer()
                }
                    .background(Color("LightCol"))
                
                Divider()
                    .foregroundStyle(Color("BorderGray"))
                
                HStack {
                    VStack {
                        TextField(
                            "Title",
                            text: $title
                        )
                        .font(.title)
                        .padding(.horizontal, 10)
                        
                        
                    }
                    .padding(.leading,2)
                    Spacer()
                    VStack {
                        CustomCheckboxBorderless(
                            isChecked: $c_isImportant,
                            color: Color(.yellow),
                            size: 30
                        )
                        
                    }
                    .padding(.trailing, 10)
                }
                
                
                HStack {
                    
                   
                    
                    DatePicker(selection: $date,
//                               in: ...Date.now,
                               displayedComponents: [.date, .hourAndMinute])
                    {
                        Text("")
                    }
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
                    .labelsHidden()
                    
                    Spacer()
                    
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
                    
                }
                .frame(alignment: .leading)
                .padding(.leading, 10)
                .padding(.trailing, 10)
                
                
                
                Divider()
                
                
                TextField(
                    "Nowe opisanie",
                    text: $desc,
                    axis: .vertical
                )
                .multilineTextAlignment(.leading)
                .lineLimit(10...10)
                .padding(.horizontal)
                .padding(.top, 10)
                .background(Color.gray.opacity(0.2))
                
                Divider()
                
                HStack {
                    Menu {
                        ForEach(tagList) {taskEl in
                            Button(action: {
                                taskTags = taskEl
                            })
                            {
                                Text(taskEl.name)
                            }
                            
                        }
                    } label: {
                        Label(taskTags?.name ?? "Select tag", systemImage: "tag")
                            .font(.title3)
                            .foregroundStyle(.black)
                    }
                    Spacer()
                }
                
                
                
                
                Spacer()
                
                
                if !self.c_isCompleted {
                    HStack(spacing: 20) {
                        
                        MediumButton(closure: {
                            SaveTask()
                        }, text: "Save", col: .black)
                        
                        if let _ = self.taskData {
                            MediumButton(closure: {
                                if let task = self.taskData {
                                    task.IsDone = true
                                    task.DateOfCompletion = Date.now
                                    try! context.save()
                                    
                                }
                                shouldClose = !true
                            },
                                         text: "Complete",
                                         col: .green)
                        }
                        
                        MediumButton(closure: {
                            if let task = self.taskData {
                                context.delete(task)
                                try! context.save()
                            }
                            shouldClose = !true
                        }, text: "",  imagename: "trash.fill", col: .red)
            
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
                            MediumButton(closure: {
                                shouldClose = !true
                            }, text: "OK", col: .green)
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
            
            
            
            }
    }
}

#Preview {
    @Previewable @State var toggle = false
    CreateTaskView(shouldClose: $toggle)
}
