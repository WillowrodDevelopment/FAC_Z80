//
//  Z80.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation
import FAC_Common

public let tStatesPerFrame = 69888

open class Z80 {
    // **** Delegates ****
    
    public var logDelegate: Z80LoggingDelegate?
    public var controlDelegate: Z80ControlDelegate?
    
    public var romSelected = 0
    public var ramSelected = 0
    public var screenShadow = false
    public var is128k = false
    
    /// Canonical (bank, address) for a 16-bit address, given the current paging state.
    /// ROMs use negative bank numbers: -1 is ROM 0 and -2 is ROM 1.
    /// For the 48k (is128k == false) the bank is always 0 and the address is unchanged.
    public func canonicalBankAddress(for addr: UInt16) -> BankedAddress {
        guard is128k else { return BankedAddress(bank: 0, address: addr) }
        let a = Int(addr)
        switch a {
        case ...0x3FFF:
            // Negative bank numbers identify ROMs and cannot collide with RAM bank 0.
            return BankedAddress(bank: -(romSelected + 1), address: addr)
        case ...0x7FFF:
            let bank = screenShadow ? 7 : 5
            return BankedAddress(bank: bank, address: addr)
        case ...0xBFFF:
            return BankedAddress(bank: 2, address: addr)
        default:
            // Keep the address in the window where it was observed.
            return BankedAddress(bank: ramSelected, address: addr)
        }
    }
    
    let memory: MemoryDelegate
    
    var stack: [UInt16] = []
    
    // **** Registers ****
    // Flags
    var _F: UInt8 = 0x00
    
    public var fpsValue = 0
    public var secondsValue = 0
    
    var displayTimer: Timer?

    var sz53pvTable: [UInt8] = []
    var sz53Table:   [UInt8] = []
    var parityBit:   [UInt8] = []
    let halfCarryAdd:  [UInt8] = [0, 1 << 4, 1 << 4, 1 << 4, 0, 0, 0, 1 << 4]
    let halfCarrySub:  [UInt8] = [0, 0, 1 << 4, 0, 1 << 4, 0, 1 << 4, 1 << 4]
    let overFlowAdd:   [UInt8] = [0, 0, 0, 1 << 2, 1 << 2, 0, 0, 0]
    let overFlowSub:   [UInt8] = [0, 1 << 2, 0, 0, 0, 0, 1 << 2, 0]

    let initialMasks: (halfCarryMask: UInt8, overflowMask: UInt8, value: UInt8) = (halfCarryMask: 0x00, overflowMask: 0x00, value: 0x00)

    // Accumilator
    public var A: UInt8 = 0x00
    // Register Pairs
    public var BC: UInt16 = 0x00
    public var DE: UInt16 = 0x00
    public var HL: UInt16 = 0x00
    // Shadow Register Pair
    public var AF2: UInt16 = 0x0
    public var BC2: UInt16 = 0x0
    public var DE2: UInt16 = 0x0
    public var HL2: UInt16 = 0x0
    // Control Registers
    public var PC: UInt16 = 0x00
    public var SP: UInt16 = 0x00
    // Index Registers
    public var IX: UInt16 = 0x00
    public var IY: UInt16 = 0x00
    // Special Registers
    public var I: UInt8 = 0x00
    public var R: UInt8 = 0x00
    // Spare Registers
    public var SPARE16: UInt16 = 0x00
    public var SPARE8: UInt8 = 0x00
    
    // **** Control ****
    
    public var tStates = 0
    public var interuptMode: UInt8 = 1
    public var iff1: UInt8 = 0x00
    public var iff2: UInt8 = 0x00
    public var interuptsEnabled: Bool = false
    var runInterup: Bool = false
    var pagingByte: UInt8 = 0

    public var shouldProcess = false

    var frameCompleted = false
    var frameStarted: TimeInterval = Date().timeIntervalSince1970
    var lastDisplayTime: TimeInterval = 0
    
    public var isInHaltState = false
    
    // **** Flag Masks ****
    
    let carry: UInt8 = 0x01
    let negative: UInt8 = 0x02
    let parityOverflow: UInt8 = 0x04
    let three: UInt8 = 0x08
    let halfCarry: UInt8 = 0x10
    let five: UInt8 = 0x20
    let zero: UInt8 = 0x40
    let sign: UInt8 = 0x80

    public var modified53 = true

    public var q: UInt8 = 0x00

    public var memptr: UInt16 = 0x00
    public var lastFetchPC: UInt16 = 0x00

    // **** Hardware ****
    public var hardwarePorts = HardwarePorts()
    
    var frames = 0
    var startTime = Date().timeIntervalSince1970


    // **** Debug ****

    public var preProcessorDebug = false
    public var postProcessorDebug = false
    public var memDebug = false
    public var miscDebug = false
    public var opcodeDebug = false

    public var isDebugging = false
    
    public var stackSize = 0

    
    public var iff1Temp: UInt8 = 0x00
    public var iff2Temp: UInt8 = 0x00
    
    let loggingService = LoggingService.shared
    
