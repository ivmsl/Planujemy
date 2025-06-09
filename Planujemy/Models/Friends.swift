//
//  Friends.swift
//  Planujemy
//
//  Created by Ivan Maslov on 02/06/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

// MARK: - Friend Request Model
@Model
class FriendRequest: Identifiable {
    @Attribute(.unique) var id: UUID
    var firebaseID: String?
    var fromUID: String
    var toUID: String
    var fromUserEmail: String
    var toUserEmail: String
    var sendDate: Date
    var resolvedDate: Date?
    var accepted: Bool
    var resolved: Bool
    
    init(fromUID: String, toUID: String, fromUserEmail: String, toUserEmail: String) {
        self.id = UUID()
        self.fromUID = fromUID
        self.toUID = toUID
        self.fromUserEmail = fromUserEmail
        self.toUserEmail = toUserEmail
        self.sendDate = Date()
        self.accepted = false
        self.resolved = false
        self.resolvedDate = nil
    }
}


enum FriendManagementError: Error, LocalizedError {
    case noAuthenticatedUser
    case userNotFound
    case alreadyFriends
    case requestAlreadyExists
    case requestNotFound
    case cannotAddSelf
    case invalidEmail
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated user found"
        case .userNotFound:
            return "User not found"
        case .alreadyFriends:
            return "Users are already friends"
        case .requestAlreadyExists:
            return "Friend request already exists"
        case .requestNotFound:
            return "Friend request not found"
        case .cannotAddSelf:
            return "Cannot add yourself as a friend"
        case .invalidEmail:
            return "Invalid email address"
        case .firestoreError(let message):
            return "Firestore error: \(message)"
        }
    }
}

// MARK: - Friend Manager
@MainActor
class FriendManager: ObservableObject {
    private let db = Firestore.firestore()
    private let modelContext: ModelContext
    
    @Published var isLoading = false
    @Published var pendingRequests: [FriendRequest] = []
    @Published var friends: [Friends] = []
    @Published var lastError: String?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - 1. Find User by Email
    
