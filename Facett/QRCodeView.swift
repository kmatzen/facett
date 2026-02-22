import SwiftUI
import CoreImage.CIFilterBuiltins
import Combine

// MARK: - QR Code Section
struct QRCodeSection: View {
    @Binding var showQr: Bool
    @ObservedObject var configManager: ConfigManager

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showQr.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "qrcode")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)

                    Text("QR Codes")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: showQr ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showQr ? 0 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showQr)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // QR Code Content
            if showQr {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 20)

                    QRCodeView()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .padding(.top, 8)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
    }
}

// MARK: - QRCodeResources
class QRCodeResources {
    static let shared = QRCodeResources()
    let context: CIContext
    let qrCodeGenerator: CIQRCodeGenerator

    private init() {
        self.context = CIContext()
        self.qrCodeGenerator = CIFilter.qrCodeGenerator()
    }

    static func initialize() {
        _ = QRCodeResources.shared
    }
}

// MARK: - QRCodeView
struct QRCodeView: View {
    private let context = QRCodeResources.shared.context
    private let qrCodeGenerator = QRCodeResources.shared.qrCodeGenerator

    @State private var initialBrightness: CGFloat = UIScreen.main.brightness
    @State private var brightnessCancellable: AnyCancellable?
    @State private var selectedTab: QRTab = .timecode
    @State private var showResetConfirmation = false
    @State private var internalSelectedTab: QRTab = .timecode

    enum QRTab: String, CaseIterable {
        case timecode = "Time"
        case reboot = "Reboot"
        case reset = "Reset"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Tab Selector with better styling
            Picker("QR Code Type", selection: $internalSelectedTab) {
                ForEach(QRTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 4)
            .onChange(of: internalSelectedTab) { newTab in
                if newTab == .reset {
                    showResetConfirmation = true
                } else {
                    selectedTab = newTab
                }
            }

            // QR Code Display with description
            VStack(spacing: 12) {
                // Description
                VStack(spacing: 4) {
                    Text(tabDescription(for: selectedTab))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                // QR Code
                TimelineView(.animation) { context in
                    if let qrCodeImage = generateQRCode(for: selectedTab, date: context.date) {
                        Image(uiImage: generateUIImage(from: qrCodeImage))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 250, maxHeight: 250)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .accessibilityIdentifier("QRCodeImage")
                    }
                }
                .onAppear(perform: setMaxBrightness)
                .onDisappear(perform: restoreBrightness)
            }
        }
        .alert("⚠️ Full Reset", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {
                internalSelectedTab = selectedTab
            }
            Button("Show Reset Code", role: .destructive) {
                selectedTab = .reset
                internalSelectedTab = .reset
            }
        } message: {
            Text("This QR code will perform a complete factory reset of the camera, including formatting the SD card. This action cannot be undone. Are you sure you want to proceed?")
        }
    }

    private func tabDescription(for tab: QRTab) -> String {
        switch tab {
        case .timecode:
            return "Set camera time and date"
        case .reboot:
            return "Restart camera"
        case .reset:
            return "Complete factory reset"
        }
    }

    private func setMaxBrightness() {
        initialBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 0.99
        UIScreen.main.brightness = 1.0
        brightnessCancellable = NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)
            .sink { _ in initialBrightness = UIScreen.main.brightness }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = .light
            }
        }
    }

    private func restoreBrightness() {
        UIScreen.main.brightness = initialBrightness
        brightnessCancellable?.cancel()

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    private func generateQRCode(for tab: QRTab, date: Date) -> CIImage? {
        let message: String

        switch tab {
        case .timecode:
            let calendar = Calendar.current

            // Extract components for the timestamp
            let day = calendar.component(.day, from: date)
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date) % 100 // Last two digits of the year
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let second = calendar.component(.second, from: date)
            let millisecond = calendar.component(.nanosecond, from: date) / 1_000_000

            let timestamp = String(format: "%02d%02d%02d%02d%02d%02d.%03d", year, month, day, hour, minute, second, millisecond)
            message = "oT\(timestamp)"
        case .reboot:
            message = "!OR"
        case .reset:
            message = "!RESET!FORMAT!FRESET*BOOT=\"!Lbt\"!SAVEbt=*BITR=200*TUSB=1"
        }
        return createQRCode(from: message)
    }

    private func createQRCode(from message: String) -> CIImage? {
        guard let data = message.data(using: .ascii) else { return nil }
        qrCodeGenerator.message = data
        qrCodeGenerator.correctionLevel = "M"
        return qrCodeGenerator.outputImage
    }

    private func generateUIImage(from ciImage: CIImage) -> UIImage {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return UIImage() }
        return UIImage(cgImage: cgImage)
    }
}
