import Foundation
import UIKit
import os.log

/// Comprehensive crash and bug reporting system
class CrashReporter: NSObject {
    static let shared = CrashReporter()

    private let logger = Logger(subsystem: "com.matzen.facett", category: "CrashReporter")
    private var crashLogs: [CrashLog] = []
    private var bugReports: [BugReport] = []

    // File paths for storing reports
    private var crashLogsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("crash_logs.json")
    }

    private var bugReportsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("bug_reports.json")
    }

    override init() {
        super.init()
        setupCrashHandling()
        loadExistingReports()
    }

    // MARK: - Crash Handling

    private func setupCrashHandling() {
        // Set up signal handlers for crashes
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleCrash(signal: signal, name: "SIGABRT")
        }
        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleCrash(signal: signal, name: "SIGSEGV")
        }
        signal(SIGBUS) { signal in
            CrashReporter.shared.handleCrash(signal: signal, name: "SIGBUS")
        }
        signal(SIGILL) { signal in
            CrashReporter.shared.handleCrash(signal: signal, name: "SIGILL")
        }

        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }

        logger.info("Crash handling setup complete")
    }

    private func handleCrash(signal: Int32, name: String) {
        let crashLog = CrashLog(
            timestamp: Date(),
            type: .signal,
            signal: signal,
            signalName: name,
            exceptionName: nil,
            exceptionReason: nil,
            threadStack: Thread.callStackSymbols,
            deviceInfo: getDeviceInfo(),
            appInfo: getAppInfo()
        )

        saveCrashLog(crashLog)
        logger.error("Crash detected: \(name) (signal \(signal))")

        // Exit gracefully
        exit(signal)
    }

    private func handleException(_ exception: NSException) {
        let crashLog = CrashLog(
            timestamp: Date(),
            type: .exception,
            signal: nil,
            signalName: nil,
            exceptionName: exception.name.rawValue,
            exceptionReason: exception.reason,
            threadStack: Thread.callStackSymbols,
            deviceInfo: getDeviceInfo(),
            appInfo: getAppInfo()
        )

        saveCrashLog(crashLog)
        logger.error("Exception detected: \(exception.name.rawValue) - \(exception.reason ?? "No reason")")
    }

    // MARK: - Bug Reporting

    func reportBug(
        title: String,
        description: String,
        severity: BugSeverity = .medium,
        category: BugCategory = .general,
        userSteps: String? = nil,
        expectedBehavior: String? = nil,
        actualBehavior: String? = nil,
        additionalInfo: [String: String] = [:]
    ) {
        let bugReport = BugReport(
            timestamp: Date(),
            title: title,
            description: description,
            severity: severity,
            category: category,
            userSteps: userSteps,
            expectedBehavior: expectedBehavior,
            actualBehavior: actualBehavior,
            additionalInfo: additionalInfo,
            deviceInfo: getDeviceInfo(),
            appInfo: getAppInfo()
        )

        saveBugReport(bugReport)
        logger.info("Bug report created: \(title)")

        // If TestFlight is available, we could send this to a server
        if isTestFlightBuild() {
            // In a real implementation, you'd send this to your backend
            logger.info("TestFlight build detected - bug report ready for upload")
        }
    }

    // MARK: - Logging

    func logError(_ message: String, error: Error? = nil, context: [String: Any] = [:], appStateContext: AppStateContext? = nil) {
        let errorLog = ErrorLog(
            timestamp: Date(),
            message: message,
            error: error?.localizedDescription,
            context: context,
            threadStack: Thread.callStackSymbols,
            deviceInfo: getDeviceInfo(),
            appInfo: getAppInfo(appStateContext: appStateContext)
        )

        saveErrorLog(errorLog)
        logger.error("Error logged: \(message)")
    }

    func logWarning(_ message: String, context: [String: Any] = [:], appStateContext: AppStateContext? = nil) {
        let warningLog = WarningLog(
            timestamp: Date(),
            message: message,
            context: context,
            deviceInfo: getDeviceInfo(),
            appInfo: getAppInfo(appStateContext: appStateContext)
        )

        saveWarningLog(warningLog)
        logger.warning("Warning logged: \(message)")
    }

    // MARK: - Data Management

    private func saveCrashLog(_ crashLog: CrashLog) {
        crashLogs.append(crashLog)
        saveCrashLogs()
    }

    private func saveBugReport(_ bugReport: BugReport) {
        bugReports.append(bugReport)
        saveBugReports()
    }

    private func saveErrorLog(_ errorLog: ErrorLog) {
        // Save to file system
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(errorLog) {
            let filename = "error_\(Date().timeIntervalSince1970).json"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent(filename)

            try? data.write(to: fileURL)
        }
    }

    private func saveWarningLog(_ warningLog: WarningLog) {
        // Save to file system
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(warningLog) {
            let filename = "warning_\(Date().timeIntervalSince1970).json"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent(filename)

            try? data.write(to: fileURL)
        }
    }

    private func saveCrashLogs() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(crashLogs) {
            try? data.write(to: crashLogsPath)
        }
    }

    private func saveBugReports() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(bugReports) {
            try? data.write(to: bugReportsPath)
        }
    }

    private func loadExistingReports() {
        // Load crash logs
        if let data = try? Data(contentsOf: crashLogsPath),
           let logs = try? JSONDecoder().decode([CrashLog].self, from: data) {
            crashLogs = logs
        }

        // Load bug reports
        if let data = try? Data(contentsOf: bugReportsPath),
           let reports = try? JSONDecoder().decode([BugReport].self, from: data) {
            bugReports = reports
        }
    }

    // MARK: - Report Access

    func getAllReports() -> (crashLogs: [CrashLog], bugReports: [BugReport]) {
        return (crashLogs, bugReports)
    }

    func getCrashLogs() -> [CrashLog] {
        return crashLogs
    }

    func getBugReports() -> [BugReport] {
        return bugReports
    }

    func clearAllReports() {
        crashLogs.removeAll()
        bugReports.removeAll()
        saveCrashLogs()
        saveBugReports()

        // Clear individual log files
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let files = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)

        files?.forEach { file in
            if file.lastPathComponent.hasPrefix("error_") || file.lastPathComponent.hasPrefix("warning_") {
                try? FileManager.default.removeItem(at: file)
            }
        }

        logger.info("All reports cleared")
    }

    // MARK: - Utility Methods

    private func getDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        return DeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            identifierForVendor: device.identifierForVendor?.uuidString,
            totalDiskSpace: getTotalDiskSpace(),
            freeDiskSpace: getFreeDiskSpace(),
            memoryUsage: getMemoryUsage(),
            bluetoothState: getBluetoothState(),
            networkReachability: getNetworkReachability(),
            batteryLevel: device.batteryLevel >= 0 ? device.batteryLevel : nil,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    private func getAppInfo(appStateContext: AppStateContext? = nil) -> AppInfo {
        let bundle = Bundle.main
        return AppInfo(
            version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "Unknown",
            isTestFlight: isTestFlightBuild(),
            appState: appStateContext?.appState ?? getCurrentAppState(),
            backgroundTimeRemaining: appStateContext?.backgroundTimeRemaining ?? getBackgroundTimeRemaining(),
            connectedCameras: appStateContext?.connectedCameras,
            discoveredCameras: appStateContext?.discoveredCameras,
            activeGroup: appStateContext?.activeGroup
        )
    }

    private func isTestFlightBuild() -> Bool {
        // Check if running from TestFlight
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    private func getTotalDiskSpace() -> Int64 {
        let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return fileSystemAttributes?[.systemSize] as? Int64 ?? 0
    }

    private func getFreeDiskSpace() -> Int64 {
        let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return fileSystemAttributes?[.systemFreeSize] as? Int64 ?? 0
    }

    private func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return MemoryUsage(
                residentSize: Int64(info.resident_size),
                virtualSize: Int64(info.virtual_size)
            )
        } else {
            return MemoryUsage(residentSize: 0, virtualSize: 0)
        }
    }

    private func getBluetoothState() -> String? {
        // Note: This would require CoreBluetooth framework access
        // For now, return nil as we can't access CBCentralManager state from here
        return nil
    }

    private func getNetworkReachability() -> String? {
        // Note: This would require Network framework access
        // For now, return nil as we can't access network state from here
        return nil
    }

    private func getCurrentAppState() -> String? {
        switch UIApplication.shared.applicationState {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }

    private func getBackgroundTimeRemaining() -> TimeInterval? {
        return UIApplication.shared.backgroundTimeRemaining
    }
}

