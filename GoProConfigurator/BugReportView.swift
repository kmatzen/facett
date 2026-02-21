import SwiftUI

struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var severity: BugSeverity = .medium
    @State private var category: BugCategory = .general
    @State private var userSteps = ""
    @State private var expectedBehavior = ""
    @State private var actualBehavior = ""
    @State private var includeDeviceInfo = true
    @State private var includeLogs = true
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bug Details")) {
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Picker("Severity", selection: $severity) {
                        ForEach(BugSeverity.allCases, id: \.self) { severity in
                            Text(severity.rawValue).tag(severity)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Picker("Category", selection: $category) {
                        ForEach(BugCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                Section(header: Text("Steps to Reproduce")) {
                    TextEditor(text: $userSteps)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                Section(header: Text("Expected vs Actual Behavior")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Behavior:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $expectedBehavior)
                            .frame(minHeight: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actual Behavior:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $actualBehavior)
                            .frame(minHeight: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                Section(header: Text("Additional Information")) {
                    Toggle("Include Device Information", isOn: $includeDeviceInfo)
                    Toggle("Include Recent Logs", isOn: $includeLogs)
                }

                Section {
                    Button(action: submitBugReport) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Bug Report")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Report Bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Bug Report Submitted", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your feedback! We'll review your report and get back to you if needed.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitBugReport() {
        guard !title.isEmpty && !description.isEmpty else {
            errorMessage = "Please fill in the title and description."
            showErrorAlert = true
            return
        }

        isSubmitting = true

        // Add device info if requested
        var additionalInfo: [String: String] = [:]
        if includeDeviceInfo {
            let device = UIDevice.current
            additionalInfo["Device Model"] = device.model
            additionalInfo["iOS Version"] = device.systemVersion
            additionalInfo["App Version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        }

        // Submit the bug report
        CrashReporter.shared.reportBug(
            title: title,
            description: description,
            severity: severity,
            category: category,
            userSteps: userSteps.isEmpty ? nil : userSteps,
            expectedBehavior: expectedBehavior.isEmpty ? nil : expectedBehavior,
            actualBehavior: actualBehavior.isEmpty ? nil : actualBehavior,
            additionalInfo: additionalInfo
        )

        // Simulate network delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            showSuccessAlert = true
        }
    }
}

struct BugReportListView: View {
    @State private var bugReports: [BugReport] = []
    @State private var showingBugReportForm = false

    var body: some View {
        NavigationView {
            List {
                if bugReports.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("No Bug Reports")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Bug reports you submit will appear here. You can also view them in TestFlight.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(bugReports, id: \.timestamp) { report in
                        BugReportRow(report: report)
                    }
                }
            }
            .navigationTitle("Bug Reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Report") {
                        showingBugReportForm = true
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        CrashReporter.shared.clearAllReports()
                        loadBugReports()
                    }
                    .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingBugReportForm) {
                BugReportView()
            }
            .onAppear {
                loadBugReports()
            }
        }
    }

    private func loadBugReports() {
        bugReports = CrashReporter.shared.getBugReports()
    }
}

struct BugReportRow: View {
    let report: BugReport
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title)
                        .font(.headline)
                        .lineLimit(isExpanded ? nil : 2)

                    HStack {
                        Label(report.severity.rawValue, systemImage: severityIcon)
                            .font(.caption)
                            .foregroundColor(severityColor)

                        Label(report.category.rawValue, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.description)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let userSteps = report.userSteps, !userSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Steps to Reproduce:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(userSteps)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let expected = report.expectedBehavior, !expected.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expected Behavior:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(expected)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    if let actual = report.actualBehavior, !actual.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Actual Behavior:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(actual)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Text("Reported: \(report.timestamp, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        switch report.severity {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "xmark.octagon"
        }
    }

    private var severityColor: Color {
        switch report.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

#Preview {
    BugReportView()
}
