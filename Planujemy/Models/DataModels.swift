//
//  DataModels.swift
//  Planujemy
//
//  Created by Ivan Maslov on 17/04/2025.
//

import Foundation
import SwiftData
import SwiftUI


@Model
class User: Identifiable {
    
    @Attribute(.unique) var id: UUID
    var Name: String
    var IsOffline: Bool
    var JWT: String?
    var RefreshToken: String?
    var LastSyncDate: Date?
    
    
    init(name: String) {
        self.id = UUID()
        self.Name = name
        self.IsOffline = true
    }
}




//enum TaskState {
//    case
//}

enum TaskOptions: Int, Codable {
    case IsImportant, IsUrgent, IsAutocomplete, IsReminder, Usual, IsDone, IsAutoFail
}

struct RGBA: Codable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    
    init() {
        self.r = .random(in: 0...1)
        self.g = .random(in: 0...1)
        self.b = .random(in: 0...1)
        self.a = 1
    }
    
    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    init(col: Color) {
        let resCol = col.resolve(in: .init())
        r = Double(resCol.red)
        g = Double(resCol.green)
        b = Double(resCol.blue)
        a = Double(resCol.opacity)
    }
    
    var color: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}

@Model
class Task: Identifiable {
    @Attribute(.unique) var id: UUID
    
    //User ref via UUID???
    var from_user: UUID?
    var to_user: UUID?
    
    //Usernames
    var FromUserName: String?
    var ToUserName: String?
    
    var title: String
    var date: Date
    var desc: String?
    var tag: TaskTag?
    
    var AutoReminder: Bool = false
    var IsUrgent: Bool = false
    var IsImportant: Bool = false
    var IsAutoComplete: Bool = true
    var IsAutoFail: Bool = false
    var IsDone: Bool = false
    
    var DateOfCompletion: Date?
    var DateOfLastReminder: Date?
    
    
    var IsSynced: Bool = false
    var ReceivedDate: Date?
    
    init(title: String, date: Date, desc: String? = nil, opt: [TaskOptions] = [.Usual]) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.desc = desc
        
        if opt.contains(.IsAutoFail) {
            self.IsAutoComplete = false
            self.IsAutoFail = true
        }
        
        if opt.contains(.IsUrgent) {
            self.IsUrgent = true
        }
        
        if opt.contains(.IsImportant) {
            self.IsImportant = true
        }
    }
    
}


@Model
class TaskTag: Identifiable {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var col: RGBA
//    @Relationship(deleteRule: .nullify, inverse: \Task.tag) var tasks: [Task]?
    
    
    init(name: String) {
        
        self.id = UUID()
        self.name = name
        self.col = RGBA()
    }
}

@Model
class Friends: Identifiable {
    
    var id: UUID
    var UserID: UUID
    var FriendID: UUID
    
    var FriendName: String
    
    init(userID: UUID, friendID: UUID, friendName: String) {
        self.id = UUID()
        self.UserID = userID
        self.FriendID = friendID
        self.FriendName = friendName
    }
}
