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

    public var memptr: UInt16 = 0x00

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
    //    startProcess()
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
        await fps()
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
    
    open func mCyclesAndTStates(m: Int, t: Int) async {
        tStates += t
        let bit7 = R & 0x80
        R = ((R &+ UInt8(m)) & 0x7F) | bit7
        if tStates >= tStatesPerFrame {
            tStates = 0
            await render()
        }
    }
    
    open func preInPerform() {
        
    }
    
//    open func await memory.write(to: UInt16, value: UInt8) async {
//        //internalawait memory.write(to: to, value: value)
//        await memory.write(to: to, value: value)
//    }
//    
//
//    open func await memory.read(from: UInt16) async -> UInt8 {
//        internalawait memory.read(from: from)
//    }
    
    
}

@Observable
public class Z80Controller {
    public static let shared = Z80Controller()
    public var lastSecondValue: Int = 0
    
    // **** Speed Control ****
    public var processorSpeed: Z80ProcessorSpeed = .standard
    
    public var memoryMap: Z80MemoryMap? = nil
    public var storedMemoryMap: Z80MemoryMap? = nil
    
    public var showingSettings = false
    
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

public actor Z80MemoryMap {
    public var jumpMap: Set<UInt16> = []
    public var dataMap8Bit: [UInt16: UInt8] = [:]
    public var dataMap16Bit: [UInt16: UInt16] = [:]
    public var ixyMap: Set<UInt16> = []
    public var stackMap: Set<UInt16> = []
    public var showingSettings = false
    
    public func recordJump(_ jump: UInt16) {
        if jump > 0x4000 {
            if jumpMap.contains(jump) {
                return
            }
                jumpMap.insert(jump)
        }
    }
    
    public func recordIxy(_ data: UInt16) {
        if data > 0x4000 {
            if ixyMap.contains(data) {
                return
            }
            print("Record Ixy: \(data)")
                ixyMap.insert(data)
        }
    }
    
    public func recordData(_ data: UInt16, value8Bit: UInt8? = nil, value16Bit: UInt16? = nil) {
        if data > 0x4000 {
            if let value8Bit {
                dataMap8Bit[data] = value8Bit
            }
            if let value16Bit {
                dataMap16Bit[data] = value16Bit
            }
        }
    }
    
    public func recordStack(_ data: UInt16) {
        if data > 0x4000 {
            if stackMap.contains(data) {
                return
            }
                stackMap.insert(data)
        }
    }
    
    public func fetch8BitData() -> [(UInt16, UInt8)] {
        return dataMap8Bit.map{($0.key, $0.value)}.sorted(by: {$0.0 < $1.0}) ?? []
    }
    
    public func fetch16BitData() -> [(UInt16, UInt16)] {
        return dataMap16Bit.map{($0.key, $0.value)}.sorted(by: {$0.0 < $1.0}) ?? []
    }
    
    public func fetchJumpMap() -> [UInt16] {
        return jumpMap.map{$0}.sorted(by: {$0 < $1}) ?? []
    }
}
