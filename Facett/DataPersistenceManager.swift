import Foundation
import os.log

/// Centralized data persistence manager for standardized storage patterns
class DataPersistenceManager {
    static let shared = DataPersistenceManager()

    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let logger = Logger(subsystem: "com.kmatzen.facett", category: "DataPersistence")

    // MARK: - Storage Types

    enum StorageType {
        case userDefaults    // For small, frequently accessed data
        case documents       // For larger data that needs file-based storage
        case cache          // For temporary data with expiration
    }

    enum StorageError: Error {
        case encodingFailed(String)
        case decodingFailed(String)
        case fileOperationFailed(String)
        case invalidData(String)

        var localizedDescription: String {
            switch self {
            case .encodingFailed(let message):
                return "Encoding failed: \(message)"
            case .decodingFailed(let message):
                return "Decoding failed: \(message)"
            case .fileOperationFailed(let message):
                return "File operation failed: \(message)"
            case .invalidData(let message):
                return "Invalid data: \(message)"
            }
        }
    }

    private init() {
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.documentsDirectory = documentsURL
        } else {
            self.documentsDirectory = fileManager.temporaryDirectory
            logger.error("Could not access documents directory, falling back to temporary directory")
        }

        // Create data directory if it doesn't exist
        let dataDirectory = documentsDirectory.appendingPathComponent("Data")
        if !fileManager.fileExists(atPath: dataDirectory.path) {
            try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - UserDefaults Storage

    /// Store data in UserDefaults (for small, frequently accessed data)
    func storeInUserDefaults<T: Codable>(_ value: T, forKey key: String) throws {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key)
            logger.debug("Stored data in UserDefaults for key: \(key)")
        } catch {
            logger.error("Failed to encode data for UserDefaults key '\(key)': \(error.localizedDescription)")
            throw StorageError.encodingFailed(error.localizedDescription)
        }
    }

    /// Retrieve data from UserDefaults
    func retrieveFromUserDefaults<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            let value = try JSONDecoder().decode(type, from: data)
            logger.debug("Retrieved data from UserDefaults for key: \(key)")
            return value
        } catch {
            logger.error("Failed to decode data from UserDefaults key '\(key)': \(error.localizedDescription)")
            throw StorageError.decodingFailed(error.localizedDescription)
        }
    }

    /// Store simple values in UserDefaults
    func storeSimpleValue<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
        logger.debug("Stored simple value in UserDefaults for key: \(key)")
    }

    /// Retrieve simple values from UserDefaults
    func retrieveSimpleValue<T>(_ type: T.Type, forKey key: String) -> T? {
        guard userDefaults.object(forKey: key) != nil else { return nil }
        if type == Bool.self {
            return userDefaults.bool(forKey: key) as? T
        }
        if type == Int.self {
            return userDefaults.integer(forKey: key) as? T
        }
        if type == Double.self {
            return userDefaults.double(forKey: key) as? T
        }
        if type == String.self {
            return userDefaults.string(forKey: key) as? T
        }
        return userDefaults.object(forKey: key) as? T
    }

    // MARK: - File-Based Storage

    /// Store data in Documents directory (for larger data)
    func storeInDocuments<T: Codable>(_ value: T, filename: String, subdirectory: String? = nil) throws {
        let directory = subdirectory != nil ?
            documentsDirectory.appendingPathComponent("Data").appendingPathComponent(subdirectory!) :
            documentsDirectory.appendingPathComponent("Data")

        // Create subdirectory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let fileURL = directory.appendingPathComponent(filename)

        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL)
            logger.debug("Stored data in documents: \(fileURL.lastPathComponent)")
        } catch {
            logger.error("Failed to store data in documents '\(filename)': \(error.localizedDescription)")
            throw StorageError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Retrieve data from Documents directory
    func retrieveFromDocuments<T: Codable>(_ type: T.Type, filename: String, subdirectory: String? = nil) throws -> T? {
        let directory = subdirectory != nil ?
            documentsDirectory.appendingPathComponent("Data").appendingPathComponent(subdirectory!) :
            documentsDirectory.appendingPathComponent("Data")

        let fileURL = directory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let value = try JSONDecoder().decode(type, from: data)
            logger.debug("Retrieved data from documents: \(fileURL.lastPathComponent)")
            return value
        } catch {
            logger.error("Failed to retrieve data from documents '\(filename)': \(error.localizedDescription)")
            throw StorageError.decodingFailed(error.localizedDescription)
        }
    }

    /// List files in a subdirectory
    func listFiles(in subdirectory: String? = nil) throws -> [String] {
        let directory = subdirectory != nil ?
            documentsDirectory.appendingPathComponent("Data").appendingPathComponent(subdirectory!) :
            documentsDirectory.appendingPathComponent("Data")

        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        do {
            let files = try fileManager.contentsOfDirectory(atPath: directory.path)
            return files.filter { !$0.hasPrefix(".") } // Filter out hidden files
        } catch {
            logger.error("Failed to list files in directory '\(directory.path)': \(error.localizedDescription)")
            throw StorageError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Delete file from Documents directory
    func deleteFile(filename: String, subdirectory: String? = nil) throws {
        let directory = subdirectory != nil ?
            documentsDirectory.appendingPathComponent("Data").appendingPathComponent(subdirectory!) :
            documentsDirectory.appendingPathComponent("Data")

        let fileURL = directory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // File doesn't exist, nothing to delete
        }

        do {
            try fileManager.removeItem(at: fileURL)
            logger.debug("Deleted file: \(fileURL.lastPathComponent)")
        } catch {
            logger.error("Failed to delete file '\(filename)': \(error.localizedDescription)")
            throw StorageError.fileOperationFailed(error.localizedDescription)
        }
    }

    // MARK: - Batch Operations

    /// Store multiple values in UserDefaults atomically
    func storeBatchInUserDefaults<T: Codable>(_ values: [String: T]) throws {
        var dataDict: [String: Data] = [:]

        for (key, value) in values {
            do {
                let data = try JSONEncoder().encode(value)
                dataDict[key] = data
            } catch {
                logger.error("Failed to encode data for batch key '\(key)': \(error.localizedDescription)")
                throw StorageError.encodingFailed("Failed to encode \(key): \(error.localizedDescription)")
            }
        }

        // Store all data atomically
        for (key, data) in dataDict {
            userDefaults.set(data, forKey: key)
        }

        logger.debug("Stored batch data in UserDefaults: \(values.keys.joined(separator: ", "))")
    }

    /// Retrieve multiple values from UserDefaults
    func retrieveBatchFromUserDefaults<T: Codable>(_ type: T.Type, forKeys keys: [String]) throws -> [String: T] {
        var result: [String: T] = [:]

        for key in keys {
            if let value: T = try retrieveFromUserDefaults(type, forKey: key) {
                result[key] = value
            }
        }

        logger.debug("Retrieved batch data from UserDefaults: \(result.keys.joined(separator: ", "))")
        return result
    }

    // MARK: - Migration Support

    /// Migrate data from one key to another
    func migrateUserDefaultsData<T: Codable>(_ type: T.Type, from oldKey: String, to newKey: String) throws {
        if let oldValue: T = try retrieveFromUserDefaults(type, forKey: oldKey) {
            try storeInUserDefaults(oldValue, forKey: newKey)
            userDefaults.removeObject(forKey: oldKey)
            logger.info("Migrated data from '\(oldKey)' to '\(newKey)'")
        }
    }

    /// Check if data exists for a key
    func dataExists(forKey key: String, storageType: StorageType = .userDefaults, subdirectory: String? = nil) -> Bool {
        switch storageType {
        case .userDefaults:
            return userDefaults.object(forKey: key) != nil
        case .documents:
            let directory = subdirectory != nil ?
                documentsDirectory.appendingPathComponent("Data").appendingPathComponent(subdirectory!) :
                documentsDirectory.appendingPathComponent("Data")
            let fileURL = directory.appendingPathComponent(key)
            return fileManager.fileExists(atPath: fileURL.path)
        case .cache:
            return false
        }
    }

    // MARK: - Cleanup

    /// Clean up old data files
    func cleanupOldFiles(olderThan days: Int = 30, in subdirectory: String? = nil) throws {
        let directory = subdirectory != nil ?
            documentsDirectory.appendingPathComponent("Data").appendingPathComponent(subdirectory!) :
            documentsDirectory.appendingPathComponent("Data")

        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))

        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])

            for fileURL in files {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date, creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    logger.debug("Cleaned up old file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            logger.error("Failed to cleanup old files: \(error.localizedDescription)")
            throw StorageError.fileOperationFailed(error.localizedDescription)
        }
    }

    // MARK: - Storage Statistics

    /// Get storage statistics
    func getStorageStats() -> StorageStats {
        var userDefaultsSize = 0
        var documentsSize = 0
        var fileCount = 0

        // Calculate UserDefaults size (approximate)
        let userDefaultsDict = userDefaults.dictionaryRepresentation()
        for (_, value) in userDefaultsDict {
            if let data = value as? Data {
                userDefaultsSize += data.count
            }
        }

        // Calculate Documents directory size
        let dataDirectory = documentsDirectory.appendingPathComponent("Data")
        if fileManager.fileExists(atPath: dataDirectory.path) {
            do {
                let files = try fileManager.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
                fileCount = files.count

                for fileURL in files {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    if let fileSize = attributes[.size] as? Int {
                        documentsSize += fileSize
                    }
                }
            } catch {
                logger.error("Failed to calculate documents size: \(error.localizedDescription)")
            }
        }

        return StorageStats(
            userDefaultsSize: userDefaultsSize,
            documentsSize: documentsSize,
            fileCount: fileCount
        )
    }
}

// MARK: - Supporting Types

struct StorageStats {
    let userDefaultsSize: Int
    let documentsSize: Int
    let fileCount: Int

    var totalSize: Int {
        return userDefaultsSize + documentsSize
    }

    var formattedUserDefaultsSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(userDefaultsSize), countStyle: .file)
    }

    var formattedDocumentsSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(documentsSize), countStyle: .file)
    }

    var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}
