//
//  Drop.swift
//  Planujemy
//
//  Created by Ivan Maslov on 12/05/2025.
//
import SwiftData
import SwiftUI


struct DropTasksButton: View {
    
    @Environment(\.modelContext) private var context
    @Query(sort:\Task.date) private var all_tasks: [Task]
    
    var body: some View {
        Button(action: {
            try! context.delete(model: Task.self)
            try! context.save()
            
        }) {
            Text("Delete user data")
                .font(.subheadline)
                .foregroundColor(.red)
        }
    }
}
