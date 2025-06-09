//
//  AddFriendInput.swift
//  Planujemy
//
//  Created by Ivan Maslov on 04/05/2025.
//

import SwiftData
import SwiftUI
import FirebaseAuth

struct AddFriendInput: View {
    
    @Binding var isPresented: Bool
    @State private var friendEmail: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.modelContext) private var context
    
    @State private var friendManager: FriendManager?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isLoading = false
    
    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }
    
    private func sendFriendRequest() {
        guard !friendEmail.isEmpty else {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await friendManager?.sendFriendRequest(to: friendEmail)
                
                await MainActor.run {
                    showAlert(title: "Success", message: "Friend request sent to \(friendEmail)")
                    friendEmail = ""
                    isPresented = false
                    isLoading = false
                }
                
            } catch let error as FriendManagementError {
                await MainActor.run {
                    showAlert(title: "Error", message: error.localizedDescription)
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    showAlert(title: "Error", message: "Failed to send friend request: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    var body: some View {
        
        HStack {
            TextField("Friend's email address", text: $friendEmail)
                .padding()
                .background(Color("LightCol"))
                .cornerRadius(8)
                .focused($isFocused)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit {
                    if !isLoading {
                        sendFriendRequest()
                    }
                }
                .onAppear {
                    // Initialize FriendManager when view appears
                    if friendManager == nil {
                        friendManager = FriendManager(modelContext: context)
                    }
                    isFocused = true
                }
                .onChange(of: isFocused) {
                    if !isFocused && isPresented && !friendEmail.isEmpty && !isLoading {
                        sendFriendRequest()
                    }
                }
                .disabled(isLoading)
            
            // Loading indicator or send button
            if isLoading {
                ProgressView()
                    .padding(.trailing)
            } else {
                Button(action: sendFriendRequest) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                .padding(.trailing, 8)
                .disabled(friendEmail.isEmpty)
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Friend List View with Add Friend Input
struct FriendListView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var friendManager: FriendManager
    
    @State private var showingAddFriend = false
    @State private var friends: [Friends] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(modelContext: ModelContext) {
        self._friendManager = StateObject(wrappedValue: FriendManager(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // MARK: - Header
            HStack {
                Text("Friends")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // MARK: - Pending Friend Requests Section
            if !pendingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Requests")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(pendingRequests) { request in
                        PendingRequestRow(
                            request: request,
                            onAccept: { acceptRequest(request) },
                            onDecline: { declineRequest(request) }
                        )
                    }
                }
                .padding(.bottom)
            }
            
            // MARK: - Friends List Section
            VStack(alignment: .leading, spacing: 8) {
                if !friends.isEmpty {
                    ForEach(friends) { friend in
                        FriendRow(
                            friend: friend,
                            onDelete: { deleteFriend(friend) }
                        )
                    }
                } else if !isLoading {
                    Text("No friends yet")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            
            Spacer()
            
            // MARK: - Add Friend Input
            VStack(spacing: 8) {
                HStack {
                    Text("Add Friend")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                
                AddFriendInput(isPresented: $showingAddFriend)
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .overlay(
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        )
        .onAppear {
            refreshData()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() {
        isLoading = true
        
        Task {
            do {
                async let friendsTask = friendManager.fetchFriends()
                async let requestsTask = friendManager.fetchPendingFriendRequests()
                
                try await friendsTask
                try await requestsTask
                
                await MainActor.run {
                    self.friends = friendManager.friends
                    self.pendingRequests = friendManager.pendingRequests
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to load friends: \(error.localizedDescription)"
                    self.showingAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func acceptRequest(_ request: FriendRequest) {
        Task {
            do {
                try await friendManager.acceptFriendRequest(request)
                await refreshData()
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to accept request: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func declineRequest(_ request: FriendRequest) {
        Task {
            do {
                try await friendManager.declineFriendRequest(request)
                await refreshData()
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to decline request: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func deleteFriend(_ friend: Friends) {
        // You'll need to add a way to get the friend's Firebase UID
        // This might require updating your Friends model to store Firebase UID
        Task {
            do {
                // Note: You'll need to implement a way to get the Firebase UID
                // let friendUID = friend.firebaseUID // Add this to your Friends model
                // try await friendManager.deleteFriend(friend, friendUID: friendUID)
                // await refreshData()
                
                // For now, just show an alert
                await MainActor.run {
                    self.alertMessage = "Delete friend functionality needs Firebase UID mapping"
                    self.showingAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PendingRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUserEmail)
                    .font(.headline)
                Text("Sent: \(request.sendDate, formatter: DateFormatter.shortDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Decline") {
                    onDecline()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color("LightCol").opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct FriendRow: View {
    let friend: Friends
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friend.FriendName.prefix(1).uppercased()))
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.FriendName)
                    .font(.headline)
                
                // Note: You might want to add email to Friends model
                Text("Friend")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color("LightCol").opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    
    VStack {
        AddFriendInput(isPresented: $isPresented)
            .padding()
        
        Spacer()
        
        // Preview of the full friend list
        // FriendListView(modelContext: modelContext) // You'd need to provide a real ModelContext
    }
}
