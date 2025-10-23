import SwiftUI
import UIKit

public struct GeorgianVoicePromptView: View {
    public var onDone: () -> Void
    public var onSkip: () -> Void

    public init(onDone: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onDone = onDone
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("Enable Georgian audio")
                .font(.title3).bold()
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("To hear letters as you slide, install the Georgian voice:")
                    .foregroundColor(.secondary)
                Text("1. Open Settings")
                Text("2. Accessibility → Spoken Content → Voices")
                Text("3. Georgian → Download")
                Text("Then return and slide over the text to hear letters.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: openSettings) {
                    Text("Open Settings")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Button(action: onSkip) {
                    Text("Not now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal)
        .presentationDetents([.height(350), .medium])
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        onDone()
    }
}
