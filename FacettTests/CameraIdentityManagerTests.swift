import XCTest
@testable import Facett

final class CameraIdentityManagerTests: XCTestCase {

    var manager: CameraIdentityManager!
    var testSerials: [String] = []

    override func setUp() {
        super.setUp()
        manager = CameraIdentityManager.shared
        testSerials = []
    }

    override func tearDown() {
        for serial in testSerials {
            manager.removeCameraName(forSerial: serial)
        }
        testSerials = []
        manager = nil
        super.tearDown()
    }

    private func uniqueSerial(_ suffix: String) -> String {
        let serial = "TEST-\(suffix)-\(UUID().uuidString.prefix(8))"
        testSerials.append(serial)
        return serial
    }

    func testGetCameraNameReturnsNilWhenNotStored() {
        let serial = uniqueSerial("unstored")
        XCTAssertNil(manager.getCameraName(forSerial: serial))
    }

    func testStoreAndGetCameraName() {
        let serial = uniqueSerial("store")
        manager.storeCameraName("My GoPro", forSerial: serial)
        XCTAssertEqual(manager.getCameraName(forSerial: serial), "My GoPro")
    }

    func testStoreCameraNameOverwritesPreviousValue() {
        let serial = uniqueSerial("overwrite")
        manager.storeCameraName("First Name", forSerial: serial)
        manager.storeCameraName("Second Name", forSerial: serial)
        XCTAssertEqual(manager.getCameraName(forSerial: serial), "Second Name")
    }

    func testRemoveCameraName() {
        let serial = uniqueSerial("remove")
        manager.storeCameraName("Temp Name", forSerial: serial)
        manager.removeCameraName(forSerial: serial)
        XCTAssertNil(manager.getCameraName(forSerial: serial))
    }

    func testGetAllCameraNamesIncludesStoredEntry() {
        let serial = uniqueSerial("all")
        manager.storeCameraName("Listed Camera", forSerial: serial)
        XCTAssertEqual(manager.getAllCameraNames()[serial], "Listed Camera")
    }

    func testGetDisplayNameForUUIDPrefersCurrentName() {
        let id = UUID()
        XCTAssertEqual(manager.getDisplayName(for: id, currentName: "Live Name"), "Live Name")
    }

    func testGetDisplayNameForUUIDFallsBackToShortId() {
        let id = UUID()
        let expected = "Camera \(String(id.uuidString.prefix(8)))"
        XCTAssertEqual(manager.getDisplayName(for: id, currentName: nil), expected)
    }

    func testGetDisplayNameForUUIDIgnoresEmptyCurrentName() {
        let id = UUID()
        let expected = "Camera \(String(id.uuidString.prefix(8)))"
        XCTAssertEqual(manager.getDisplayName(for: id, currentName: ""), expected)
    }

    func testGetDisplayNameForSerialStoresProvidedCurrentName() {
        let serial = uniqueSerial("displayStore")
        let result = manager.getDisplayName(forSerial: serial, currentName: "Fresh Name")
        XCTAssertEqual(result, "Fresh Name")
        XCTAssertEqual(manager.getCameraName(forSerial: serial), "Fresh Name")
    }

    func testGetDisplayNameForSerialUsesStoredNameWhenNoCurrentName() {
        let serial = uniqueSerial("displayStored")
        manager.storeCameraName("Previously Stored", forSerial: serial)
        XCTAssertEqual(manager.getDisplayName(forSerial: serial, currentName: nil), "Previously Stored")
    }

    func testGetDisplayNameForSerialFallsBackToSerialItself() {
        let serial = uniqueSerial("displayFallback")
        XCTAssertEqual(manager.getDisplayName(forSerial: serial, currentName: nil), serial)
    }
}

final class CameraSerialResolverTests: XCTestCase {

    var resolver: CameraSerialResolver!
    var testSerials: [String] = []

    override func setUp() {
        super.setUp()
        resolver = CameraSerialResolver.shared
        testSerials = []
    }

    override func tearDown() {
        for serial in testSerials {
            resolver.removeMapping(forSerial: serial)
        }
        testSerials = []
        resolver = nil
        super.tearDown()
    }

    private func uniqueSerial(_ suffix: String) -> String {
        let serial = "TEST-\(suffix)-\(UUID().uuidString.prefix(8))"
        testSerials.append(serial)
        return serial
    }

    func testGetUUIDReturnsNilWhenNotStored() {
        let serial = uniqueSerial("unstored")
        XCTAssertNil(resolver.getUUID(forSerial: serial))
    }

    func testStoreAndGetUUID() {
        let serial = uniqueSerial("store")
        let id = UUID()
        resolver.storeUUID(id, forSerial: serial)
        XCTAssertEqual(resolver.getUUID(forSerial: serial), id)
    }

    func testStoreUUIDUpdatesExistingMapping() {
        let serial = uniqueSerial("update")
        let first = UUID()
        let second = UUID()
        resolver.storeUUID(first, forSerial: serial)
        resolver.storeUUID(second, forSerial: serial)
        XCTAssertEqual(resolver.getUUID(forSerial: serial), second)
    }

    func testGetSerialPerformsReverseLookup() {
        let serial = uniqueSerial("reverse")
        let id = UUID()
        resolver.storeUUID(id, forSerial: serial)
        XCTAssertEqual(resolver.getSerial(forUUID: id), serial)
    }

    func testRemoveMappingClearsBothDirections() {
        let serial = uniqueSerial("removeMapping")
        let id = UUID()
        resolver.storeUUID(id, forSerial: serial)
        resolver.removeMapping(forSerial: serial)
        XCTAssertNil(resolver.getUUID(forSerial: serial))
        XCTAssertNil(resolver.getSerial(forUUID: id))
    }

    func testGetAllMappingsIncludesStoredEntry() {
        let serial = uniqueSerial("allMappings")
        let id = UUID()
        resolver.storeUUID(id, forSerial: serial)
        XCTAssertEqual(resolver.getAllMappings()[serial], id)
    }

    func testGetMappingStatsReflectsCount() {
        let serial = uniqueSerial("stats")
        let before = resolver.getMappingStats().totalMappings
        resolver.storeUUID(UUID(), forSerial: serial)
        let after = resolver.getMappingStats().totalMappings
        XCTAssertEqual(after, before + 1)
    }
}
