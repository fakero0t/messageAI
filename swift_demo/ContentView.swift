//
//  ContentView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Main App")
                    .font(.largeTitle)
                    .padding()
                
                if let user = AuthenticationService.shared.currentUser {
                    Text("Welcome, \(user.displayName)!")
                        .font(.title2)
                        .padding()
                }
                
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Logout")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Messaging App")
        }
    }
}

#Preview {
    ContentView()
}
