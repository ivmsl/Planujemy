//
//  SmallTaskCard.swift
//  Planujemy
//
//  Created by Ivan Maslov on 27/04/2025.
//

import SwiftUI
import SwiftData


struct SmallTaskCard: View {
    private var taskData: PTask?
    @State var hline: String = ""
    @State var uline: String = ""
    @State var dzn: Date = Date()
    @State var col: Color = Color.blue
    @State private var dtformat: Date.FormatStyle = .dateTime.hour().minute()
    
    @State private var taskOpt: Set<TaskOptions> = []
    
    //        var offset: CGFloat = 0;
    
    public init() {}
    
    public init(hline: String, uline: String, dzn: Date, col: Color, opt: [TaskOptions]) {
        
        self.init()
        
        self.hline = hline
        self.uline = uline
        self.dzn = dzn
        self.col = col
        
        if dzn.formatted(.dateTime.day().month().year()) != Date().formatted(.dateTime.day().month().year()) {
            dtformat = .dateTime.day().month().year().hour().minute()
        }
        self.taskOpt = Set(opt)
    }
    
    public init(tData: PTask, col: Color = Color.blue) {
        self.init()
        
        self.taskData = tData
        self.hline = tData.title
        self.uline = tData.desc ?? ""
        self.dzn = tData.date
        self.col = col
        
        if dzn != Date() {
            dtformat = .dateTime.day().month().hour().minute()
        }
//        self.taskOpt = Set(tData.options)
        
    }
        
        var body: some View {
            VStack {
                HStack {
                    Text(hline)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(5)
                        .font(.title2)
                        .bold()
                    
                    Text(dzn, format: self.dtformat)
                        .padding(5)
                }
                HStack {
                    Text(uline)
                            .lineLimit(3)
                            .padding(5)
                    Spacer()
                }
                HStack(spacing: 3) {
                    Spacer()
                    Spacer()
                    if (taskData?.IsImportant ?? false) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    if (taskData?.IsAutoComplete ?? false) {
                        Image(systemName: "calendar.badge.checkmark.rtl")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            
                    }
                    if (taskData?.IsAutoFail ?? false) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            
                    }
                    
                }.padding(5)
                    
                    
            }
            .padding(5)
            .border(col, width: 1)
            .cornerRadius(10)
            .background(Color("LightCol").opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color("BorderGray"), lineWidth: 2))
            
    }
    
    
}

#Preview {
    SmallTaskCard(hline: "Headline on on", uline: "Desc", dzn: Date(), col: Color(.red), opt: [.IsAutocomplete, .IsImportant])
}

