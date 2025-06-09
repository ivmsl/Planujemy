//
//  NewTagInput.swift
//  Planujemy
//
//  Created by Ivan Maslov on 04/05/2025.
//

import SwiftData
import SwiftUI


struct NewTagInput: View {
    
    @Binding var isPresented: Bool
    @State private var TagName: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.modelContext) private var context
    
    @State private var selectedSymImage: String?
    @State private var taskManager: PrivateTaskManager?
    
    init(isPresented: Binding<Bool>, taskManager: PrivateTaskManager?) {
        _isPresented = isPresented
        _taskManager = State(initialValue: taskManager)
    }
    
    private func SaveTag() -> Void {
//        if let tag = self.tagData {
//            // EDITING existing tag
//            tag.name = self.tagName
////            tag.symImage = self.selectedSymImage
////            tag.col = self.selectedColor // Assuming you have color picker
//            
//            // Mark for sync and save locally
//            taskManager?.markTagForSync(tag)
//            
//            Task {
//                await taskManager?.quickSync()
//            }
//            
//        } else {
            // CREATING new tag
            Task {
                await taskManager?.createTag(
                    name: TagName,
                    symImage: selectedSymImage?.isEmpty == true ? nil : selectedSymImage
                )
            }
//        }
        
//        shouldClose = true
        isPresented = false
    }
    
    func addNewTag() -> Void {
        if !TagName.isEmpty {
            let newTag = TaskTag(name: TagName)
            context.insert(newTag)
            try! context.save()
        }
//        print("Added new tag: \(TagName)")
        isPresented = false
        TagName = ""
    }
    
    var body: some View {
        TextField("New category", text: $TagName)
            .padding()
            .background(Color("LightCol"))
            .cornerRadius(8)
            .focused($isFocused)
            .onSubmit {SaveTag()}
            .onAppear {
                isFocused = true
            }
            .onChange(of: isFocused)
            {
                if !isFocused && isPresented {
                    SaveTag()
                }
            }
                      
        VStack {
            
        }
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true
//    NewTagInput(isPresented: $isPresented, taskManager: )
}
