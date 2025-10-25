//
//  DefinitionModalView.swift
//  swift_demo
//
//  Created for AI V3: Word Definition Lookup
//

import SwiftUI

/// Modal view displaying Georgian word definition and example
/// Think of this as a Vue modal component: <DefinitionModal v-model:show="showModal" :result="definition" />
struct DefinitionModalView: View {
    let result: DefinitionResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Georgian word (large, prominent)
                    Text(result.word)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    
                    Divider()
                    
                    // Definition (English)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Definition")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(result.definition)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Divider()
                    
                    // Example (Georgian)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Example")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(result.example)
                            .font(.system(size: 14, weight: .regular))
                            .italic()
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Cache indicator (subtle)
                    if result.cached {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("Cached offline")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Word Definition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

/// Loading state for definition modal
struct DefinitionLoadingView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Looking up definition...")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Word Definition")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Error state for definition modal
struct DefinitionErrorView: View {
    let error: Error
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text(error.localizedDescription)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.georgianRed)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Error")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

#Preview("Definition") {
    DefinitionModalView(result: DefinitionResult(
        word: "გამარჯობა",
        definition: "A greeting meaning 'hello' or 'hi', used in casual conversation between friends and peers.",
        example: "გამარჯობა, როგორ ხარ? (Hi, how are you?)",
        cached: true
    ))
}

#Preview("Loading") {
    DefinitionLoadingView()
}

#Preview("Error") {
    DefinitionErrorView(error: DefinitionError.offline)
}

