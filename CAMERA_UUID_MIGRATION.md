# Camera Serial Number Identification

## Overview

This feature uses the camera's WiFi AP SSID (serial number) as the primary stable identifier for cameras in camera groups. This ensures cameras maintain their group associations even when iOS assigns new peripheral UUIDs after connection resets.

## Problem

When you reset Bluetooth connections, iOS CoreBluetooth may assign a new `peripheral.identifier` (UUID) to the same physical camera. This previously caused the app to treat it as a "new" camera, breaking the association with camera groups.

## Solution

The solution uses serial numbers (from AP SSID) as the primary stable identifier:

1. **Serial Numbers as Keys**: Camera groups store serial numbers instead of UUIDs
2. **Runtime UUID Lookup**: At runtime, look up which UUID currently corresponds to each serial number
3. **Display Name Consistency**: Display names still come from `peripheral.name` as before
4. **Automatic Association**: When a camera connects with a new UUID, it automatically appears in the correct groups based on its serial number

## Implementation

### Modified: `CameraGroup`

**Data Model** (line ~5):
- Changed from `cameraIds: Set<UUID>` to `cameraSerials: Set<String>`
- Camera groups now store serial numbers as the stable identifier

### Modified: `CameraNameManager`

**Serial-Based Storage** (line ~10):
- Changed from `[UUID: String]` to `[String: String]` (serial → name)
- Provides both UUID-based and serial-based lookup methods for compatibility
- Stores display names keyed by serial number for persistence

### Component: `CameraSerialNumberManager`

Located at: `GoProConfigurator/GoProConfigurator/CameraSerialNumberManager.swift`

**Key Features:**
- Maintains runtime mappings: serial ↔ UUID (bidirectional)
- Persists mappings to UserDefaults
- Provides lookup to find which UUID currently has which serial

**Key Methods:**
```swift
// Store a serial number for a UUID
func storeSerialNumber(_ serialNumber: String, for uuid: UUID)

// Get the current UUID for a serial number
func getUUID(forSerial serialNumber: String) -> UUID?

// Get the serial number for a UUID
func getSerialNumber(forUUID uuid: UUID) -> String?
```

### Modified: `BLEResponseHandler`

**Serial Number Handling** (line ~321):
- When AP SSID is received, stores the serial → UUID mapping
- Also stores the display name keyed by serial number

### Modified: `CameraGroupManager`

**Serial-Based Operations**:
- `addCameraToGroup` now takes serial number instead of UUID
- `removeCameraFromGroup` now takes serial number instead of UUID
- `getCamerasInActiveGroup` looks up UUIDs from serial numbers
- `getGroupStatus` looks up cameras by serial numbers

### Modified: Views

All views updated to work with serial numbers:
- `CameraInGroupRowView`: Takes `cameraSerial` and looks up UUID
- `CameraGroupEditorView`: Displays cameras by serial number
- `CameraSelectorView`: Shows both discovered and connected cameras, refreshes on appear to clear stale entries
- `ActiveGroupSummaryView`: Looks up UUIDs from serial numbers to display cameras
- `ContentView`: Converts serial sets to UUID sets when needed
- `RecordingControlsView`: Uses serial numbers for recording control

## Data Flow

```
1. Discovery
   └─> Device advertises as "GoPro 1234"
   └─> Added to discovered devices (normal BLE flow)

2. Connection & Status Query
   └─> Camera connects
   └─> Query status including AP SSID
   └─> Receive AP SSID "GP12345678"
   └─> Store mapping: "GP12345678" → UUID
   └─> Store display name: "GP12345678" → "GoPro 1234"

3. Group Membership
   └─> Camera group contains serial "GP12345678"
   └─> Look up current UUID for "GP12345678"
   └─> Display camera in group using that UUID
   └─> Even if UUID changes, serial stays the same
```

## Usage

The feature works automatically with no user intervention required:

1. **Adding Camera to Group**: User opens "Add Camera" view
   - View refreshes discovered cameras list (clears stale entries)
   - Shows both connected cameras and newly discovered cameras
   - Tap a connected camera to add it immediately
   - Tap a discovered camera to connect and auto-add to group
   - App stores the camera's serial number in the group
2. **Normal Operation**: Camera is identified by its serial number
   - Display shows `peripheral.name` (e.g., "GoPro 1234")
   - Groups reference cameras by serial, runtime lookup finds current UUID
3. **After Connection Reset**: Camera gets new UUID from iOS
   - App receives AP SSID during connection
   - Stores new UUID → serial mapping
   - Camera automatically appears in correct groups
   - No migration or manual re-association needed

## Persistence

- **Serial → UUID Mappings**: Stored in UserDefaults under key `"CameraSerialMappings"` as `[String: String]` (serial → UUID string)
- **Serial → Name Mappings**: Stored in UserDefaults under key `"CameraNames"` as `[String: String]` (serial → display name)
- **Camera Groups**: Stored with serial numbers in the `cameraSerials` field

## Logging

The feature provides detailed logging:
- `📝` Stored serial number mapping when AP SSID is received

## Edge Cases Handled

1. **Camera Without Serial**: Camera discovered but not yet connected
   - Solution: CameraSelectorView shows discovered cameras with "Tap to connect"
   - One tap connects and auto-adds to group when serial is received

2. **Stale Discovered Cameras**: Cameras no longer in range still in discovered list
   - Solution: CameraSelectorView clears discovered list on appear via `refreshDiscoveredCameras()`
   - Only currently advertising cameras will reappear after refresh

3. **First Time Connection**: Camera connects for first time
   - Solution: Stores serial → UUID mapping immediately when AP SSID is received

4. **UUID Changes**: iOS assigns new UUID after connection reset
   - Solution: Old UUID mapping is removed, new one stored automatically
   - Groups continue to work because they reference serial, not UUID

5. **Display Names**: Consistent naming across UUID changes
   - Solution: Display names stored by serial number, persisted across sessions

6. **Duplicates**: Same camera appearing as both discovered and connected
   - Solution: CameraSelectorView prioritizes connected cameras, filters out duplicates

## Key Benefits

1. **Stable Identity**: Cameras maintain group membership across iOS UUID changes
2. **No Migration Needed**: System automatically uses current UUID for each serial
3. **Simple Implementation**: Using serial as primary key eliminates complex migration logic
4. **User Transparent**: No user action required when UUID changes
