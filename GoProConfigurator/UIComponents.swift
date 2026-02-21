import SwiftUI
import UIKit

// MARK: - UIKit TextField Wrapper
struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .default
        textField.returnKeyType = .done
        textField.delegate = context.coordinator

        // CRITICAL: Set background color to avoid rendering issues
        textField.backgroundColor = UIColor.systemBackground
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.layer.borderWidth = 1.0
        textField.layer.cornerRadius = 8.0

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if different to avoid unnecessary updates
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UIKitTextField

        init(_ parent: UIKitTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.text = textField.text ?? ""
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - Enter Key Handler View
struct EnterKeyHandlerView: UIViewRepresentable {
    let enterKeyHandler: EnterKeyHandler

    func makeUIView(context: Context) -> EnterKeyHandler {
        return enterKeyHandler
    }

    func updateUIView(_ uiView: EnterKeyHandler, context: Context) {
        // No update needed
    }
}

// MARK: - Spinning Sync Icon Component
struct SpinningSyncIcon: View {
    @State private var isRotating = false

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.blue)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isRotating)
            .padding(5)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(5)
            .onAppear {
                isRotating = true
            }
            .onDisappear {
                isRotating = false
            }
    }
}

// MARK: - Status Icon View
struct StatusIconView: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(color)
            .frame(width: 20, height: 20)
    }
}

#Preview("Spinning Sync Icon") {
    SpinningSyncIcon()
        .padding()
}

#Preview("Status Icon View") {
    VStack(spacing: 20) {
        StatusIconView(icon: "checkmark.circle.fill", color: .green)
        StatusIconView(icon: "xmark.circle.fill", color: .red)
        StatusIconView(icon: "exclamationmark.triangle.fill", color: .orange)
    }
    .padding()
}
