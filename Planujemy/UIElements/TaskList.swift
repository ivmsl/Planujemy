//
//  TaskList.swift
//  Planujemy
//
//  Created by Ivan Maslov on 04/05/2025.
//

import SwiftUI
import Foundation
import SwiftData
import FirebaseAuth


struct ShowTaskList: View {
    @Environment(\.modelContext) var context
    @Query var allTaskList: [PTask]
    @Binding var isVisible: Bool
    
    @State private var taskTagName: String = ""
    @State private var selectedTaskFromList: PTask?
    @State private var editTaskListFromScreen: Bool = false
    
    private var taskList: [PTask] {
            guard let currentUserID = Auth.auth().currentUser?.uid else { return [] }
            
            return allTaskList.filter { task in
                task.owner_fID == currentUserID && !task.IsShared
            }
        }
    
    init(tagInfo: TaskTag?, predicate: Predicate<PTask>?, isVisible: Binding<Bool>, listName: String = "") {
        _isVisible = isVisible
        
        if let tmpTagInfo = tagInfo {
            self._taskTagName = State(initialValue: tmpTagInfo.name)
            let tagID = tmpTagInfo.id
            let predicate = #Predicate<PTask> {
                $0.tag?.id == tagID
                    
            }
            _allTaskList = Query(filter: predicate, sort: \.date)
        }
        else if let pred = predicate {
            if listName != "" {self._taskTagName = State(initialValue: listName)}
            _allTaskList = Query(filter: pred, sort: \.date)
        }
        else {
            _allTaskList = Query(sort: \.date)
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
        .background(Color("LightCol"))
        
        
    }
}
