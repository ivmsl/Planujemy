//
//  TaskList.swift
//  Planujemy
//
//  Created by Ivan Maslov on 04/05/2025.
//

import SwiftUI
import Foundation
import SwiftData


struct ShowTaskList: View {
    @Environment(\.modelContext) var context
    @Query var taskList: [Task]
    @Binding var isVisible: Bool
    
    @State private var taskTagName: String = ""
    @State private var selectedTaskFromList: Task?
    @State private var editTaskListFromScreen: Bool = false
    
    init(tagInfo: TaskTag?, predicate: Predicate<Task>?, isVisible: Binding<Bool>, listName: String = "") {
        _isVisible = isVisible
        
        if let tmpTagInfo = tagInfo {
            self._taskTagName = State(initialValue: tmpTagInfo.name)
            let tagID = tmpTagInfo.id
            let predicate = #Predicate<Task> {
                $0.tag?.id == tagID
                    
            }
            _taskList = Query(filter: predicate, sort: \.date)
        }
        else if let pred = predicate {
            if listName != "" {self._taskTagName = State(initialValue: listName)}
            _taskList = Query(filter: pred, sort: \.date)
        }
        else {
            _taskList = Query(sort: \.date)
        }
        
    }
    
    
    
    var body: some View {
        
        ZStack {
            if !editTaskListFromScreen {
                VStack {
                    Text(self.taskTagName)
                        .font(.title)
                        .bold()
                    ScrollView {
                        ForEach(taskList) { task in
                            SmallTaskCard(
                                tData: task, col: (task.IsAutoFail && task.IsDone) ? Color.red :
                                    (task.IsDone) ? Color.green : Color.blue
                            )
                            .onTapGesture {
                                self.selectedTaskFromList = task
            //                                            print(task.title)
                                self.editTaskListFromScreen = true
                            }
                        }
                        
                    }
                    BigButton(closure: {
                        isVisible.toggle()
                    }, text: "Close")
                }
                
            }
            else {
                CreateTaskView(shouldClose: $editTaskListFromScreen, taskData: selectedTaskFromList)
            }
            
        }
        .frame(width: UIScreen.main.bounds.width - 20, height: 600)
//        .background(.white)
        .padding()
        .background(Color("ApplColor"))
        
        
    }
}
