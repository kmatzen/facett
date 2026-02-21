import Foundation
import SwiftUI

// MARK: - Configuration Manager
class ConfigManager: ObservableObject {
    @Published var configs: [CameraConfig] = []
    @Published var selectedConfigId: UUID?
    @Published var autoSyncEnabled: Bool = false
    @Published var isAutoSyncing: Bool = false
    private var syncInProgress: Bool = false // Internal sync state tracking
    private let syncQueue = DispatchQueue(label: "com.gopro.sync", qos: .userInitiated)

    private let userDefaults = UserDefaults.standard
    private let configsKey = "CameraConfigs"
    private let selectedConfigKey = "SelectedConfigId"
    private let autoSyncKey = "AutoSyncEnabled"

    init() {
        loadConfigs()
        loadAutoSyncSetting()
        if configs.isEmpty {
            createDefaultConfigs()
        }
    }

    // MARK: - Centralized Target Settings Logic
    /// Get the target settings that should be applied to cameras
    /// Priority: 1. Globally selected config, 2. Group-specific config, 3. Default config
    func getTargetSettings(for cameraGroup: CameraGroup? = nil) -> GoProSettings {
        // 1. Check globally selected config first
        if let selectedConfig = getSelectedConfig() {
            return selectedConfig.settings.toGoProSettings()
        }

        // 2. Check group-specific config
        if let cameraGroup = cameraGroup,
           let configId = cameraGroup.configId,
           let config = configs.first(where: { $0.id == configId }) {
            return config.settings.toGoProSettings()
        }

        // 3. Fall back to default config
        if let defaultConfig = getDefaultConfig() {
            return defaultConfig.settings.toGoProSettings()
        }

        // 4. Final fallback - this should never happen if createDefaultConfigs() works
        ErrorHandler.warning("No default config found, using hardcoded defaults")
        return GoProSettingsData.defaultSettings().toGoProSettings()
    }

    // MARK: - Default Configurations
    private func createDefaultConfigs() {
        configs = DefaultConfigurations.createDefaultConfigs()
        selectedConfigId = configs.first?.id
        saveConfigs()
    }

    // MARK: - Configuration Management
    func addConfig(_ config: CameraConfig) {
        configs.append(config)
        saveConfigs()
    }

