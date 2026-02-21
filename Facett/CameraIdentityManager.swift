import Foundation

// MARK: - Camera Identity Manager
class CameraIdentityManager: ObservableObject {
    static let shared = CameraIdentityManager()

    private let persistenceManager = DataPersistenceManager.shared
    private let cameraNamesKey = "CameraNames"

    @Published private var cameraNames: [String: String] = [:] // Serial number -> display name

    private init() {
        loadCameraNames()
    }

    // MARK: - Public Interface

    /// Get the stored name for a camera by serial number, or nil if not stored
    func getCameraName(forSerial serial: String) -> String? {
        return cameraNames[serial]
    }

    /// Store a camera name persistently by serial number
    func storeCameraName(_ name: String, forSerial serial: String) {
        // Only store if the name is different or doesn't exist
        if cameraNames[serial] != name {
            cameraNames[serial] = name
            saveCameraNames()
            ErrorHandler.info("📝 Stored camera name '\(name)' for camera \(serial)")
        }
    }

    /// Get a display name for a camera, with fallback logic
    /// Uses UUID for backward compatibility during runtime lookups
    func getDisplayName(for cameraId: UUID, currentName: String? = nil) -> String {
        // If we have a current name from the peripheral, use it directly
        if let currentName = currentName, !currentName.isEmpty {
            return currentName
        }

        // Fallback to a generic name with the camera ID
        return "Camera \(String(cameraId.uuidString.prefix(8)))"
    }

    /// Get a display name for a camera by serial number
    func getDisplayName(forSerial serial: String, currentName: String? = nil) -> String {
        // If we have a current name from the peripheral, use it and store it
        if let currentName = currentName, !currentName.isEmpty {
            storeCameraName(currentName, forSerial: serial)
            return currentName
        }

        // If we have a stored name, use it
        if let storedName = cameraNames[serial] {
            return storedName
        }

        // Fallback to the serial number
        return serial
    }

    /// Remove a stored camera name (useful for cleanup)
    func removeCameraName(forSerial serial: String) {
        cameraNames.removeValue(forKey: serial)
        saveCameraNames()
        ErrorHandler.info("🗑️ Removed stored name for camera \(serial)")
    }

    /// Get all stored camera names
    func getAllCameraNames() -> [String: String] {
        return cameraNames
    }

    // MARK: - Private Methods

    private func loadCameraNames() {
        do {
            if let stringDict: [String: String] = try persistenceManager.retrieveFromUserDefaults([String: String].self, forKey: cameraNamesKey) {
                // Already in the correct format (serial -> name)
                cameraNames = stringDict
                ErrorHandler.info("Loaded \(cameraNames.count) stored camera names")
            }
        } catch {
            ErrorHandler.error("Failed to load camera names", error: error)
            // Fall back to empty dictionary
            cameraNames = [:]
        }
    }

    private func saveCameraNames() {
        do {
            // Already in the correct format (serial -> name)
            try persistenceManager.storeInUserDefaults(cameraNames, forKey: cameraNamesKey)
        } catch {
            ErrorHandler.error("Failed to save camera names", error: error)
        }
    }
}

// MARK: - Camera Serial Resolver
class CameraSerialResolver {
    static let shared = CameraSerialResolver()

    private let persistenceManager = DataPersistenceManager.shared
    private let serialToUUIDKey = "CameraSerialToUUID"

    // Serial number -> most recent UUID mapping
    private var serialToUUID: [String: UUID] = [:]

    private init() {
        loadMappings()
    }

    // MARK: - Public Interface

    /// Get the most recent UUID for a camera serial number
    func getUUID(forSerial serial: String) -> UUID? {
        return serialToUUID[serial]
    }

    /// Store or update the UUID for a camera serial number
    func storeUUID(_ uuid: UUID, forSerial serial: String) {
        // Only update if the UUID has changed or doesn't exist
        if serialToUUID[serial] != uuid {
            serialToUUID[serial] = uuid
            saveMappings()
            ErrorHandler.info("📍 Updated UUID mapping for camera \(serial) to \(uuid.uuidString.prefix(8))...")
        }
    }

    /// Get the serial number for a given UUID (reverse lookup)
    func getSerial(forUUID uuid: UUID) -> String? {
        return serialToUUID.first(where: { $0.value == uuid })?.key
    }

    /// Remove a serial number mapping (useful for cleanup)
    func removeMapping(forSerial serial: String) {
        serialToUUID.removeValue(forKey: serial)
        saveMappings()
        ErrorHandler.info("🗑️ Removed UUID mapping for camera \(serial)")
    }

    /// Get all serial -> UUID mappings
    func getAllMappings() -> [String: UUID] {
        return serialToUUID
    }

    /// Get statistics about stored mappings
    func getMappingStats() -> (totalMappings: Int, oldestMapping: Date?, newestMapping: Date?) {
        return (totalMappings: serialToUUID.count, oldestMapping: nil, newestMapping: nil)
    }

    // MARK: - Private Methods

    private func loadMappings() {
        do {
            if let stringDict: [String: String] = try persistenceManager.retrieveFromUserDefaults([String: String].self, forKey: serialToUUIDKey) {
                // Convert string UUIDs back to UUID objects
                serialToUUID = stringDict.compactMapValues { UUID(uuidString: $0) }
                ErrorHandler.info("Loaded \(serialToUUID.count) serial → UUID mappings")
            }
        } catch {
            ErrorHandler.error("Failed to load serial number mappings", error: error)
            // Fall back to empty dictionary
            serialToUUID = [:]
        }
    }

    private func saveMappings() {
        do {
            // Convert UUIDs to strings for UserDefaults storage
            let stringDict = serialToUUID.mapValues { $0.uuidString }
            try persistenceManager.storeInUserDefaults(stringDict, forKey: serialToUUIDKey)
        } catch {
            ErrorHandler.error("Failed to save serial number mappings", error: error)
        }
    }
}
