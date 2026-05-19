# AGENTS.md

## Project

Swift Package — Z80 CPU emulator library ("Fake-A-Chip" family).
Platforms: macOS 14+, iOS 17+. Swift 5.10+.

## Build & Verify

```
swift build        # compile
swift test         # test target declared but no test files exist
```

No lint, formatter, typecheck, or CI config.

## Dependency Quirk

`FAC_Common` is a **local path dependency** at `../FAC_Common` (sibling directory). The package will not build without that sibling present.

## Architecture

- **`Z80`** (`Z80.swift`) — `open class`, designed to be subclassed by hardware-specific implementations. Override `display()`, `preProcess()`, `postProcess()`, `mCyclesAndTStates()`.
- **`Z80Controller`** — `@Observable` singleton (`shared`), manages processor speed, memory map, CPU log.
- **`Z80+Process.swift`** — async `process()` loop.
- **`OpCodes/`** — opcode dispatch split by prefix: main, CB, ED, DD/FD, DD/FD CB.
- **`Operations/`** — 8-bit and 16-bit ALU calculations.
- **`Actors/`** — `MemoryActor`, `Z80LogActor`, `HardwarePortsActor` (Swift concurrency).
- **`Delegates/`** — `MemoryDelegate`, `Z80LoggingDelegate`, `Z80ControlDelegate` — extension points.

Key constant: `tStatesPerFrame = 69888`.

## Branches

- `development` — default (remote HEAD).
- `main` — likely stale.
