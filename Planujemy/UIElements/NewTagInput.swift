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
    
    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
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
            .background(Color("AccColour").opacity(0.5))
            .cornerRadius(8)
            .focused($isFocused)
            .onSubmit {addNewTag()}
            .onAppear {
                isFocused = true
            }
            .onChange(of: isFocused)
            {
                if !isFocused && isPresented {
                    addNewTag()
                }
            }
                      
        VStack {
            
        }
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    NewTagInput(isPresented: $isPresented)
}
