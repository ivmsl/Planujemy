//
//  CCheckbox.swift
//  Planujemy
//
//  Created by Ivan Maslov on 27/04/2025.
//

import SwiftUI


struct CustomCheckboxBorderless: View {
    @Binding var isChecked: Bool
    var label: String?
    var color: Color = .primary
    var bckColor: Color? = nil
    var size: CGFloat = 14
    var imgName: String = "star"
    var imgPressed: String? = nil
    
    
    var body: some View {
    
        
        
        ZStack {
            if isChecked {
                Image(systemName: imgPressed != nil ? imgPressed! : imgName + ".fill")
                    .foregroundColor(color)
                    .font(.system(size: size))
            } else {
                Image(systemName: imgName)
                    .foregroundColor(bckColor ?? color)
                    .font(.system(size: size))
            }
            
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isChecked.toggle()
        }
    }
}


struct CustomCheckbox: View {
    @Binding var isChecked: Bool
    var label: String?
    var color: Color = .primary
    var bckColor: Color? = nil
    var size: CGFloat = 14
    var imgName: String = "star"
    
    var isStroke: Bool = true
    
    var body: some View {
    
        
        
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(bckColor != nil && !isChecked ? bckColor ?? color : color,
                        lineWidth: isStroke ? 1 : 0 )
                .frame(width: size, height: size)
            
            
            if isChecked {
                Image(systemName: imgName)
                    .foregroundColor(color)
                    .font(.system(size: 14))
            }
            
//            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
//                .foregroundColor(color)
//                .onTapGesture {
//                    isChecked.toggle()
//                }
//            if let label = label {
//                Text(label)
//            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isChecked.toggle()
//            print("Tapped", isChecked)
        }
    }
}
//
struct DullCustomCheckbox: View {
    var color: Color = .gray
    var size: CGFloat = 14
    
    var body: some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color, lineWidth: 1)
                .frame(width: size, height: size)
        }
        .contentShape(Rectangle())
    }
}



#Preview {
    @Previewable @State var isChecked = false
    CustomCheckboxBorderless(isChecked: $isChecked)
}
