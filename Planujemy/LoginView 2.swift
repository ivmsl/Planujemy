//
//  LoginView 2.swift
//  Planujemy
//
//  Created by Ivan Maslov on 20/04/2025.
//


import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseCore
import _Concurrency

enum LoginScreenState {
    case start, signupPressed, loginPressed, signupSuccess, loginSuccess, loginFailed
}


struct ProfileSetupView: View {
    @State private var uname: String = ""
    @State private var isUpdating: Bool = false
    @State private var updateError: String? = nil
    @Environment(\.modelContext) var context
    
    var onProfileComplete: (() -> Void)?
    
    var body: some View {
        ZStack {
            VStack {}
                .frame(width: UIScreen.main.bounds.width,
                       height: UIScreen.main.bounds.height)
                .background(Color("LightCol"))
            
            
            
            VStack(spacing: 24) {
                Spacer()
                VStack() {
                    Spacer()
                    Text("Planujemy")
                        .font(.system(size: 54, weight: .bold))
                }
                .frame(height: 200)
                Spacer()
                
                VStack {
                    Text("Choose a username")
                        .font(.title2)
                        .bold()
                    Text("Your username will be visible to your friends")
                    Text("So choose wisely :)")
                        .font(.caption)
                }
                
                TextField("Username", text: $uname)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16.0)
                    .frame(height: 45)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color("BorderGray"), lineWidth: 2)
                    )
                
                if let error = updateError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                        .multilineTextAlignment(.center)
                }
                
                if isUpdating {
                    ProgressView("Updating...")
                } else {
                    BigButton(closure: {
                        updateDisplayName()
                    }, text: "Complete Setup")
                    .disabled(uname.isEmpty)
                }
                
                Spacer()
            }
            .padding(30.0)
        }
    }
    
    // In your ProfileSetupView or wherever you handle profile completion
    private func handleProfileCompletion(usr: User) async {
        do {
            
            // Create local SwiftData user
            let newUser = Users(name: self.uname, uEmail: usr.email)
            
            // Add to local SwiftData context
            context.insert(newUser)
            
            // Create user document in Firestore
            try await newUser.createInFirestore()
            
            // Save local changes
            try context.save()
            
            print("✅ User created successfully in both local and Firestore")
            
            // Call your existing completion handler
            onProfileComplete?()
            
        } catch {
            print("❌ Error creating user: \(error.localizedDescription)")
            // Handle error appropriately - maybe show an alert
            // You might want to rollback local changes if Firestore fails
        }
    }
    
    private func updateDisplayName() {
            guard !uname.isEmpty else { return }
            
            isUpdating = true
            updateError = nil
            
            if let user = Auth.auth().currentUser {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = uname
                
                changeRequest.commitChanges { error in
                    DispatchQueue.main.async {
                        self.isUpdating = false
                        
                        if let error = error {
                            self.updateError = "Error updating username: \(error.localizedDescription)"
                            print("Error updating display name: \(error.localizedDescription)")
                        } else {
                            print("Display name updated successfully to: \(uname)")
                            // The state listener in RootView will automatically detect the change
                            // and navigate to MainPlanView
                            
                            
                            
                            
                            _Concurrency.Task {
                                await self.handleProfileCompletion(usr: user)
                            }
                        }
                    }
                }
            }
        }
}

struct LoginView: View {
    @State private var email: String = ""
    @State private var passwd: String = ""
    @State private var uname: String = ""
    @State private var isEmailValid: Bool = false
    
    @State private var user: FirebaseAuth.User? = nil
    
    @State private var isSignupSelected: Bool = false
    @State private var isLoginSelected: Bool = false
    @State private var isSignupSuccessfull: Bool = false
    @State private var isEmailError:Bool = false
    @State private var isAuthError: Bool = false
    
    private func validateEmail() -> Void {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        self.isEmailValid = emailPred.evaluate(with: email)
    }
    
