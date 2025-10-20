//
//  DateSeparatorView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct DateSeparatorView: View {
    let date: Date
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
            
            Text(date.dateSeparatorText())
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
}

