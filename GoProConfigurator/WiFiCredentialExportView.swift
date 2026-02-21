import SwiftUI
import UniformTypeIdentifiers

struct WiFiCredentialExportView: View {
    @ObservedObject var bleManager: BLEManager
    @State private var showingShareSheet = false
    @State private var credentialsFileURL: URL?
    @State private var isExporting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)

                    Text("WiFi Credential Export")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Export WiFi credentials for connected cameras to enable high-speed file transfers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Connected cameras info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connected Cameras")
                        .font(.headline)

                    if bleManager.connectedGoPros.isEmpty {
                        Text("No cameras connected")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(bleManager.connectedGoPros.values), id: \.peripheral.identifier) { camera in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "camera")
                                        .foregroundColor(.green)

                                    Text(camera.name ?? "Unknown Camera")
                                        .fontWeight(.medium)

                                    Spacer()

                                    if camera.status.apState == 1 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    if let apSSID = camera.status.apSSID {
                                        HStack {
                                            Text("AP SSID:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(apSSID)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    } else {
                                        HStack {
                                            Text("AP SSID:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Not available")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }

                                    if let wifiSSID = camera.status.wifiSSID, !wifiSSID.isEmpty {
                                        HStack {
                                            Text("Connected Client:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(wifiSSID)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }

                                    if let apPassword = camera.status.apPassword, !apPassword.isEmpty {
                                        HStack {
                                            Text("Password:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(apPassword)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    } else {
                                        HStack {
                                            Text("Password:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Not available")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(.leading, 24)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Action buttons
                VStack(spacing: 12) {
                    // Enable WiFi AP button
                    Button(action: {
                        bleManager.enableAPAllDevices()
                        // Wait a moment then get credentials
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            bleManager.getWiFiCredentialsForAllDevices()
                        }
                    }) {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Enable WiFi for All Cameras")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(bleManager.connectedGoPros.isEmpty)

                    // Export credentials button
                    Button(action: exportCredentials) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Credentials via AirDrop")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(bleManager.connectedGoPros.isEmpty || isExporting)

                    if isExporting {
                        ProgressView("Preparing credentials...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }

                // Add bottom padding to ensure content isn't cut off
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
        .navigationTitle("WiFi Export")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = credentialsFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func exportCredentials() {
        isExporting = true

        // Create credentials data
                            let credentials = bleManager.connectedGoPros.values.map { camera in
                        [
                            "camera_id": camera.peripheral.identifier.uuidString,
                            "camera_name": camera.name ?? "Unknown Camera",
                            "primary_ssid": camera.status.apSSID ?? "Unknown",
                            "connected_client_ssid": camera.status.wifiSSID ?? "",
                            "password": camera.status.apPassword ?? "",
                            "ap_state": camera.status.apState ?? 0,
                            "export_timestamp": Date().timeIntervalSince1970,
                            "export_date": ISO8601DateFormatter().string(from: Date())
                        ]
                    }

        // Create JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: credentials, options: .prettyPrinted) else {
            isExporting = false
            return
        }

        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gopro_wifi_credentials")
            .appendingPathExtension("json")

        do {
            try jsonData.write(to: tempURL)
            credentialsFileURL = tempURL
            isExporting = false
            showingShareSheet = true
        } catch {
            ErrorHandler.error("Error writing credentials file: \(error)")
            isExporting = false
        }
    }
}

// Share sheet for AirDrop
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    WiFiCredentialExportView(bleManager: BLEManager())
}
