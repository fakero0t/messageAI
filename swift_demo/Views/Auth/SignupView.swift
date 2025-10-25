//
//  SignupView.swift
//  swift_demo
//
//  Created by ary on 10/20/25.
//

import SwiftUI

struct SignupView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showVoicePrompt = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.georgianRed)
                    Text("Welcome to KaiaaChat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 30)
                
                // Form Fields
                VStack(spacing: 15) {
                    // Username field with availability check
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            TextField("Username", text: $viewModel.username)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: viewModel.username) { oldValue, newValue in
                                    // Auto-check username availability after typing stops
                                    Task {
                                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                                        if viewModel.username == newValue && !newValue.isEmpty {
                                            await viewModel.checkUsernameAvailability()
                                        }
                                    }
                                }
                            
                            if viewModel.isCheckingUsername {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        Text("3-20 characters: letters, numbers, and underscores only")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    TextField("Display Name", text: $viewModel.displayName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
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
                
                // Signup Button
                Button(action: {
                    Task {
                        await viewModel.signup()
                        if viewModel.isAuthenticated {
                            maybePromptForGeorgianVoice()
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Sign Up")
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
                
                // Login Link
                Button(action: {
                    dismiss()
                }) {
                    Text("Already have an account? Login")
                        .foregroundColor(.georgianRed)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding(.top, 50)
            .navigationBarHidden(true)
            .sheet(isPresented: $showVoicePrompt) {
                GeorgianVoicePromptView(onDone: {
                    UserDefaults.standard.set(true, forKey: "geoVoicePromptShown")
                    showVoicePrompt = false
                }, onSkip: {
                    UserDefaults.standard.set(true, forKey: "geoVoicePromptShown")
                    showVoicePrompt = false
                })
            }
        }
    }

    private func maybePromptForGeorgianVoice() {
        // Only once
        if UserDefaults.standard.bool(forKey: "geoVoicePromptShown") { return }
        // If Georgian voice already present, skip
        if TextToSpeechService().hasGeorgianVoice() { return }
        // Show prompt
        showVoicePrompt = true
    }
}