    /// Search for a Firebase user by email
    func findUserByEmail(_ email: String) async throws -> (uid: String, name: String)? {
        guard let currentUser = Auth.auth().currentUser else {
            throw FriendManagementError.noAuthenticatedUser
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            throw FriendManagementError.invalidEmail
        }
        
        // Prevent adding self
        if email.lowercased() == currentUser.email?.lowercased() {
            throw FriendManagementError.cannotAddSelf
        }
        
        // Search in users collection by email
        let usersQuery = db.collection("users")
            .whereField("email", isEqualTo: email.lowercased())
            .limit(to: 1)
        
        do {
            let snapshot = try await usersQuery.getDocuments()
            
            if let document = snapshot.documents.first {
                let data = document.data()
                let uid = document.documentID
                let name = data["name"] as? String ?? "Unknown User"
                
                return (uid: uid, name: name)
            }
            
            return nil
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    // MARK: - 2. Send Friend Request
    
    /// Send a friend request to a user by email
    func sendFriendRequest(to email: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FriendManagementError.noAuthenticatedUser
        }
        
        await updateLoadingState(true)
        defer { Task { await updateLoadingState(false) } }
        
        // Find target user
        guard let targetUser = try await findUserByEmail(email) else {
            throw FriendManagementError.userNotFound
        }
        
        // Check if already friends
        if try await areAlreadyFriends(currentUser.uid, targetUser.uid) {
            throw FriendManagementError.alreadyFriends
        }
        
        // Check if request already exists
        if try await friendRequestExists(from: currentUser.uid, to: targetUser.uid) {
            throw FriendManagementError.requestAlreadyExists
        }
        
        // Get current user's data
        let currentUserDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        let currentUserName = currentUserDoc.data()?["name"] as? String ?? "Unknown User"
        
        // Create friend request document
        let requestData: [String: Any] = [
            "from_uid": currentUser.uid,
            "to_uid": targetUser.uid,
            "from_email": currentUser.email ?? "",
            "to_email": email.lowercased(),
            "from_name": currentUserName,
            "to_name": targetUser.name,
            "send_date": FieldValue.serverTimestamp(),
            "accepted": false,
            "resolved": false,
            "resolved_date": NSNull()
        ]
        
        do {
            let docRef = try await db.collection("friend_requests").addDocument(data: requestData)
            
            // Create local FriendRequest model
            let friendRequest = FriendRequest(
                fromUID: currentUser.uid,
                toUID: targetUser.uid,
                fromUserEmail: currentUser.email ?? "",
                toUserEmail: email.lowercased()
            )
            friendRequest.firebaseID = docRef.documentID
            
            modelContext.insert(friendRequest)
            try modelContext.save()
            
            print("✅ Friend request sent to \(email)")
            
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    // MARK: - 3. Check Friend Requests
    
    /// Fetch pending friend requests for current user
    func fetchPendingFriendRequests() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FriendManagementError.noAuthenticatedUser
        }
        
        await updateLoadingState(true)
        defer { Task { await updateLoadingState(false) } }
        
        do {
            // Simplified query - filter only by to_uid, then filter resolved in code
            let requestsQuery = db.collection("friend_requests")
                .whereField("to_uid", isEqualTo: currentUser.uid)
//                .order(by: "send_date", descending: true)
            
            let snapshot = try await requestsQuery.getDocuments()
            
            var requests: [FriendRequest] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Filter out resolved requests in code instead of query
                let resolved = data["resolved"] as? Bool ?? false
                if resolved {
                    continue // Skip resolved requests
                }
                
                guard let fromUID = data["from_uid"] as? String,
                      let toUID = data["to_uid"] as? String,
                      let fromEmail = data["from_email"] as? String,
                      let toEmail = data["to_email"] as? String else {
                    continue
                }
                
                let request = FriendRequest(
                    fromUID: fromUID,
                    toUID: toUID,
                    fromUserEmail: fromEmail,
                    toUserEmail: toEmail
                )
                request.firebaseID = document.documentID
                
                if let sendTimestamp = data["send_date"] as? Timestamp {
                    request.sendDate = sendTimestamp.dateValue()
                }
                
                request.accepted = data["accepted"] as? Bool ?? false
                request.resolved = data["resolved"] as? Bool ?? false
                
                if let resolvedTimestamp = data["resolved_date"] as? Timestamp {
                    request.resolvedDate = resolvedTimestamp.dateValue()
                }
                
                requests.append(request)
            }
            
            await MainActor.run {
                self.pendingRequests = requests
            }
            
            print("✅ Fetched \(requests.count) pending friend requests")
            
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    // MARK: - 4. Accept Friend Request
    
    /// Accept a friend request and add to friends
    func acceptFriendRequest(_ request: FriendRequest) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FriendManagementError.noAuthenticatedUser
        }
        
        guard let requestFirebaseID = request.firebaseID else {
            throw FriendManagementError.requestNotFound
        }
        
        await updateLoadingState(true)
        defer { Task { await updateLoadingState(false) } }
        
        do {
            // Start a batch write
            let batch = db.batch()
            
            // 1. Update friend request as accepted and resolved
            let requestRef = db.collection("friend_requests").document(requestFirebaseID)
            batch.updateData([
                "accepted": true,
                "resolved": true,
                "resolved_date": FieldValue.serverTimestamp()
            ], forDocument: requestRef)
            
            // 2. Add friend to current user's friends subcollection
            let currentUserFriendRef = db.collection("users")
                .document(currentUser.uid)
                .collection("friends")
                .document(request.fromUID)
            
            batch.setData([
                "uid": request.fromUID,
                "email": request.fromUserEmail,
                "added_date": FieldValue.serverTimestamp(),
                "status": "active"
            ], forDocument: currentUserFriendRef)
            
            // 3. Add current user to requester's friends subcollection
            let requesterFriendRef = db.collection("users")
                .document(request.fromUID)
                .collection("friends")
                .document(currentUser.uid)
            
            batch.setData([
                "uid": currentUser.uid,
                "email": currentUser.email ?? "",
                "added_date": FieldValue.serverTimestamp(),
                "status": "active"
            ], forDocument: requesterFriendRef)
            
            // Commit the batch
            try await batch.commit()
            
            // Update local models
            request.accepted = true
            request.resolved = true
            request.resolvedDate = Date()
            
            // Get requester's name for local Friends model
            let requesterDoc = try await db.collection("users").document(request.fromUID).getDocument()
            let requesterName = requesterDoc.data()?["name"] as? String ?? "Unknown User"
            
            // ✅ FIXED: Create local Friends model WITH Firebase UID and email
            let newFriend = Friends(
                userID: UUID(), // Current user's local UUID
                friendID: UUID(), // Friend's local UUID
                friendName: requesterName,
                friendFirebaseUID: request.fromUID, // ✅ This is the key fix!
                friendEmail: request.fromUserEmail  // ✅ Also store email
            )
            
            print("✅ Creating friend with Firebase UID: \(request.fromUID)")
            print("✅ Friend name: \(requesterName)")
            print("✅ Friend email: \(request.fromUserEmail)")
            
            modelContext.insert(newFriend)
            try modelContext.save()
            
            // Add to local friends array immediately
            await MainActor.run {
                self.friends.append(newFriend)
            }
            
            // Remove from pending requests
            if let index = pendingRequests.firstIndex(where: { $0.id == request.id }) {
                await MainActor.run {
                    self.pendingRequests.remove(at: index)
                }
            }
            
            print("✅ Friend request accepted from \(request.fromUserEmail)")
            
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    /// Decline a friend request
    func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let requestFirebaseID = request.firebaseID else {
            throw FriendManagementError.requestNotFound
        }
        
        await updateLoadingState(true)
        defer { Task { await updateLoadingState(false) } }
        
        do {
            // Update friend request as declined and resolved
            try await db.collection("friend_requests").document(requestFirebaseID).updateData([
                "accepted": false,
                "resolved": true,
                "resolved_date": FieldValue.serverTimestamp()
            ])
            
            // Update local model
            request.accepted = false
            request.resolved = true
            request.resolvedDate = Date()
            
            // Remove from pending requests
            if let index = pendingRequests.firstIndex(where: { $0.id == request.id }) {
                await MainActor.run {
                    self.pendingRequests.remove(at: index)
                }
            }
            
            print("✅ Friend request declined from \(request.fromUserEmail)")
            
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    // MARK: - 5. Delete Friend
    
    /// Remove a friend from both users' friends subcollections
    func deleteFriend(_ friend: Friends) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FriendManagementError.noAuthenticatedUser
        }
        
        guard let friendUID = friend.friendFirebaseUID else {
            throw FriendManagementError.firestoreError("Friend Firebase UID not available")
        }
        
        await updateLoadingState(true)
        defer { Task { await updateLoadingState(false) } }
        
        do {
            // Start a batch write to ensure atomicity
            let batch = db.batch()
            
            // 1. Remove friend from current user's friends subcollection
            let currentUserFriendRef = db.collection("users")
                .document(currentUser.uid)
                .collection("friends")
                .document(friendUID)
            
            batch.deleteDocument(currentUserFriendRef)
            
            // 2. Remove current user from friend's friends subcollection
            let friendUserRef = db.collection("users")
                .document(friendUID)
                .collection("friends")
                .document(currentUser.uid)
            
            batch.deleteDocument(friendUserRef)
            
            // Commit the batch
            try await batch.commit()
            
            // Remove from local storage
            modelContext.delete(friend)
            try modelContext.save()
            
            // Remove from local friends array
            if let index = friends.firstIndex(where: { $0.id == friend.id }) {
                await MainActor.run {
                    self.friends.remove(at: index)
                }
            }
            
            print("✅ Friend \(friend.FriendName) removed successfully")
            
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if two users are already friends
    private func areAlreadyFriends(_ userUID: String, _ friendUID: String) async throws -> Bool {
        let friendDoc = try await db.collection("users")
            .document(userUID)
            .collection("friends")
            .document(friendUID)
            .getDocument()
        
        return friendDoc.exists
    }
    
    /// Check if a friend request already exists
    private func friendRequestExists(from fromUID: String, to toUID: String) async throws -> Bool {
        let existingRequest = try await db.collection("friend_requests")
            .whereField("from_uid", isEqualTo: fromUID)
            .whereField("to_uid", isEqualTo: toUID)
            .whereField("resolved", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()
        
        return !existingRequest.documents.isEmpty
    }
    
    /// Validate email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    /// Fetch user's friends list
    func fetchFriends() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FriendManagementError.noAuthenticatedUser
        }
        
        do {
            let friendsSnapshot = try await db.collection("users")
                .document(currentUser.uid)
                .collection("friends")
                .whereField("status", isEqualTo: "active")
                .getDocuments()
            
            var friendsList: [Friends] = []
            
            for document in friendsSnapshot.documents {
                let data = document.data()
                
                if let friendUID = data["uid"] as? String,
                   let friendEmail = data["email"] as? String {
                    
                    // Get friend's details from users collection
                    let friendDoc = try await db.collection("users").document(friendUID).getDocument()
                    let friendName = friendDoc.data()?["name"] as? String ?? "Unknown User"
                    
                    // ✅ FIXED: Create Friends with Firebase UID and email
                    let friend = Friends(
                        userID: UUID(),
                        friendID: UUID(),
                        friendName: friendName,
                        friendFirebaseUID: friendUID, // ✅ Store Firebase UID
                        friendEmail: friendEmail      // ✅ Store email
                    )
                    
                    print("✅ Fetched friend: \(friendName) with UID: \(friendUID)")
                    
                    friendsList.append(friend)
                }
            }
            
            await MainActor.run {
                self.friends = friendsList
            }
            
            print("✅ Fetched \(friendsList.count) friends")
            
        } catch {
            throw FriendManagementError.firestoreError(error.localizedDescription)
        }
    }
    
    // MARK: - State Management
    
    private func updateLoadingState(_ isLoading: Bool) async {
        await MainActor.run {
            self.isLoading = isLoading
        }
    }
    
    private func updateError(_ error: String?) async {
        await MainActor.run {
            self.lastError = error
        }
    }
}