    func updateConfig(_ config: CameraConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            saveConfigs()
        }
    }

    func deleteConfig(_ configId: UUID) {
        configs.removeAll { $0.id == configId }
        if selectedConfigId == configId {
            selectedConfigId = configs.first?.id
        }
        saveConfigs()
    }

    func duplicateConfig(_ configId: UUID) -> CameraConfig? {
        guard let originalConfig = configs.first(where: { $0.id == configId }) else { return nil }

        var duplicatedConfig = CameraConfig(
            name: "\(originalConfig.name) (Copy)",
            description: originalConfig.description,
            isDefault: false
        )
        duplicatedConfig.settings = originalConfig.settings

        addConfig(duplicatedConfig)
        return duplicatedConfig
    }

    func setDefaultConfig(_ configId: UUID) {
        // Remove default from all configs
        for i in 0..<configs.count {
            configs[i].isDefault = false
        }

        // Set new default
        if let index = configs.firstIndex(where: { $0.id == configId }) {
            configs[index].isDefault = true
        }

        saveConfigs()
    }

    func selectConfig(_ configId: UUID) {
        selectedConfigId = configId
        userDefaults.set(configId.uuidString, forKey: selectedConfigKey)
    }

    func selectConfigAndSync(_ configId: UUID, bleManager: BLEManager, cameraGroupManager: CameraGroupManager) {
        selectConfig(configId)
        checkAndTriggerAutoSync(bleManager: bleManager, cameraGroupManager: cameraGroupManager)
    }

    func getSelectedConfig() -> CameraConfig? {
        return configs.first { $0.id == selectedConfigId }
    }

    func getDefaultConfig() -> CameraConfig? {
        return configs.first { $0.isDefault }
    }

    // MARK: - Settings Validation
    func validateCurrentConfig() -> (isValid: Bool, warnings: [String], errors: [String]) {
        return ConfigValidation.validateCurrentConfig(self)
    }

    func validateConfig(_ config: CameraConfig) -> (isValid: Bool, warnings: [String], errors: [String]) {
        return ConfigValidation.validateConfig(config)
    }

    // MARK: - Persistence
    private func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(configs) {
            userDefaults.set(encoded, forKey: configsKey)
        }
    }

    private func loadConfigs() {
        if let data = userDefaults.data(forKey: configsKey),
           let decoded = try? JSONDecoder().decode([CameraConfig].self, from: data) {
            configs = decoded
        }

        if let selectedIdString = userDefaults.string(forKey: selectedConfigKey),
           let selectedId = UUID(uuidString: selectedIdString) {
            selectedConfigId = selectedId
        } else {
            selectedConfigId = configs.first?.id
        }
    }

    private func loadAutoSyncSetting() {
        autoSyncEnabled = userDefaults.bool(forKey: autoSyncKey)
    }

    func saveAutoSyncSetting() {
        userDefaults.set(autoSyncEnabled, forKey: autoSyncKey)
    }

    // MARK: - Auto-Sync
    func checkAndTriggerAutoSync(bleManager: BLEManager, cameraGroupManager: CameraGroupManager) {
        guard autoSyncEnabled else { return }

        // Use sync queue to prevent multiple sync operations from running simultaneously
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // Check if sync is already in progress
            if self.syncInProgress {
                ErrorHandler.debug("🔄 Auto-sync: Skipping - sync already in progress")
                return
            }

            // Set sync in progress flag
            self.syncInProgress = true

            // Run sync logic on main queue for UI updates
            DispatchQueue.main.async {
                self.performAutoSync(bleManager: bleManager, cameraGroupManager: cameraGroupManager)
            }
        }
    }

    private func performAutoSync(bleManager: BLEManager, cameraGroupManager: CameraGroupManager) {
        // Get target settings using centralized logic
        let targetSettings = getTargetSettings(for: cameraGroupManager.activeGroup)
        let configName = getSelectedConfig()?.name ?? getDefaultConfig()?.name ?? "Default"

        ErrorHandler.info("🎯 Auto-sync using config: '\(configName)' (FPS: \(targetSettings.framesPerSecond))")

        // Check if any connected cameras have mismatched settings
        var mismatchedCameras: [String] = []
        for (_, gopro) in bleManager.connectedGoPros {
            ErrorHandler.debug("🔍 Auto-sync checking camera '\(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.name))'")
            ErrorHandler.debug("   Camera FPS: \(gopro.settings.framesPerSecond)")
            ErrorHandler.debug("   Target FPS: \(targetSettings.framesPerSecond)")

            // Skip settings mismatch checks for recording cameras to avoid false positives
            if gopro.status.isEncoding == true {
                ErrorHandler.debug("   Skipping settings check for recording camera")
                continue
            }

            if ConfigValidation.hasSettingsMismatch(gopro: gopro, targetSettings: targetSettings) {
                mismatchedCameras.append(CameraIdentityManager.shared.getDisplayName(for: gopro.peripheral.identifier, currentName: gopro.name))
            }
        }

        // If mismatches found, trigger sync
        if !mismatchedCameras.isEmpty {
            ErrorHandler.info("🔄 Auto-sync: Syncing \(mismatchedCameras.count) camera(s) to '\(configName)' config")
            ErrorHandler.info("   Cameras: \(mismatchedCameras.joined(separator: ", "))")

            // Set visual indicator
            self.isAutoSyncing = true

            if let activeGroup = cameraGroupManager.activeGroup {
                bleManager.sendSettingsToCamerasInGroup(activeGroup.cameraSerials, configManager: self, cameraGroupManager: cameraGroupManager)
            }

            // Clear visual indicator and sync state after settings are sent
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                self.isAutoSyncing = false
                self.syncInProgress = false
            }
        } else {
            ErrorHandler.info("✅ Auto-sync: All cameras match target settings")
            // Ensure sync indicator and state are cleared when no mismatches exist
            self.isAutoSyncing = false
            self.syncInProgress = false
        }
    }
}
