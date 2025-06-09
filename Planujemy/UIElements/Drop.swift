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
    @Query(sort:\PTask.date) private var all_tasks: [PTask]
    @Query(sort:\Users.Name) private var all_users: [Users]
    
    var body: some View {
        Button(action: {
            try! context.delete(model: Friends.self)
//            try! context.delete(model: Users.self)
//            try! context.delete(model: TaskTag.self)
            try! context.save()
            
        }) {
            Text("Delete user data")
                .font(.subheadline)
                .foregroundColor(.red)
        }
    }
}
