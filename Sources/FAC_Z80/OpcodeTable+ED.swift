import Foundation

// MARK: - ED prefix table
//
// Faithful port of the switch in Z80+ED_OpCodes.swift. Indexed by the ED
// operand byte (0…255). Each handler performs the instruction body and returns
// the actual (M-cycle, t-state) cost; the dispatcher accumulates them.
//
// Unhandled ED opcodes are NOP-like and default to (2, 12), matching the
// switch's `var ts = 12; var mCycles = 2` with `break` in `default`/0x00…0x3f.

extension OpcodeTableSet {

    static func buildEDTable() -> [OpcodeInfo] {
        var t = [OpcodeInfo](repeating: OpcodeInfo { _ in (2, 12) }, count: 256)

        // ---- 0x00…0x3F Z180-only: NOP (2, 12) ----
        // (left at the default)

        // ---- IN r,(C) / OUT (C),r and the 8×8 matrix ----
        let inRegs: [UInt8: (Z80) -> UInt8] = [
            0x40: { $0.B }, 0x48: { $0.C }, 0x50: { $0.D }, 0x58: { $0.E },
            0x60: { $0.H }, 0x68: { $0.L }, 0x70: { $0.A }, 0x78: { $0.A },
        ]
        for (op, _) in inRegs {
            let isC = op == 0x48 // only 0x48 writes C and must use the updated C in memptr
            t[Int(op)] = OpcodeInfo { cpu in
                let port = cpu.C
                let value = cpu.performIn(port: port, map: cpu.B)
                switch op {
                case 0x40: cpu.B = value
                case 0x48: cpu.C = value
                case 0x50: cpu.D = value
                case 0x58: cpu.E = value
                case 0x60: cpu.H = value
                case 0x68: cpu.L = value
                case 0x78: cpu.A = value
                default: break // 0x70 IN (C): value not stored
                }
                let memptrLow: UInt16 = isC ? UInt16(cpu.C) : UInt16(port)
                cpu.memptr = (UInt16(cpu.B) << 8) &+ memptrLow &+ 1
                cpu.F = cpu.preserve(cpu.carry) | cpu.sz53pv(value)
                return (2, 12)
            }
        }
        // OUT (C),r — 0x41,0x49,0x51,0x59,0x61,0x69 write r; 0x71 writes 0
        let outRegs: [UInt8: (Z80) -> UInt8] = [
            0x41: { $0.B }, 0x49: { $0.C }, 0x51: { $0.D }, 0x59: { $0.E },
            0x61: { $0.H }, 0x69: { $0.L }, 0x79: { $0.A },
        ]
        for (op, getter) in outRegs {
            t[Int(op)] = OpcodeInfo { cpu in
                let port = cpu.C
                cpu.performOut(port: port, map: cpu.B, value: getter(cpu))
                cpu.memptr = (UInt16(cpu.B) << 8) &+ UInt16(port) &+ 1
                return (2, 12)
            }
        }
        // 0x71 OUT (C),0
        t[0x71] = OpcodeInfo { cpu in
            let port = cpu.C
            cpu.performOut(port: port, map: cpu.B, value: 0x00)
            return (2, 12)
        }

        // ---- 16-bit ADC/SBC HL,rp and LD (nn),rp / LD rp,(nn) ----
        func sbchl(_ rp: @escaping (Z80) -> UInt16, flagIfZero: UInt8) -> OpcodeInfo {
            OpcodeInfo { cpu in
                cpu.memptr = cpu.HL &+ 1
                let masks = cpu.halfCarryOverflowCalculationSub16Bit(value: cpu.HL, amount: rp(cpu), carryIn: (cpu.F & cpu.carry))
                cpu.HL = masks.value
                cpu.F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (cpu.sz53(cpu.HL.highByte()) & 0xA8) | cpu.negative | (cpu.HL == 0 ? flagIfZero : 0x00)
                return (2, 15)
            }
        }
        func adchl(_ rp: @escaping (Z80) -> UInt16, flagIfZero: UInt8) -> OpcodeInfo {
            OpcodeInfo { cpu in
                cpu.memptr = cpu.HL &+ 1
                let masks = cpu.halfCarryOverflowCalculationAdd16Bit(value: cpu.HL, amount: rp(cpu), carryIn: (cpu.F & cpu.carry))
                cpu.HL = masks.value
                cpu.F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (cpu.sz53(cpu.HL.highByte()) & 0xA8) | (cpu.HL == 0 ? flagIfZero : 0x00)
                return (2, 15)
            }
        }
        t[0x42] = sbchl({ $0.BC }, flagIfZero: 0x40)
        t[0x52] = sbchl({ $0.DE }, flagIfZero: 0x50)
        t[0x62] = OpcodeInfo { cpu in // SBC HL,HL
            cpu.memptr = cpu.HL &+ 1
            let masks = cpu.halfCarryOverflowCalculationSub16Bit(value: cpu.HL, amount: cpu.HL, carryIn: (cpu.F & cpu.carry))
            cpu.HL = masks.value
            cpu.F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | cpu.sz53(cpu.HL.highByte()) | cpu.negative
            return (2, 15)
        }
        t[0x72] = sbchl({ $0.SP }, flagIfZero: 0x70)
        t[0x4A] = adchl({ $0.BC }, flagIfZero: 0x00)
        t[0x5A] = adchl({ $0.DE }, flagIfZero: 0x50)
        t[0x6A] = OpcodeInfo { cpu in // ADC HL,HL
            cpu.memptr = cpu.HL &+ 1
            let masks = cpu.halfCarryOverflowCalculationAdd16Bit(value: cpu.HL, amount: cpu.HL, carryIn: (cpu.F & cpu.carry))
            cpu.HL = masks.value
            cpu.F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (cpu.sz53(cpu.HL.highByte()) & 0xA8)
            return (2, 15)
        }
        t[0x7A] = adchl({ $0.SP }, flagIfZero: 0x00)

        func ldMem(_ rp: @escaping (Z80) -> UInt16) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let address = cpu.nextWord()
                cpu.memory.writeWord(to: address, value: rp(cpu))
                cpu.memptr = address &+ 1
                return (2, 20)
            }
        }
        func ldFromMem(_ rp: @escaping (Z80, UInt16) -> Void) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let address = cpu.nextWord()
                let value = cpu.memory.readWord(from: address)
                rp(cpu, value)
                cpu.memptr = address &+ 1
                return (2, 20)
            }
        }
        t[0x43] = ldMem({ $0.BC })
        t[0x53] = ldMem({ $0.DE })
        t[0x63] = ldMem({ $0.HL })
        t[0x73] = ldMem({ $0.SP })
        t[0x4B] = ldFromMem({ $0.BC = $1 })
        t[0x5B] = ldFromMem({ $0.DE = $1 })
        t[0x6B] = ldFromMem({ $0.HL = $1 })
        t[0x7B] = ldFromMem({ $0.SP = $1 })

        // ---- NEG (8 variants) ----
        for op in [0x44, 0x4C, 0x54, 0x5C, 0x64, 0x6C, 0x74, 0x7C] {
            t[op] = OpcodeInfo { cpu in
                let masks = cpu.carryHalfCarryOverflowCalculationSub(value: 0x00, amount: cpu.A)
                cpu.A = masks.value
                cpu.F = cpu.negative | cpu.sz53(cpu.A) | masks.carryMask | masks.halfCarryMask | masks.overflowMask
                return (2, 8)
            }
        }
        // ---- RETN (8 variants) ----
        for op in [0x45, 0x4D, 0x55, 0x5D, 0x65, 0x6D, 0x75, 0x7D] {
            t[op] = OpcodeInfo { cpu in
                cpu.PC = cpu.pop()
                cpu.iff1 = cpu.iff2
                cpu.memptr = cpu.PC
                return (2, 14)
            }
        }
        // ---- IM 0 ----
        for op in [0x46, 0x4E, 0x66, 0x6E] {
            t[op] = OpcodeInfo { cpu in cpu.interuptMode = 0; return (2, 8) }
        }
        // ---- IM 1 ----
        for op in [0x56, 0x76] {
            t[op] = OpcodeInfo { cpu in cpu.interuptMode = 1; return (2, 8) }
        }
        // ---- IM 2 ----
        for op in [0x5E, 0x7E] {
            t[op] = OpcodeInfo { cpu in cpu.interuptMode = 2; return (2, 8) }
        }
        // ---- LD I,A (mCycles 2) / LD R,A (mCycles 0) ----
        t[0x47] = OpcodeInfo { cpu in cpu.I = cpu.A; return (2, 9) }
        t[0x4F] = OpcodeInfo { cpu in cpu.R = cpu.A; return (0, 9) }
        // ---- LD A,I / LD A,R ----
        t[0x57] = OpcodeInfo { cpu in
            cpu.A = cpu.I
            cpu.F = cpu.preserve(cpu.carry) | cpu.sz53(cpu.A) | (cpu.iff2 << 2)
            return (2, 9)
        }
        t[0x5F] = OpcodeInfo { cpu in
            let bit7 = cpu.R & 0x80
            cpu.R = ((cpu.R &+ UInt8(2)) & 0x7F) | bit7
            cpu.A = cpu.R
            cpu.F = cpu.preserve(cpu.carry) | cpu.sz53(cpu.A) | (cpu.iff2 << 2)
            return (0, 9)
        }
        // ---- RRD / RLD ----
        t[0x67] = OpcodeInfo { cpu in // RRD
            let part1 = cpu.A & 0xF0
            let part2 = (cpu.A & 0x0F) << 4
            let hl = cpu.memory.read(from: cpu.HL)
            let part3 = (hl & 0xF0) >> 4
            let part4 = hl & 0x0F
            cpu.A = part1 | part4
            cpu.memory.write(to: cpu.HL, value: (part3 | part2))
            cpu.F = cpu.preserve(cpu.carry) | cpu.sz53pv(cpu.A)
            cpu.memptr = cpu.HL &+ 1
            return (2, 18)
        }
        t[0x6F] = OpcodeInfo { cpu in // RLD
            let part1 = cpu.A & 0xF0
            let part2 = (cpu.A & 0x0F)
            let hl = cpu.memory.read(from: cpu.HL)
            let part3 = (hl & 0xF0) >> 4
            let part4 = (hl & 0x0F) << 4
            cpu.A = part1 | part3
            cpu.memory.write(to: cpu.HL, value: (part4 | part2))
            cpu.F = cpu.preserve(cpu.carry) | cpu.sz53pv(cpu.A)
            cpu.memptr = cpu.HL &+ 1
            return (2, 18)
        }

        // ---- LDI/LDD ----
        func ldi(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let transferedByte = cpu.memory.read(from: cpu.HL)
                if cpu.DE >= 0x4000 && cpu.DE <= 0x57FF {
                    cpu.recordGraphicsSourceBanked(cpu.HL)
                }
                cpu.memory.write(to: cpu.DE, value: transferedByte)
                cpu.DE = dir > 0 ? cpu.DE &+ 1 : cpu.DE &- 1
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.BC = cpu.BC &- 1
                let byteFor53 = transferedByte &+ cpu.A
                cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.carry) | cpu.bits53ForCopy(byteFor53)
                return (2, 16)
            }
        }
        t[0xA0] = ldi(1)
        t[0xA8] = ldi(-1)

        // ---- CPI/CPD ----
        func cpi(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let transferedByte = cpu.memory.read(from: cpu.HL)
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.BC = cpu.BC &- 1
                let masks = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: transferedByte)
                let byteFor53 = cpu.A &- transferedByte &- (masks.halfCarryMask >> 4)
                cpu.F = cpu.preserve(cpu.carry) | masks.halfCarryMask | (cpu.sz53(masks.value) & 0xC0) | cpu.negative | cpu.bits53ForCopy(byteFor53)
                cpu.memptr = dir > 0 ? cpu.memptr &+ 1 : cpu.memptr &- 1
                return (2, 16)
            }
        }
        t[0xA1] = cpi(1)
        t[0xA9] = cpi(-1)

        // ---- INI/IND/OUTI/OUTD ----
        func ini(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let value = cpu.performIn(port: cpu.C, map: cpu.B)
                cpu.memory.write(to: cpu.HL, value: value)
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.memptr = dir > 0 ? cpu.BC &+ 1 : cpu.BC &- 1
                cpu.dec(.B)
                let bit1: UInt8 = (value & 0x80) >> 6
                let calculation: UInt8 = value &+ cpu.C &+ (dir > 0 ? 1 : 0xFF)
                let bits0And4: UInt8 = (calculation >= value ? 0x00 : 0x11)
                let parityCalculation: UInt8 = (calculation & 0x07) ^ cpu.B
                let bit2: UInt8 = cpu.parityBit[parityCalculation]
                cpu.F = cpu.sz53(cpu.B) | bits0And4 | bit1 | bit2
                return (2, 16)
            }
        }
        t[0xA2] = ini(1)
        t[0xAA] = ini(-1)

        func outi(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let value = cpu.memory.read(from: cpu.HL)
                cpu.performOut(port: cpu.C, map: cpu.B, value: value)
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.dec(.B)
                let bit1: UInt8 = (value & 0x80) >> 6
                let calculation: UInt8 = value &+ cpu.L
                let bits0And4: UInt8 = (calculation >= value ? 0x00 : 0x11)
                let parityCalculation: UInt8 = (calculation & 0x07) ^ cpu.B
                let bit2: UInt8 = cpu.parityBit[parityCalculation]
                cpu.F = cpu.sz53(cpu.B) | bits0And4 | bit1 | bit2
                cpu.memptr = dir > 0 ? cpu.BC &+ 1 : cpu.BC &- 1
                return (2, 16)
            }
        }
        t[0xA3] = outi(1)
        t[0xAB] = outi(-1)

        // ---- LDIR/LDDR ----
        func ldir(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let transferedByte = cpu.memory.read(from: cpu.HL)
                if cpu.DE >= 0x4000 && cpu.DE <= 0x57FF {
                    cpu.recordGraphicsSourceBanked(cpu.HL)
                }
                cpu.memory.write(to: cpu.DE, value: transferedByte)
                cpu.BC = cpu.BC &- 1
                let byteFor53 = transferedByte &+ cpu.A
                cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.carry) | cpu.bits53ForCopy(byteFor53)
                cpu.DE = dir > 0 ? cpu.DE &+ 1 : cpu.DE &- 1
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                if cpu.BC != 0 {
                    cpu.PC = cpu.PC &- 2
                    cpu.memptr = cpu.PC &+ 1
                    cpu.F = (cpu.F & (cpu.sign | cpu.zero | cpu.carry | cpu.parityOverflow)) | cpu.bits35FromPC(cpu.PC)
                    return (2, 21)
                } else {
                    return (2, 16)
                }
            }
        }
        t[0xB0] = ldir(1)
        t[0xB8] = ldir(-1)

        // ---- CPIR/CPDR ----
        func cpir(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let transferedByte = cpu.memory.read(from: cpu.HL)
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.BC = cpu.BC &- 1
                let masks = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: transferedByte)
                let byteFor53 = cpu.A &- transferedByte &- (masks.halfCarryMask >> 4)
                cpu.F = cpu.preserve(cpu.carry) | masks.halfCarryMask | (cpu.sz53(masks.value) & 0xC0) | cpu.negative | cpu.bits53ForCopy(byteFor53)
                if cpu.BC != 0 && cpu.A != transferedByte {
                    cpu.PC = cpu.PC &- 2
                    cpu.memptr = cpu.PC &+ 1
                    cpu.F = (cpu.F & (cpu.sign | cpu.zero | cpu.carry | cpu.parityOverflow | cpu.negative | cpu.halfCarry)) | cpu.bits35FromPC(cpu.PC)
                    return (2, 21)
                } else {
                    cpu.memptr = cpu.memptr &+ 1
                    return (2, 16)
                }
            }
        }
        t[0xB1] = cpir(1)
        t[0xB9] = cpir(-1)

        // ---- INIR/INDR ----
        func inir(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let value = cpu.performIn(port: cpu.C, map: cpu.B)
                cpu.memory.write(to: cpu.HL, value: value)
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.memptr = dir > 0 ? cpu.BC &+ 1 : cpu.BC &- 1
                cpu.dec(.B)
                let adjust = dir > 0 ? UInt16(cpu.C &+ 1) : UInt16(cpu.C &- 1)
                let sum16 = adjust &+ UInt16(value)
                let carryFlag: UInt8 = sum16 > 0xFF ? cpu.carry : 0
                let nFlag: UInt8 = (value & 0x80) >> 6
                let pvFlag: UInt8 = cpu.parityBit[UInt8(sum16 & 0x07) ^ cpu.B]
                if cpu.B != 0 {
                    cpu.PC = cpu.PC &- 2
                    let adj = cpu.blockRepeatFlagAdjustment(carryFlag: carryFlag, nFlag: nFlag, pvFlag: pvFlag, b: cpu.B, pc: cpu.PC)
                    cpu.F = (cpu.sz53(cpu.B) & (cpu.sign | cpu.zero)) | adj.bits35 | adj.h | adj.pv | nFlag | carryFlag
                    return (2, 21)
                } else {
                    cpu.F = (cpu.sz53(cpu.B) & (cpu.sign | cpu.zero)) | (cpu.B & (cpu.three | cpu.five)) | (carryFlag << 4) | pvFlag | nFlag | carryFlag
                    return (2, 16)
                }
            }
        }
        t[0xB2] = inir(1)
        t[0xBA] = inir(-1)

        // ---- OTIR/OTDR ----
        func otir(_ dir: Int) -> OpcodeInfo {
            OpcodeInfo { cpu in
                let value = cpu.memory.read(from: cpu.HL)
                cpu.performOut(port: cpu.C, map: cpu.B, value: value)
                cpu.HL = dir > 0 ? cpu.HL &+ 1 : cpu.HL &- 1
                cpu.dec(.B)
                let sum16 = UInt16(cpu.L) &+ UInt16(value)
                let carryFlag: UInt8 = sum16 > 0xFF ? cpu.carry : 0
                let nFlag: UInt8 = (value & 0x80) >> 6
                let pvFlag: UInt8 = cpu.parityBit[UInt8(sum16 & 0x07) ^ cpu.B]
                cpu.memptr = dir > 0 ? cpu.BC &+ 1 : cpu.BC &- 1
                if cpu.B != 0 {
                    cpu.PC = cpu.PC &- 2
                    let adj = cpu.blockRepeatFlagAdjustment(carryFlag: carryFlag, nFlag: nFlag, pvFlag: pvFlag, b: cpu.B, pc: cpu.PC)
                    cpu.F = (cpu.sz53(cpu.B) & (cpu.sign | cpu.zero)) | adj.bits35 | adj.h | adj.pv | nFlag | carryFlag
                    return (2, 21)
                } else {
                    cpu.F = (cpu.sz53(cpu.B) & (cpu.sign | cpu.zero)) | (cpu.B & (cpu.three | cpu.five)) | (carryFlag << 4) | pvFlag | nFlag | carryFlag
                    return (2, 16)
                }
            }
        }
        t[0xB3] = otir(1)
        t[0xBB] = otir(-1)

        // ---- 0x77, 0x7F NOP (ts 8) ----
        t[0x77] = OpcodeInfo { _ in (2, 8) }
        t[0x7F] = OpcodeInfo { _ in (2, 8) }

        return t
    }
}
