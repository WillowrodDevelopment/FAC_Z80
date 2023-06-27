//
//  Z80+Registers.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation
import FAC_Common

extension Z80 {
    
    var B : UInt8 {
        get {return BC.highByte()}
        set {
            let low = BC.lowByte()
            BC = (UInt16(newValue) * 256) + UInt16(low)
        }
    }

    var C : UInt8 {
        get {return BC.lowByte()}
        set {
            let high = UInt16(BC.highByte()) * 256
            BC = high + UInt16(newValue)
        }
    }

    var D : UInt8 {
        get {return DE.highByte()}
        set {
            let low = DE.lowByte()
            DE = (UInt16(newValue) * 256) + UInt16(low)
        }
    }

    var E : UInt8 {
        get {return DE.lowByte()}
        set {
            let high = UInt16(DE.highByte()) * 256
            DE = high + UInt16(newValue)
        }
    }

    var F: UInt8 {
        get {return _F}
        set {
        //    modified53 = _F & 0x28 != newValue & 0x28
            _F = newValue
        }
    }

    var H : UInt8 {
        get {return HL.highByte()}
        set {
            let low = HL.lowByte()
            HL = (UInt16(newValue) * 256) + UInt16(low)
        }
    }

    var L : UInt8 {
        get {return HL.lowByte()}
        set {
            let high = UInt16(HL.highByte()) * 256
            HL = high + UInt16(newValue)
        }
    }
    
    var AF : UInt16 {
        get {
            let high = UInt16(A) * 256
            return UInt16(F) + high
        }
        set {
            A = newValue.highByte()
            F = newValue.lowByte()
        }
    }

    func valueFromSource(source: UInt8, index: Z8016BitRegister? = nil) -> UInt8 { //, displacement: UInt8 = 0x00
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
                return memory[Int(displacedIndex(index, displacement: next()))]
            }
            return memory[Int(HL)]
        case 0x07:
            return A
        default:
            print("Should not get here!")
            return 0x00
        }
    }

    func valueOfIndex(index: Z8016BitRegister) -> UInt16 {
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

    func writeIndex(_ index: Z8016BitRegister, value: UInt16) {
        switch index {
        case .PC:
            PC = value
        case .SP:
             SP = value
        case .IX:
             IX = value
        case .IY:
             IY = value
        case .SPARE:
             SPARE16 = value
        }
     }

    func swapAF() {
        let temp = AF
        AF = AF2
        AF2 = temp
    }

    func swapBC() {
        let temp = BC
        BC = BC2
        BC2 = temp
    }

    func swapDE() {
        let temp = DE
        DE = DE2
        DE2 = temp
    }

    func swapHL() {
        let temp = HL
        HL = HL2
        HL2 = temp
    }

    func getRegister(_ byte: UInt8) -> UInt8 {
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
            return memoryRead(from: HL)
        default:
            return A
        }
    }

        func writeRegister(_ byte: UInt8, value: UInt8) {
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
                 memory[Int(HL)] = value
                 //break
             default:
                 A = value
             }
         }
}