    var body: some View {
        NavigationView() {
            ZStack {
                VStack {}
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                    .background(
                        Color("LightCol")
                    )
                
                VStack() {
                    
                    VStack() {
                        Spacer()
                        Text("Planujemy")
                            .font(.system(size: 54, weight: .bold))
                    }
                    .frame(height: 200)
                    
                    
                    VStack {
                        
                        if !isLoginSelected && !isSignupSuccessfull {
                            
                        VStack(spacing: 24) {
                            Spacer()
                            
                            VStack {
                                Text("Create an account")
                                    .font(.title2)
                                    .bold()
                                Text("Enter your email to sign up")
                            }
                            
                            
                            TextField("\("email@example.com")", text: $email)
                                .disableAutocorrection(true)
                                .textInputAutocapitalization(.never)
                                .padding(.horizontal, 16.0)
                                .frame(height: 45)
        //                        .cornerRadius(8)
                                .overlay(
                                    
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color("BorderGray"), lineWidth: 2)
                                )
                                .overlay(
                                    HStack {
                                        Spacer()
                                        
                                        if      !email.isEmpty {
                                            Image( systemName: isEmailValid ? "checkmark" : "xmark")
                                                .frame(width: 24, height: 24)
                                                .padding(.trailing, 8)
                                                
                                        }
                                    }
                                )
                                    
                                .frame(height: 50)
                                .onChange(of: email,
                                {
                                    validateEmail()
                                    isEmailError = false
                                    
                                })
                            if isEmailError {
                                Text("Error: No valid email provided")
                                    .font(.caption)
                                    .foregroundStyle(Color.red)
                            }
                            
                            if !isSignupSelected {
                                VStack(spacing: 24) {
                                    BigButton(closure: {
                                        if !email.isEmpty && isEmailValid {
                                            withAnimation(.easeIn) {
                                                isSignupSelected = true
                                            }
                                        } else {
                                            withAnimation(.easeIn) {
                                                isEmailError = true
                                            }
                                        }
                                        
                                    }, text: "Continue")
                                    
                                    ZStack {
                                        Divider()
                                        Text("or")
                                    }
                                    BigButton(closure: {
                                        withAnimation(.easeIn) {
                                            isLoginSelected = true
                                        }
                                    }, text: "Log In")
                                    
                                    Text("By clicking continue you agree to our Terms of Service and Privacy Policy ")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                               
                            } else {
                                VStack(spacing: 24) {
                                    SecureField("\("Password")", text: $passwd)
                                        .disableAutocorrection(true)
                                        .padding(.horizontal, 16.0)
                                        .frame(height: 45)
                //                        .cornerRadius(8)
                                        .overlay(
                                            
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(Color("BorderGray"), lineWidth: 2)
                                        )
                                        .onChange(of: passwd) {
                                            isAuthError = false
                                        }
                                    
                                    if isAuthError {
                                        Text("Password error: it should contain at least 6 characters, one special character and one number")
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(Color.red)
                                    }

                                    BigButton(closure: {
                                        Auth.auth().createUser(withEmail: email, password: passwd) { authResult, authErr in
                                            if let _ = authErr {
                                                withAnimation(.easeIn) {
                                                    isAuthError = true
                                                }
                                            } else {
                                                isSignupSuccessfull = true
                                                user = Auth.auth().currentUser!
                                            }
                                            print(authResult ?? " ", authErr ?? " ")
                                            
                                        }
                                        
                                    }, text: "Sign Up")
                                    
                                    
                                    BigButton(closure: {
                                        withAnimation(.easeIn) {
                                            isSignupSelected = false
                                        }
                                        passwd = ""
                                        email = ""
                                        
                                    }, text: "Back")
                                }
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                                
                            }
                                
                            }.transition(.opacity.combined(with: .move(edge: .leading)))
                                                        
                        } else if isLoginSelected { //ifnotIsLogin selected!!!
                               
                               VStack(spacing: 24) {
                                   Spacer()
                                   VStack {
                                       Text("Login into an account")
                                           .font(.title2)
                                           .bold()
                                       Text("Enter your email and your password")
                                   }
                                   Spacer()
                                   
                                   TextField("\("email@example.com")", text: $email)
                                       .disableAutocorrection(true)
                                       .textInputAutocapitalization(.never)
                                       .padding(.horizontal, 16.0)
                                       .frame(height: 45)
               //                        .cornerRadius(8)
                                       .overlay(
                                           
                                           RoundedRectangle(cornerRadius: 15)
                                               .stroke(Color("BorderGray"), lineWidth: 2)
                                       )
                                       .overlay(
                                           HStack {
                                               Spacer()
                                               
                                               if      !email.isEmpty {
                                                   Image( systemName: isEmailValid ? "checkmark" : "xmark")
                                                       .frame(width: 24, height: 24)
                                                       .padding(.trailing, 8)
                                                       
                                               }
                                           }
                                       )
                                           
                                       .frame(height: 50)
                                       .onChange(of: email,
                                       {
                                           validateEmail()
                                           
                                       })
                                   
                                   SecureField("\("Password")", text: $passwd)
                                       .disableAutocorrection(true)
                                       .padding(.horizontal, 16.0)
                                       .frame(height: 45)
               //                        .cornerRadius(8)
                                       .overlay(
                                           
                                           RoundedRectangle(cornerRadius: 15)
                                               .stroke(Color("BorderGray"), lineWidth: 2)
                                       )
                                       .onChange(of: passwd) {
                                           isAuthError = false
                                       }
                                   if isAuthError {
                                       Text("Login error. Check if you have provided valid email and password")
                                           .font(.caption)
                                           .multilineTextAlignment(.center)
                                           .foregroundStyle(Color.red)
                                       
                                   }
                                   BigButton(closure: {
                                       Auth.auth().signIn(withEmail: email, password: passwd) { authResult, authErr in
                                           
                                           if let _ = authErr {
                                               withAnimation(.easeIn) {
                                                   isAuthError = true
                                               }
                                               
                                           }
                                           
                                           print(authResult ?? " ", authErr ?? " ", Auth.auth().currentUser?.uid ?? "no")
                                           
                                       }
                                       
                                   }, text: "Log In")
                                   
                                   BigButton(closure: {
                                       withAnimation(.easeIn) {
                                           isLoginSelected = false
                                       }
                                       passwd = ""
                                       email = ""
                                       
                                   }, text: "Back")
                                   
                               }.transition(.opacity.combined(with: .move(edge: .leading)))
                               

                               
                        }
   
                            
                        }
                    
                        Spacer()
                            .frame(height: 100)
                        HStack {
                            
                            NavigationLink(destination: MainPlanView()) {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline)
                                Text("Offline mode")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        
                    }
                    .padding()
                }
                .padding(30.0)
                    
                }
            
        }
}

#Preview {
    LoginView()
}