// MARK: - Data Models

struct CrashLog: Codable {
    let timestamp: Date
    let type: CrashType
    let signal: Int32?
    let signalName: String?
    let exceptionName: String?
    let exceptionReason: String?
    let threadStack: [String]
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo

    init(timestamp: Date, type: CrashType, signal: Int32?, signalName: String?, exceptionName: String?, exceptionReason: String?, threadStack: [String], deviceInfo: DeviceInfo, appInfo: AppInfo) {
        self.timestamp = timestamp
        self.type = type
        self.signal = signal
        self.signalName = signalName
        self.exceptionName = exceptionName
        self.exceptionReason = exceptionReason
        self.threadStack = threadStack
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
    }
}

enum CrashType: String, Codable {
    case signal
    case exception
}

struct BugReport: Codable {
    let timestamp: Date
    let title: String
    let description: String
    let severity: BugSeverity
    let category: BugCategory
    let userSteps: String?
    let expectedBehavior: String?
    let actualBehavior: String?
    let additionalInfo: [String: String]
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
}

enum BugSeverity: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

enum BugCategory: String, Codable, CaseIterable {
    case general = "General"
    case ui = "UI/UX"
    case bluetooth = "Bluetooth"
    case camera = "Camera"
    case recording = "Recording"
    case settings = "Settings"
    case performance = "Performance"
    case crash = "Crash"
}

