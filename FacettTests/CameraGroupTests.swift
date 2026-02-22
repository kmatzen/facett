import XCTest
@testable import Facett

final class CameraGroupTests: XCTestCase {

    var configManager: ConfigManager!
    var groupManager: CameraGroupManager!

    override func setUp() {
        super.setUp()
        configManager = ConfigManager()
        groupManager = CameraGroupManager(configManager: configManager)
        groupManager.cameraGroups.removeAll()
    }

    override func tearDown() {
        groupManager = nil
        configManager = nil
        super.tearDown()
    }

    // MARK: - CameraGroup Model

    func testCameraGroupInit() {
        let group = CameraGroup(name: "Test Group")
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertTrue(group.cameraSerials.isEmpty)
        XCTAssertFalse(group.isActive)
        XCTAssertNil(group.configId)
    }

    func testCameraGroupInitWithSerials() {
        let group = CameraGroup(name: "Group", cameraSerials: ["GP001", "GP002"])
        XCTAssertEqual(group.cameraSerials.count, 2)
        XCTAssertTrue(group.cameraSerials.contains("GP001"))
    }

    func testCameraGroupCodable() throws {
        let original = CameraGroup(name: "Codable Test", cameraSerials: ["S1", "S2"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CameraGroup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.cameraSerials, original.cameraSerials)
    }

    // MARK: - Add Group

    func testAddCameraGroup() {
        groupManager.addCameraGroup(name: "Alpha")

        XCTAssertEqual(groupManager.cameraGroups.count, 1)
        XCTAssertEqual(groupManager.cameraGroups.first?.name, "Alpha")
    }

    func testAddFirstGroupAutoSelectsActive() {
        groupManager.addCameraGroup(name: "First")

        XCTAssertNotNil(groupManager.activeGroupId)
        XCTAssertEqual(groupManager.activeGroupId, groupManager.cameraGroups.first?.id)
    }

    func testAddSecondGroupDoesNotChangeActive() {
        groupManager.addCameraGroup(name: "First")
        let firstId = groupManager.activeGroupId

        groupManager.addCameraGroup(name: "Second")

        XCTAssertEqual(groupManager.activeGroupId, firstId)
    }

    // MARK: - Remove Group

    func testRemoveCameraGroup() {
        groupManager.addCameraGroup(name: "ToRemove")
        let group = groupManager.cameraGroups.first!

        groupManager.removeCameraGroup(group)

        XCTAssertTrue(groupManager.cameraGroups.isEmpty)
    }

    func testRemoveActiveGroupSelectsAnother() {
        groupManager.addCameraGroup(name: "First")
        groupManager.addCameraGroup(name: "Second")
        let first = groupManager.cameraGroups[0]

        groupManager.setActiveGroup(first)
        groupManager.removeCameraGroup(first)

        XCTAssertEqual(groupManager.cameraGroups.count, 1)
        XCTAssertEqual(groupManager.activeGroupId, groupManager.cameraGroups.first?.id)
    }

    // MARK: - Active Group

    func testSetActiveGroup() {
        groupManager.addCameraGroup(name: "A")
        groupManager.addCameraGroup(name: "B")
        let groupB = groupManager.cameraGroups[1]

        groupManager.setActiveGroup(groupB)

        XCTAssertEqual(groupManager.activeGroupId, groupB.id)
        XCTAssertEqual(groupManager.activeGroup?.name, "B")
    }

    func testSetActiveGroupNil() {
        groupManager.addCameraGroup(name: "A")
        groupManager.setActiveGroup(nil)

        XCTAssertNil(groupManager.activeGroupId)
        XCTAssertNil(groupManager.activeGroup)
    }

    // MARK: - Camera Management

    func testAddCameraToGroup() {
        groupManager.addCameraGroup(name: "Test")
        let group = groupManager.cameraGroups.first!

        groupManager.addCameraToGroup("GP12345", group: group)

        let updated = groupManager.cameraGroups.first!
        XCTAssertTrue(updated.cameraSerials.contains("GP12345"))
    }

    func testRemoveCameraFromGroup() {
        groupManager.addCameraGroup(name: "Test")
        var group = groupManager.cameraGroups.first!
        groupManager.addCameraToGroup("GP12345", group: group)

        group = groupManager.cameraGroups.first!
        groupManager.removeCameraFromGroup("GP12345", group: group)

        let updated = groupManager.cameraGroups.first!
        XCTAssertFalse(updated.cameraSerials.contains("GP12345"))
    }

    func testAddDuplicateCameraIsIdempotent() {
        groupManager.addCameraGroup(name: "Test")
        let group = groupManager.cameraGroups.first!

        groupManager.addCameraToGroup("GP001", group: group)
        let afterFirst = groupManager.cameraGroups.first!
        groupManager.addCameraToGroup("GP001", group: afterFirst)

        let updated = groupManager.cameraGroups.first!
        XCTAssertEqual(updated.cameraSerials.count, 1)
    }

    // MARK: - Update Group

    func testUpdateCameraGroup() {
        groupManager.addCameraGroup(name: "Original")
        var group = groupManager.cameraGroups.first!
        group.name = "Updated"

        groupManager.updateCameraGroup(group)

        XCTAssertEqual(groupManager.cameraGroups.first?.name, "Updated")
    }

    // MARK: - CameraStatus

    func testCameraStatusRawValues() {
        XCTAssertEqual(CameraStatus.ready.rawValue, "Ready")
        XCTAssertEqual(CameraStatus.error.rawValue, "Error")
        XCTAssertEqual(CameraStatus.disconnected.rawValue, "Disconnected")
    }
}
