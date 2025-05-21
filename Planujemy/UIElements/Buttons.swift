//
//  BigButton.swift
//  Planujemy
//
//  Created by Ivan Maslov on 04/05/2025.
//

import Foundation
import SwiftUI

struct BigButton: View {
    var closure: () -> Void
    var text: String
    
    
    
    var body: some View {
        
        Button(action: {
            closure()
        }) {
            Text(text)
            //                        .bold()
                .foregroundColor(.black)
                .font(.title2)
                .padding()
                .frame(width: UIScreen.main.bounds.width - 50, height: 50)
                .background(.white.opacity(1))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.black, lineWidth: 2))
        }
        
    }
}


struct MediumButton: View {
    var closure: () -> Void
    var text: String
    var imagename: String?
    var col: Color = .black
    
    
    var body: some View {
        
        Button(action: {
            closure()
        }) {
            if (imagename == nil) {
                Text(text)
                    .foregroundColor(col)
                    .font(.title2)
                    .padding()
                    .frame(height: 50)
                    .background(.white.opacity(1))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(col, lineWidth: 2))
            }
            else {
                Image(systemName: imagename!)
                    .foregroundColor(col)
                    .font(.title2)
                    .padding()
                    .frame(height: 50)
                    .background(.white.opacity(1))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(col, lineWidth: 2))
            }
            
        }
    }
}
