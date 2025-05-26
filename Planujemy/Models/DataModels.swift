//
//  DataModels.swift
//  Planujemy
//
//  Created by Ivan Maslov on 17/04/2025.
//

import Foundation
import SwiftData
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Error Handling
enum UserFirestoreError: Error, LocalizedError {
    case noAuthenticatedUser
    case noFirebaseID
    case invalidDocumentData
    case missingRequiredFields
    case documentNotFound
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated user found"
        case .noFirebaseID:
            return "User has no Firebase ID"
        case .invalidDocumentData:
            return "Invalid document data from Firestore"
        case .missingRequiredFields:
            return "Missing required fields in Firestore document"
        case .documentNotFound:
            return "User document not found in Firestore"
        }
    }
}


@Model
class Users: Identifiable {
    
    @Attribute(.unique) var id: UUID
    var fID: String?
    var Name: String
    var LastSyncDate: Date?
    var AutoSync: Bool = true
    var added: Date?
    var uEmail: String?
    
    
    init(name: String, uEmail: String? = nil, fID: String? = nil) {
        self.id = UUID()
        self.Name = name
        self.fID = fID
        self.LastSyncDate = nil
        self.AutoSync = true
        self.added = Date.now
        self.uEmail = uEmail
    }
    
    
    // MARK: - Firestore Operations
        
    /// Creates a new user document in Firestore
    func createInFirestore() async throws {
            guard let currentUser = Auth.auth().currentUser else {
                throw UserFirestoreError.noAuthenticatedUser
            }
            
            // Set fID to Firebase user's UID if not already set
            if self.fID == nil {
                self.fID = currentUser.uid
            }
            
            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "id": self.fID ?? currentUser.uid,
                "name": self.Name,
                "added": FieldValue.serverTimestamp(),
                "last_sync": Timestamp(date: Date()),
                "auto_sync": self.AutoSync,
                "email": self.uEmail ?? ""
            ]
            
            try await db.collection("users").document(currentUser.uid).setData(userData)
            self.LastSyncDate = Date()
        }
    
    func updateInFirestore() async throws {
            guard let fID = self.fID else {
                throw UserFirestoreError.noFirebaseID
            }
            
            let db = Firestore.firestore()
            let updateData: [String: Any] = [
                "name": self.Name,
                "email": self.uEmail ?? "",
                "last_sync": Timestamp(date: Date()),
                "auto_sync": self.AutoSync
            ]
            
            try await db.collection("users").document(fID).updateData(updateData)
            self.LastSyncDate = Date()
        }
    
    /// Creates a User instance from Firestore document
        static func fromFirestore(document: DocumentSnapshot) throws -> Users {
            guard let data = document.data() else {
                throw UserFirestoreError.invalidDocumentData
            }
            
            guard let name = data["name"] as? String,
                  let id = data["id"] as? String else {
                throw UserFirestoreError.missingRequiredFields
            }
            
            let user = Users(name: name, fID: id)
            
            // Handle optional timestamp fields
            if let lastSyncTimestamp = data["last_sync"] as? Timestamp {
                user.LastSyncDate = lastSyncTimestamp.dateValue()
            }
            
            if let addedTimestamp = data["added"] as? Timestamp {
                user.added = addedTimestamp.dateValue()
            }
            
            if let uEmailString = data["email"] as? String {
                user.uEmail = uEmailString
            }
            
            if let autoSync = data["auto_sync"] as? Bool {
                user.AutoSync = autoSync
            }
            
            return user
        }
    
    /// Fetches user data from Firestore and updates local model
        func syncFromFirestore() async throws {
            guard let fID = self.fID else {
                throw UserFirestoreError.noFirebaseID
            }
            
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(fID).getDocument()
            
            guard let data = document.data() else {
                throw UserFirestoreError.documentNotFound
            }
            
            // Update local properties with Firestore data
            if let name = data["name"] as? String {
                self.Name = name
            }
            
            if let uEmailString = data["email"] as? String {
                self.uEmail = uEmailString
            }
            
            if let autoSync = data["auto_sync"] as? Bool {
                self.AutoSync = autoSync
            }
            
            if let lastSyncTimestamp = data["last_sync"] as? Timestamp {
                self.LastSyncDate = lastSyncTimestamp.dateValue()
            }
        }
    
    /// Checks if user exists in Firestore
        static func existsInFirestore(uid: String) async throws -> Bool {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(uid).getDocument()
            return document.exists
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
class PTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var fID: String? //firebase document ID
    
    // User references
    var from_user_fID: String? //firebase user ID
    var to_user_fID: String? //firebase user ID
    var owner_fID: String? //firebase user ID
    
    // Usernames
    var FromUserName: String? //firebase username
    var ToUserName: String? //firebase username
    
    // Task data
    var title: String
    var date: Date
    var desc: String?
    
    // Tag relationship - ADD THESE:
    var tag: TaskTag? //
    var tagID: String? // For Firebase reference
    
    // Task properties — they are all important
    var AutoReminder: Bool = false
    var IsUrgent: Bool = false
    var IsImportant: Bool = false
    var IsAutoComplete: Bool = true
    var IsAutoFail: Bool = false
    var IsDone: Bool = false
    
    var DateOfCompletion: Date?
    var DateOfLastReminder: Date?
    
    // Sync properties - ADD THESE:
    var IsSynced: Bool = false
    var ReceivedDate: Date?
    
    // Sharing properties - ADD THESE:
    var IsShared: Bool = false
    
    init(title: String, date: Date, desc: String? = nil, tag: TaskTag? = nil, opt: [TaskOptions] = [.Usual]) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.desc = desc
        self.tag = tag
        self.tagID = tag?.id.uuidString // Set Firebase reference
        
        // Set owner to current Firebase user
        if let currentUser = Auth.auth().currentUser {
            self.owner_fID = currentUser.uid
        }
        
        // Handle options
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
    var fID: String? //Firebase ID
    var owner_fID: String? // Firebase user ID who owns this tag
    var symImage: String?
    var name: String
    var col: RGBA
    var IsSynced: Bool = false // Track sync status
    
    init(name: String, symImage: String? = nil) {
        self.id = UUID()
        self.name = name
        self.col = RGBA()
        self.symImage = symImage
        
        // Set owner to current user
        if let currentUser = Auth.auth().currentUser {
            self.owner_fID = currentUser.uid
        }
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
