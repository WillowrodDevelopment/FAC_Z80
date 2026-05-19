# Plan: Speed up Z80 opcode processing — Phase 2

## Goal
Replace register computed properties with direct storage for B, C, D, E, H, L. Make BC, DE, HL computed from the individual bytes using bit shifts instead of division/multiplication.

## Why
Currently every access to B/C/D/E/H/L goes through computed properties that call `highByte()`/`lowByte()` extensions involving division and multiplication. Storing the 8-bit registers directly eliminates this overhead on every opcode.

## Changes

### 1. `Sources/FAC_Z80/Z80.swift` (lines 45-55)
**Remove:**
```swift
public var BC: UInt16 = 0x00
public var DE: UInt16 = 0x00
public var HL: UInt16 = 0x00
```

**Add:**
```swift
public var B: UInt8 = 0x00
public var C: UInt8 = 0x00
public var D: UInt8 = 0x00
public var E: UInt8 = 0x00
public var H: UInt8 = 0x00
public var L: UInt8 = 0x00
```

### 2. `Sources/FAC_Z80/Z80+Registers.swift`
**Remove** the B, C, D, E, H, L computed property definitions (lines 13-67).

**Add** BC, DE, HL as computed properties:
```swift
public var BC: UInt16 {
    get { (UInt16(B) << 8) | UInt16(C) }
    set { B = UInt8(newValue >> 8); C = UInt8(newValue & 0xFF) }
}
public var DE: UInt16 {
    get { (UInt16(D) << 8) | UInt16(E) }
    set { D = UInt8(newValue >> 8); E = UInt8(newValue & 0xFF) }
}
public var HL: UInt16 {
    get { (UInt16(H) << 8) | UInt16(L) }
    set { H = UInt8(newValue >> 8); L = UInt8(newValue & 0xFF) }
}
```

### 3. Replace all `.inc()` / `.dec()` on BC, DE, HL pairs
These extension methods mutate `self` and won't work on computed properties. Replace with direct assignment:

- `BC.inc()` → `BC = BC &+ 1`
- `BC.dec()` → `BC = BC &- 1`
- Same for DE, HL

**Files affected:**
- `Z80+OpCodes.swift` — 6 occurrences
- `Z80+ED_OpCodes.swift` — 28 occurrences
- `Z80+DDFD_OpCodes.swift` — 4 occurrences
- `Z80+16BitCalculations.swift` — 6 occurrences (in `inc(pair:)` and `add(pair:)` helpers)

### 4. `Sources/FAC_Z80/Z80+Control.swift` — `resetProcessor()`
Change:
```swift
BC = 0x00
DE = 0x00
HL = 0x00
```
To:
```swift
B = 0x00; C = 0x00
D = 0x00; E = 0x00
H = 0x00; L = 0x00
```

### 5. Build and verify
Run `swift build` and `swift test` to confirm no regressions.

## Risk assessment
- **Low risk**: BC/DE/HL computed properties maintain the same external API — all existing code that reads/writes pairs continues to work
- **No behavioral change**: bit shifts produce identical results to the previous `* 256` / division approach
- **Shadow registers** (BC2, DE2, HL2) remain as stored UInt16 — swap operations unchanged
- **AF** computed property unchanged — A and _F remain separate storage
