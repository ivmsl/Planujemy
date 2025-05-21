//
//  LoginView 2.swift
//  Planujemy
//
//  Created by Ivan Maslov on 20/04/2025.
//


import SwiftUI

struct LoginView: View {
    @State private var login: String = ""
    @State private var passwd: String = ""
    var body: some View {
        NavigationView() {
            ZStack {
                VStack {}
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                    .background(
                        Color("ApplColor")
                    )
                
                VStack {
                    Spacer()
                    
                    Image(systemName: "text.document")
                        .font(.system(size: 64))
                    Text("Planujemy")
                        .font(.system(size: 54, weight: .bold))
                    //                    .foregroundStyle(.white)
                    Spacer()
                    Button(action: { }) {
                        Text("Login")
                        //                        .bold()
                            .foregroundColor(.black)
                            .font(.title)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width - 50, height: 50)
                            .background(.white)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.black, lineWidth: 2))
                    }
                    Spacer().frame(height: 20)
                    
                    Button(action: { }) {
                        Text("Register")
                        //                        .bold()
                            .foregroundColor(.black)
                            .font(.title)
                            .padding()
                            .frame(
                                width: UIScreen.main.bounds.width - 50, height: 50)
                            .background(.white)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.black, lineWidth: 2))
                    }
                    
                    Spacer()
                        .frame(height: 30)
                    
                    HStack {
                        
                        NavigationLink(destination: MainPlanView()) {
                            Image(systemName: "arrow.right")
                                .font(.subheadline)
                            Text("Offline mode")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    
                    Spacer()
                        .frame(height:30)
                }
                .padding()
            }
            
            //            Text("Wejdź do systemu:")
            //            Form {
            //                TextField("Login", text: $login)
            //                SecureField("Haslo", text: $passwd)
            //                Text("Kontinuj offline")
            //                    .foregroundStyle(.cyan, .red)
            //                    .onTapGesture {
            //                        print("TAP")
            //                    }
            //            }
            //                .padding()
            //            //    .background(.tint)
            //
            //            Spacer( )
            
        }
    }
}

#Preview {
    LoginView()
}
