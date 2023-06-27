//
//  Z80.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation

open class Z80 {
    public var memory: [UInt8] = []
    public var memoryBlocks: [[UInt8]] = []
    // **** Registers ****
    // Flags
    var _F: UInt8 = 0x00
    
    public var fpsValue = 0

    var sz53pvTable: [UInt8] = []
    var sz53Table:   [UInt8] = []
    var parityBit:   [UInt8] = []
    let halfCarryAdd:  [UInt8] = [0, 1 << 4, 1 << 4, 1 << 4, 0, 0, 0, 1 << 4]
    let halfCarrySub:  [UInt8] = [0, 0, 1 << 4, 0, 1 << 4, 0, 1 << 4, 1 << 4]
    let overFlowAdd:   [UInt8] = [0, 0, 0, 1 << 2, 1 << 2, 0, 0, 0]
    let overFlowSub:   [UInt8] = [0, 1 << 2, 0, 0, 0, 0, 1 << 2, 0]

    let initialMasks: (halfCarryMask: UInt8, overflowMask: UInt8, value: UInt8) = (halfCarryMask: 0x00, overflowMask: 0x00, value: 0x00)

    // Accumilator
    var A: UInt8 = 0x00
    // Register Pairs
    var BC: UInt16 = 0x00
    var DE: UInt16 = 0x00
    var HL: UInt16 = 0x00
    // Shadow Register Pair
    var AF2: UInt16 = 0x0
    var BC2: UInt16 = 0x0
    var DE2: UInt16 = 0x0
    var HL2: UInt16 = 0x0
    // Control Registers
    var PC: UInt16 = 0x00
    var SP: UInt16 = 0x00
    // Index Registers
    var IX: UInt16 = 0x00
    var IY: UInt16 = 0x00
    // Special Registers
    var I: UInt8 = 0x00
    var R: UInt8 = 0x00
    // Spare Registers
    var SPARE16: UInt16 = 0x00
    var SPARE8: UInt8 = 0x00
    
    // **** Control ****
    let tStatesPerFrame = 69888
    var tStates = 0
    var interuptMode: UInt8 = 1
    var iff1: UInt8 = 0x00
    var iff2: UInt8 = 0x00
    var runInterup: Bool = false
    var pagingByte: UInt8 = 0

    public var shouldProcess = false

    var frameCompleted = false
    var frameStarted: TimeInterval = Date().timeIntervalSince1970
    
    var isInHaltState = false
    
    // **** Flag Masks ****
    
    let carry: UInt8 = 0x01
    let negative: UInt8 = 0x02
    let parityOverflow: UInt8 = 0x04
    let three: UInt8 = 0x08
    let halfCarry: UInt8 = 0x10
    let five: UInt8 = 0x20
    let zero: UInt8 = 0x40
    let sign: UInt8 = 0x80

    var modified53 = false

    var memptr: UInt16 = 0x00

    // **** Hardware ****

    public var activeHardwarePorts: [String : UInt8] = [:]
    
    var frames = 0
    var startTime = Date().timeIntervalSince1970

// **** Speed Control ****

    public var processorSpeed: Z80ProcessorSpeed = .standard

    // **** Debug ****

    public var preProcessorDebug = false
    public var postProcessorDebug = false
    public var memDebug = false
    public var miscDebug = false
    public var opcodeDebug = false

    public var isDebugging = false

    
    public init() {
        memory = Array(repeating: 0x00, count: 65536)
        calculateTables()
    }
    
    // Overrideable functions
    
    open func fps() {
        let seconds = Int(Date().timeIntervalSince1970 - startTime)
        frames += 1
        if seconds > 0 {
            fpsValue = frames / seconds
        }
    }
    
    open func display() {
        // Override to handle screen writes
    }
    
}
