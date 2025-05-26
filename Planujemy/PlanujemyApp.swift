//
//  PlanujemyApp.swift
//  Planujemy
//
//  Created by Ivan Maslov on 17/04/2025.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct PlanujemyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [PTask.self, TaskTag.self, Users.self])
    }
}

struct RootView: View {
    @State private var isUserAuthenticated = false
    @State private var isCheckingAuth = true
    @State private var needsProfileSetup = false
    
    var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView("Loading...")
            }
            else if needsProfileSetup {
                ProfileSetupView(onProfileComplete: {
                    // Manually recheck authentication state
                    checkAuthenticationStateOnce()
                })
            } else if isUserAuthenticated {
                MainPlanView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            checkAuthenticationState()
        }
    }
    
    private func checkAuthenticationState() {
        Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                updateAuthenticationState(for: user)
            }
        }
    }
    
    // Extract the logic to a separate method for reuse
    private func updateAuthenticationState(for user: FirebaseAuth.User?) {
        if let user = user {
            // Check if user has completed profile setup
            if user.displayName == nil || user.displayName?.isEmpty == true {
                self.needsProfileSetup = true
                self.isUserAuthenticated = false
            } else {
                self.needsProfileSetup = false
                self.isUserAuthenticated = true
            }
        } else {
            self.isUserAuthenticated = false
            self.needsProfileSetup = false
        }
        
        print("Profile setup: ", self.needsProfileSetup, "User authenticated: ", self.isUserAuthenticated)
        self.isCheckingAuth = false
    }
    
    // Method to manually check state once (for profile completion)
    private func checkAuthenticationStateOnce() {
        let currentUser = Auth.auth().currentUser
        updateAuthenticationState(for: currentUser)
    }
}
