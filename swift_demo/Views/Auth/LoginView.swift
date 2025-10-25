//
//  LoginView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showSignup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.georgianRed)
                    Text("Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 30)
                
                // Form Fields
                VStack(spacing: 15) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Login Button
                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Login")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.georgianRed)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                
                // Signup Link
                Button(action: {
                    showSignup = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.georgianRed)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding(.top, 50)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignup) {
                SignupView(viewModel: viewModel)
            }
        }
    }
}

