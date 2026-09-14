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
    
    /// Optional recorder that observes every memory/I/O access with its frame
    /// t-state. Set by a machine to feed ULA contention. `memory` is always a
    /// recording wrapper that forwards to the real delegate and reports to
    /// this recorder when one is attached.
    public weak var accessRecorder: MemoryAccessRecorder?

    /// Optional bus-contention model (ULA). When set, wait states are inserted
    /// into the CPU clock at each contended memory access.
    public weak var contention: BusContention?

    // **** Per-M-cycle clock (M0) ****
    var instructionBaseTStates = 0
    var instructionDelay = 0
    var instructionLastOffset = 0
    var instructionAccessIndex = 0
    var currentInstructionPattern: AccessPattern?

    /// Reports an access to the recorder at its per-M-cycle frame position, and
    /// applies any bus-contention wait state by advancing the CPU clock.
    func recordAccess(_ kind: MemAccessKind, address: UInt16) {
        if let pattern = currentInstructionPattern,
           instructionAccessIndex < pattern.steps.count {
            let step = pattern.steps[instructionAccessIndex]
            let target = instructionBaseTStates + step.tStateOffset + instructionDelay
            if target > tStates {
                tStates = target
            }
            instructionLastOffset = step.tStateOffset
            instructionAccessIndex += 1
        }
        // The per-M-cycle clock can run past the frame boundary mid-instruction
        // (accumulate wraps it at the end); the ULA model expects a frame-relative
        // position, so wrap it here.
        let frameT = currentFrameTState % frameTStates
        if let contention {
            let delay = contention.delay(beginningAt: frameT, address: address)
            if delay > 0 {
                tStates += delay
                instructionDelay += delay
            }
        }
        // Recompute after contention so the recorder sees the post-delay position.
        accessRecorder?.record(RecordedMemoryAccess(
            kind: kind,
            address: address,
            tStateInFrame: currentFrameTState % frameTStates
        ))
    }

    /// The CPU's absolute position in the current frame, in t-states.
    private var currentFrameTState: Int {
        frameBaseTState + tStates
    }

    var frameBaseTState = 0
    
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

    // **** M0: scanline tracking (additive, no game-timing impact) ****
    /// T-states per scanline (default: 48K's 224). Machines with a different
    /// line length override this.
    open var tStatesPerScanline: Int { 224 }
    /// Scanlines per rendered frame, derived from the frame budget.
    public var scanlinesPerFrame: Int { frameTStates / tStatesPerScanline }
    /// Current scanline within the frame (0…scanlinesPerFrame-1).
    public var currentScanline: Int {
        min(tStates / tStatesPerScanline, max(scanlinesPerFrame - 1, 0))
    }
    /// Hook fired for each scanline boundary crossed by an instruction. Machines
    /// override this for per-line behaviour (ULA fetch, border, Copper).
    open func scanlineCrossed(line: Int) {
    }
    var lastScanline = 0

    // **** M0: NMI (additive, unused by Spectrum software) ****
    /// Set by `requestNMI()`; serviced at the next instruction boundary by
    /// `checkNMI()`, independent of the maskable-INT path.
    public var nmiRequested = false
    /// Requests a non-maskable interrupt. On service: IFF1 is saved to IFF2,
    /// IFF1 is cleared, and the CPU vectors to 0x0066 (RETN restores IFF1).
    public func requestNMI() {
        nmiRequested = true
    }

    /// Services a pending NMI (called after each instruction). Leaves the
    /// maskable-INT path untouched so frame-interrupt-driven games are unaffected.
    func checkNMI() {
        guard nmiRequested else { return }
        nmiRequested = false
        iff2 = iff1          // save IFF1 for RETN
        iff1 = 0             // disable maskable interrupts during NMI handler
        isInHaltState = false
        push(PC)
        PC = 0x0066
    }

    // **** M0: maskable-INT timing (per-instruction, once per frame) ****
    /// EI defers interrupt acceptance by one instruction: EI sets IFF1/IFF2 but
    /// the instruction *following* EI always completes before an INT is taken.
    public var eiDeferred = false
    /// True once a maskable INT has been serviced this frame (reset at the
    /// frame boundary) so the interrupt fires at most once per frame.
    var intServicedThisFrame = false
    /// First frame t-state at which the maskable INT line is asserted
    /// (machine-configurable; default: 48K's pulse at frame start).
    open var interruptStartTState: Int { 0 }
    /// Frame t-state just past the end of the maskable INT pulse (default 32).
    open var interruptEndTState: Int { 32 }
    /// Whether the maskable INT line is asserted at the current frame position.
    public var intAsserted: Bool {
        tStates >= interruptStartTState && tStates < interruptEndTState
    }

    /// Services a pending NMI, then the maskable INT. Called after every
    /// instruction. The maskable INT is serviced at most once per frame: it is
    /// taken only inside the assert window when IFF1 is set and not in the EI
    /// deferral; accepting it clears IFF1/IFF2 (real-Z80 behaviour), so it can
    /// never re-fire until the program re-enables interrupts.
    func serviceInterrupts() {
        checkNMI()
        if controller.processorSpeed == .paused { return }
        guard !intServicedThisFrame else { return }
        if eiDeferred {
            // The instruction after EI completes without interruption.
            eiDeferred = false
            return
        }
        if intAsserted && iff1 == 1 {
            intServicedThisFrame = true
            serviceMaskableInterrupt()
        }
    }

    func serviceMaskableInterrupt() {
        isInHaltState = false
        push(PC)
        switch interuptMode {
        case 0:
            PC = 0x0066 // Unused on the ZX Spectrum
        case 1:
            PC = 0x0038
        default:
            let oldPC = PC
            let intAddress = (UInt16(I) * 256) + 0xff // Assume the databus will send 0xFF as no external hardware available
            PC = memory.readWord(from: intAddress)
            recordJumpBanked(PC, type: .IM2, from: oldPC)
        }
        // Real Z80: accepting a maskable interrupt clears IFF1 and IFF2.
        iff1 = 0
        iff2 = 0
    }
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

    /// Enables the Next's extended instruction set (Z80N). Off by default so
    /// classic Z80s treat those ED opcodes as NOPs; a Next machine sets this.
    public var z80nEnabled = false

    public var isDebugging = false
    
    public var stackSize = 0

    
    public var iff1Temp: UInt8 = 0x00
    public var iff2Temp: UInt8 = 0x00
    
    let loggingService = LoggingService.shared
    
    public init(memory: MemoryDelegate) {
        let wrapper = RecordingMemoryDelegate(wrapping: memory)
        self.memory = wrapper
        calculateTables()
        controller.cpuLog = Z80Log(cpu: self)
        wrapper.attach(cpu: self)
    }
     
    public let controller = Z80Controller.shared

    /// The opcode dispatch tables for this CPU. Defaults to the reference
    /// (switch-equivalent) tables; used by the table-driven execution path
    /// during the switch→table refactor and, once migrated, as the primary
    /// dispatcher.
    public var opcodeTables: OpcodeTableSet = OpcodeTableSet.defaultTables()
    
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
    
    /// Total t-states per rendered frame, gated per machine. Defaults to the
    /// classic 48K figure (69,888). A subclass overrides this for machines with
    /// a different frame budget — e.g. the 128K/+2 and +2A/+3 run 70,908
    /// (228 t-states × 311 lines). FAC_ULA's ULATimingProfile is the source of
    /// truth for these numbers when a machine adopts it.
    open var frameTStates: Int { tStatesPerFrame }

    /// Synchronously accumulates cycle counts and R refresh for an instruction.
    /// Sets `frameBoundaryHit` when a frame's t-state budget is consumed so the
    /// async renderer can be invoked once per frame by the process loop.
    func accumulate(m: Int, t: Int) {
        let oldT = tStates
        tStates += t
        let bit7 = R & 0x80
        R = ((R &+ UInt8(m)) & 0x7F) | bit7
        let newLine = min(tStates / tStatesPerScanline, max(scanlinesPerFrame - 1, 0))
        let oldLine = oldT / tStatesPerScanline
        // Forward crossings only: a frame wrap (newLine < oldLine) resets the
        // scanline counter below rather than reporting phantom lines.
        if newLine > oldLine {
            for line in (oldLine + 1)...newLine {
                scanlineCrossed(line: line)
            }
            lastScanline = newLine
        }
        if tStates >= frameTStates {
            tStates = 0
            intServicedThisFrame = false
            lastScanline = 0
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
        recordAccess(.io, address: UInt16(lower))
        hardwarePorts.performOut(lower: lower, upper: upper, value: value)
    }
    
    open func readPort(lower: UInt8, upper: UInt8) -> UInt8 {
        recordAccess(.io, address: UInt16(lower))
        return hardwarePorts.performIn(lower: lower, upper: upper)
    }

    /// Writes `value` to a Next register (Z80N NEXTREG, ED 91/92). The base
    /// Z80 has no Next registers; a Next machine overrides this to route into
    /// its NextREG file. Declared here (not an extension) so subclasses can
    /// override it.
    open func nextRegWrite(_ reg: UInt8, value: UInt8) {
    }

    /// Called before each M1 opcode fetch (in `fetchAndExecute`). A machine
    /// overrides this to observe or trap opcode fetches — e.g. the divMMC
    /// auto-pager and the esxDOS RST 8 dispatcher. Return `true` when the
    /// hook has handled the fetch (it must have set PC/state itself), in
    /// which case no instruction is executed this cycle.
    open func preFetch(pc: UInt16) -> Bool {
        false
    }

    /// Called immediately after each M1 opcode fetch (the opcode byte has
    /// been read at `pc`), before the instruction executes. A machine
    /// overrides this for post-fetch state changes — e.g. the divMMC
    /// auto-pager's delayed page-out at the $1FF8-$1FFF off-area.
    open func postFetch(pc: UInt16) {
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