struct ErrorLog: Codable {
    let timestamp: Date
    let message: String
    let error: String?
    let context: [String: String] // Changed from [String: Any] to [String: String]
    let threadStack: [String]
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo

    init(timestamp: Date, message: String, error: String?, context: [String: Any], threadStack: [String], deviceInfo: DeviceInfo, appInfo: AppInfo) {
        self.timestamp = timestamp
        self.message = message
        self.error = error
        // Convert [String: Any] to [String: String] for encoding
        self.context = context.mapValues { String(describing: $0) }
        self.threadStack = threadStack
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
    }
}

struct WarningLog: Codable {
    let timestamp: Date
    let message: String
    let context: [String: String] // Changed from [String: Any] to [String: String]
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo

    init(timestamp: Date, message: String, context: [String: Any], deviceInfo: DeviceInfo, appInfo: AppInfo) {
        self.timestamp = timestamp
        self.message = message
        // Convert [String: Any] to [String: String] for encoding
        self.context = context.mapValues { String(describing: $0) }
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
    }
}

struct DeviceInfo: Codable {
    let model: String
    let systemName: String
    let systemVersion: String
    let identifierForVendor: String?
    let totalDiskSpace: Int64
    let freeDiskSpace: Int64
    let memoryUsage: MemoryUsage
    let bluetoothState: String?
    let networkReachability: String?
    let batteryLevel: Float?
    let isLowPowerMode: Bool?
}

struct AppInfo: Codable {
    let version: String
    let build: String
    let bundleIdentifier: String
    let isTestFlight: Bool
    let appState: String?
    let backgroundTimeRemaining: TimeInterval?
    let connectedCameras: Int?
    let discoveredCameras: Int?
    let activeGroup: String?
}

struct MemoryUsage: Codable {
    let residentSize: Int64
    let virtualSize: Int64
}

struct AppStateContext {
    let connectedCameras: Int?
    let discoveredCameras: Int?
    let activeGroup: String?
    let appState: String?
    let backgroundTimeRemaining: TimeInterval?
}
