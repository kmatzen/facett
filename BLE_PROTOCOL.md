# GoPro BLE Protocol

Facett communicates with GoPro cameras over BLE using a packet-based protocol with TLV (Type-Length-Value) encoding.

Reference: <https://gopro.github.io/OpenGoPro/ble/protocol/data_protocol.html>

## Service & Characteristic UUIDs

| Name | UUID |
|------|------|
| GoPro Service | `B5F90001-AA8D-11E3-9046-0002A5D5C51B` |
| Command (write) | `B5F90002-AA8D-11E3-9046-0002A5D5C51B` |
| Command Response (notify) | `B5F90003-AA8D-11E3-9046-0002A5D5C51B` |
| Query (write) | `B5F90076-AA8D-11E3-9046-0002A5D5C51B` |
| Query Response (notify) | `B5F90077-AA8D-11E3-9046-0002A5D5C51B` |

## Packet Structure

BLE 4.2 limits packets to 20 bytes. Larger messages are split across start + continuation packets.

### Header Format

**Bit 7** determines start vs. continuation:

- **Bit 7 = 0 → Start packet.** Bits 6-5 select the length format:
  - `00` → General (5-bit): bits 4-0 = message length (max 31)
  - `01` → Extended 13-bit: bits 4-0 + next byte = message length
  - `10` → Extended 16-bit: next 2 bytes = message length (receive-only)
- **Bit 7 = 1 → Continuation packet.** Bits 3-0 = 4-bit sequence counter (wraps at 0xF)

### Start Packet Layouts

#### General (5-bit length)
```
Byte 0:   [0][00][5-bit message length]
Bytes 1+: message payload
```

#### Extended 13-bit
```
Byte 0:   [0][01][upper 5 bits of length]
Byte 1:   [lower 8 bits of length]
Bytes 2+: message payload
```

#### Extended 16-bit (receive-only, messages >= 8192 bytes)
```
Byte 0:   [0][10][reserved]
Bytes 1-2: 16-bit message length
Bytes 3+:  message payload
```

### Continuation Packet
```
Byte 0:   [1][reserved][4-bit counter]
Bytes 1+: continuation payload
```

## Message Payload

Query responses (on Query Response characteristic):
```
[QueryID (1 byte)] [Status (1 byte)] [TLV data...]
```

Command responses (on Command Response characteristic):
```
[CommandID (1 byte)] [Status (1 byte)] [optional data...]
```

## TLV Encoding

Each entry in the TLV data region:

```
┌──────────┬──────────┬─────────────┐
│ Type     │ Length   │ Value       │
│ (1 byte) │ (1 byte) │ (N bytes)   │
└──────────┴──────────┴─────────────┘
```

Multiple TLV entries are concatenated back-to-back in a single message payload.

## Parsing Pipeline

The app processes incoming BLE data through three stages:

1. **`BLEPacketReconstructor`** — reassembles multi-packet messages using header bit-fields
2. **`BLETLVParser`** — decodes TLV entries from the reassembled payload
3. **`BLEResponseMapper`** — maps TLV entries to strongly-typed `ResponseType` values

See `GoProCommands.swift` for the command byte definitions used by the app.
