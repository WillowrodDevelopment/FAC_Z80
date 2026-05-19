//
//  Z80+Registers.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation
import FAC_Common

extension Z80 {
    
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
    
    public var F: UInt8 {
        get { _F }
        set { _F = newValue }
    }

    public var AF : UInt16 {
        get {
            let high = UInt16(A) * 256
            return UInt16(F) + high
        }
        set {
            A = newValue.highByte()
            F = newValue.lowByte()
        }
    }

    func valueFromSource(source: UInt8, index: Z8016BitRegister? = nil) async -> UInt8 { //, displacement: UInt8 = 0x00
        switch source {
        case 0x00:
            return B
        case 0x01:
            return C
        case 0x02:
            return D
        case 0x03:
            return E
        case 0x04:
            if let index {
                switch index {
                case .IX:
                    return IX.highByte()
                case .IY:
                    return IY.highByte()
                default:
                    return 0x00
                }
            }
            return H
        case 0x05:
            if let index {
                switch index {
                case .IX:
                    return IX.lowByte()
                case .IY:
                    return IY.lowByte()
                default:
                    return 0x00
                }
            }
            return L
        case 0x06:
            if let index {
                return await memory.read(from: displacedIndex(index, displacement: next()))
            }
            return await memory.read(from: HL)
        case 0x07:
            return A
        default:
            print("Should not get here!")
            return 0x00
        }
    }

    func valueOfIndex(index: Z8016BitRegister) async -> UInt16 {
        switch index {
        case .PC:
            return PC
        case .SP:
            return SP
        case .IX:
            return IX
        case .IY:
            return IY
        case .SPARE:
            return SPARE16
        }
    }

    func writeIndex(_ index: Z8016BitRegister, value: UInt16) async {
        switch index {
        case .PC:
            PC = value
        case .SP:
             SP = value
            await controller.memoryMap?.recordStack(value)
        case .IX:
             IX = value
            await controller.memoryMap?.recordIxy(value)
        case .IY:
             IY = value
            await controller.memoryMap?.recordIxy(value)
        case .SPARE:
             SPARE16 = value
        }
     }

    func swapAF() async {
        let temp = AF
        AF = AF2
        AF2 = temp
    }

    func swapBC() async {
        let temp = BC
        BC = BC2
        BC2 = temp
    }

    func swapDE() async {
        let temp = DE
        DE = DE2
        DE2 = temp
    }

    func swapHL() async {
        let temp = HL
        HL = HL2
        HL2 = temp
    }

    func getRegister(_ byte: UInt8) async -> UInt8 {
        switch byte {
        case 0:
            return B
        case 1:
            return C
        case 2:
            return D
        case 3:
            return E
        case 4:
            return H
        case 5:
            return L
        case 6:
            return await memory.read(from: HL)
        default:
            return A
        }
    }

        func writeRegister(_ byte: UInt8, value: UInt8) async {
             switch byte {
             case 0:
                 B = value
             case 1:
                 C = value
             case 2:
                 D = value
             case 3:
                 E = value
             case 4:
                 H = value
             case 5:
                 L = value
             case 6:
                 await memory.write(to: HL, value: value)
                 //break
             default:
                 A = value
             }
         }
    
    public func loadRegisters(a: UInt8,
                       b: UInt8,
                       c: UInt8,
                       d: UInt8,
                       e: UInt8,
                       f: UInt8,
                       h: UInt8,
                       l: UInt8,
                       a2: UInt8,
                       b2: UInt8,
                       c2: UInt8,
                       d2: UInt8,
                       e2: UInt8,
                       f2: UInt8,
                       h2: UInt8,
                       l2: UInt8,
                       sp: UInt16,
                       ix: UInt16,
                       iy: UInt16,
                       i: UInt8,
                       r: UInt8,
                       im: UInt8,
                       ir1: UInt8,
                       ir2: UInt8,
                       pc: UInt16,
                       shouldReturn: Bool
    ) async {
        AF = await wordFrom(high: a, low: f)
        BC = await wordFrom(high: b, low: c)
        DE = await wordFrom(high: d, low: e)
        HL = await wordFrom(high: h, low: l)
        
            AF2 = await wordFrom(high: a2, low: f2)
            BC2 = await wordFrom(high: b2, low: c2)
            DE2 = await wordFrom(high: d2, low: e2)
            HL2 = await wordFrom(high: h2, low: l2)
        
        SP = sp
        I = i
        R = r
        
        interuptMode = im
        iff1 = ir1
        iff2 = ir2
        
        if (shouldReturn) {
            await ret()
        } else {
            PC = pc
        }
        
        
        
    }
    
    func fetchRegisterData() async -> Dictionary<String, String> {
        return ["A": A.hex(),
                "B": B.hex(),
                "C": C.hex(),
                "D": D.hex(),
                "E": E.hex(),
                "H": H.hex(),
                "L": L.hex(),
                "F": F.bin(),
                "BC": BC.hex(),
                "DE": DE.hex(),
                "HL": HL.hex(),
                "PC": PC.hex(),
                "SP": SP.hex(),
                "I": I.hex(),
                "R": R.hex(),
                "IM": String(interuptMode),
                "IFF1": String(iff1),
                "IFF2": String(iff2)
    ]
    }
    
}
