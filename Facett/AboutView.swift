import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.on.rectangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("Facett")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("About")) {
                    Text("""
                        Facett is a multi-camera control app that connects to action \
                        cameras over Bluetooth Low Energy. Manage camera groups, \
                        synchronize settings, and start or stop recording across \
                        multiple cameras simultaneously.
                        """)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Compatibility")) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GoPro\u{00AE} HERO10 Black")
                                .font(.subheadline)
                            Text("Tested with GoPro Labs firmware. Other models may work but are not officially supported.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GoPro Labs Firmware Required")
                                .font(.subheadline)
                            Text("Install GoPro Labs firmware on your cameras for full BLE connectivity.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }

                Section(header: Text("Legal")) {
                    Text("""
                        This product and/or service is not affiliated with, \
                        endorsed by or in any way associated with GoPro Inc. \
                        or its products and services. GoPro, HERO and their \
                        respective logos are trademarks or registered \
                        trademarks of GoPro, Inc.
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