    public init(memory: MemoryDelegate) {
        self.memory = memory
        calculateTables()
        controller.cpuLog = Z80Log(cpu: self)
    }
     
    public let controller = Z80Controller.shared
    
    // Overrideable functions
    
    public var lastPCValues: [UInt16] = []
    
    public func startProcess() {
        Task {
            await process()
        }
    }
    
    open func fps() async {
        
        if controller.processorSpeed != .paused {
            let seconds = Int(Date().timeIntervalSince1970 - startTime)
            frames += 1
            if seconds > secondsValue {
                secondsValue = seconds
                controller.lastSecondValue = frames// / seconds
                frames = 0
                
            }
        } else {
            controller.lastSecondValue = 0
        }
    }
    
    open func display() async {
        // Override to handle screen writes
    }
    
    public func haltInterupts() async {
        
        await pause()
        iff1Temp = iff1
        iff2Temp = iff2
        iff1 = 0
        iff2 = 0
    }
    
    public func resumeInterupts() async {
        iff1 = iff1Temp
        iff2 = iff2Temp
    }
    
    /// Synchronously accumulates cycle counts and R refresh for an instruction.
    /// Sets `frameBoundaryHit` when a frame's t-state budget is consumed so the
    /// async renderer can be invoked once per frame by the process loop.
    func accumulate(m: Int, t: Int) {
        tStates += t
        let bit7 = R & 0x80
        R = ((R &+ UInt8(m)) & 0x7F) | bit7
        if tStates >= tStatesPerFrame {
            tStates = 0
            frameBoundaryHit = true
        }
        if controller.memoryMap != nil {
            controller.memoryMap?.recordPC(PC)
        }
    }

    var frameBoundaryHit = false

    /// Called once after each instruction's cycles are accumulated. Overridable so a
    /// computer can perform per-instruction work (border tracking, tape feeding)
    /// synchronously on the emulation thread. `t` is the instruction's t-state count.
    open func postInstruction(t: Int) {
    }

    open func mCyclesAndTStates(m: Int, t: Int) async {
        accumulate(m: m, t: t)
        if frameBoundaryHit {
            frameBoundaryHit = false
            await fps()
            await render()
        }
    }
    
    open func preProcess() async {
//        if PC >= 0xF66C && PC <= 0xF68E {
//            loggingService.log("Reading: \(PC.hex())")
//        }
    }
    
    open func postProcess() async {
        
    }
    
    open func preInPerform() {
        
    }
    
    // Port I/O hooks - overridable so specific computers (e.g. the ZX
    // Spectrum 128k) can intercept memory paging and sound chip ports.
    open func writePort(lower: UInt8, upper: UInt8?, value: UInt8) {
        hardwarePorts.performOut(lower: lower, upper: upper, value: value)
    }
    
    open func readPort(lower: UInt8, upper: UInt8) -> UInt8 {
        hardwarePorts.performIn(lower: lower, upper: upper)
    }
    
//    open func memory.write(to: UInt16, value: UInt8) async {
//        //internalmemory.write(to: to, value: value)
//        memory.write(to: to, value: value)
//    }
//    
//
//    open func memory.read(from: UInt16) async -> UInt8 {
//        internalmemory.read(from: from)
//    }
    
    /// Restarts the emulation process. Subclasses can override to reset
    /// machine-specific state (e.g. 128k paging) before the CPU restarts.
    open func reboot() async {
        await pause()
        shouldProcess = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Change `2.0` to the desired number of seconds.
            self.startProcess()
        }
    }
    
    
}

@Observable
public class Z80Controller {
    public static let shared = Z80Controller()
    public var lastSecondValue: Int = 0
    
    // **** Speed Control ****
    public var processorSpeed: Z80ProcessorSpeed = .standard
    
    /// Set by the app when the app enters background (scenePhase != .active).
    /// The emulation loop idles at ~1 FPS and stops rendering while true.
    public var isAppInBackground = false
    
    public var memoryMap: Z80MemoryMap? = nil
    public var storedMemoryMap: Z80MemoryMap? = nil
    public var cpuLog: Z80Log? = nil
    
    public var showingSettings = false
    
    // **** Breakpoints ****
    public private(set) var breakpoints: Set<UInt16> = []
    public var breakpointHit: UInt16? = nil
    public var isStepping = false
    public var breakpointsEnabled = false
    private let breakpointsLock = NSLock()
    
    public func setBreakpoints(_ newValue: Set<UInt16>) {
        breakpointsLock.lock()
        breakpoints = newValue
        breakpointsLock.unlock()
    }
    
    public func containsBreakpoint(_ address: UInt16) -> Bool {
        breakpointsLock.lock()
        defer { breakpointsLock.unlock() }
        return breakpoints.contains(address)
    }
    
    public var frameCount = 0
    
    func setJumpMapActive() {
        memoryMap = Z80MemoryMap()
    }
    
    func setJumpMapInactive() {
        storedMemoryMap = memoryMap
        memoryMap = nil
    }
    
    public func toggleJumpMap() {
        if let memoryMap {
            setJumpMapInactive()
        } else {
            setJumpMapActive()
        }
    }
}
