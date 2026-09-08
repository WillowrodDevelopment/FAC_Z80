import Foundation

// MARK: - Main 256-opcode table
//
// Faithful port of the switch in Z80+OpCodes.swift. Each entry performs the
// instruction body and returns the actual (M-cycle, t-state) cost so the
// shared epilogue accumulates and runs post-instruction hooks uniformly.
//
// Prefix opcodes (0xCB, 0xDD, 0xED, 0xFD) call their sub-decoder, which does
// its OWN accumulate; they therefore return (0, 0) exactly as the switch's
// `ts = 0; mCycles = 0` did.
//
// The matrix families (LD r,r, ADD/ADC/SUB/SBC/AND/XOR/OR/CP, RST, JP/CALL/RET
// cc) are generated programmatically from the opcode byte to keep this file
// compact and to guarantee all 256 slots are populated.

extension OpcodeTableSet {

    static func buildMainTable() -> [OpcodeInfo] {
        var t = [OpcodeInfo](repeating: OpcodeInfo { _ in (0, 0) }, count: 256)

        func set(_ op: Int, _ ts: Int, _ m: Int = 1, _ body: @escaping (Z80) -> Void) {
            t[op] = OpcodeInfo { cpu in
                body(cpu)
                return (m, ts)
            }
        }

        // ---- 0x00 NOP ----
        set(0x00, 4) { _ in }

        // ---- 0x01 LD BC,nn ----
        set(0x01, 10) { cpu in cpu.BC = cpu.nextWord() }
        // ---- 0x02 LD (BC),A ----
        set(0x02, 7) { cpu in
            cpu.memory.write(to: cpu.BC, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: (cpu.BC.lowByte() &+ 1))
        }
        set(0x03, 6) { cpu in cpu.BC.inc() }
        set(0x04, 4) { cpu in cpu.inc(.B) }
        set(0x05, 4) { cpu in cpu.dec(.B) }
        set(0x06, 7) { cpu in cpu.B = cpu.next() }
        // 0x07 RLCA
        set(0x07, 4) { cpu in
            let carryMask: UInt8 = (cpu.A & 0x80) > 0 ? 0x01 : 0x00
            cpu.A = cpu.A << 1 | carryMask
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        // 0x08 EX AF,AF'
        set(0x08, 4) { cpu in
            let spareAF = cpu.AF
            cpu.AF = cpu.AF2
            cpu.AF2 = spareAF
        }
        // 0x09 ADD HL,BC
        set(0x09, 11) { cpu in
            let addtemp = cpu.halfCarryOverflowCalculationAdd16Bit(value: cpu.HL, amount: cpu.BC)
            let carryMask: UInt8 = cpu.HL > addtemp.value ? 0x01 : 0x00
            cpu.memptr = cpu.HL &+ 1
            cpu.HL = addtemp.value
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | addtemp.halfCarryMask | carryMask | cpu.bits53OnH
        }
        set(0x0A, 7) { cpu in
            cpu.A = cpu.memory.read(from: cpu.BC)
            cpu.memptr = cpu.BC &+ 1
        }
        set(0x0B, 6) { cpu in cpu.BC.dec() }
        set(0x0C, 4) { cpu in cpu.inc(.C) }
        set(0x0D, 4) { cpu in cpu.dec(.C) }
        set(0x0E, 7) { cpu in cpu.C = cpu.next() }
        // 0x0F RRCA
        set(0x0F, 4) { cpu in
            let carryMask: UInt8 = cpu.A & 0x01
            cpu.A = cpu.A >> 1 | (carryMask > 0 ? 0x80 : 0x00)
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        // 0x10 DJNZ
        t[0x10] = OpcodeInfo { cpu in
            let dis = cpu.next()
            cpu.B = cpu.B &- 0x01
            if cpu.B == 0 {
                return (1, 8)
            } else {
                cpu.relativeJump(twos: dis)
                return (1, 13)
            }
        }
        // 0x11 LD DE,nn
        set(0x11, 10) { cpu in cpu.DE = cpu.nextWord() }
        set(0x12, 7) { cpu in
            cpu.memory.write(to: cpu.DE, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: (cpu.DE.lowByte() &+ 1))
        }
        set(0x13, 6) { cpu in cpu.DE.inc() }
        set(0x14, 4) { cpu in cpu.inc(.D) }
        set(0x15, 4) { cpu in cpu.dec(.D) }
        set(0x16, 7) { cpu in cpu.D = cpu.next() }
        // 0x17 RLA
        set(0x17, 4) { cpu in
            let carryMask: UInt8 = (cpu.A & 0x80) > 0 ? 0x01 : 0x00
            cpu.A = cpu.A << 1 | cpu.F & 0x01
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        set(0x18, 12) { cpu in cpu.relativeJump(twos: cpu.next()) }
        // 0x19 ADD HL,DE
        set(0x19, 11) { cpu in
            let addtemp = cpu.halfCarryOverflowCalculationAdd16Bit(value: cpu.HL, amount: cpu.DE)
            let carryMask: UInt8 = cpu.HL > addtemp.value ? 0x01 : 0x00
            cpu.memptr = cpu.HL &+ 1
            cpu.HL = addtemp.value
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | addtemp.halfCarryMask | carryMask | cpu.bits53OnH
        }
        set(0x1A, 7) { cpu in
            cpu.A = cpu.memory.read(from: cpu.DE)
            cpu.memptr = cpu.DE &+ 1
            cpu.recordDataBanked(cpu.DE, value8Bit: cpu.A)
        }
        set(0x1B, 6) { cpu in cpu.DE.dec() }
        set(0x1C, 4) { cpu in cpu.inc(.E) }
        set(0x1D, 4) { cpu in cpu.dec(.E) }
        set(0x1E, 7) { cpu in cpu.E = cpu.next() }
        // 0x1F RRA
        set(0x1F, 4) { cpu in
            let carryMask: UInt8 = cpu.A & 0x01
            cpu.A = cpu.A >> 1 | (cpu.F & 0x01 > 0 ? 0x80 : 0x00)
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }

        // ---- 0x20 JR NZ (7 not taken / 12 taken) ----
        t[0x20] = OpcodeInfo { cpu in
            let dis = cpu.next()
            if cpu.F & cpu.zero == 0 {
                cpu.relativeJump(twos: dis)
                return (1, 12)
            } else {
                return (1, 7)
            }
        }
        set(0x21, 10) { cpu in cpu.HL = cpu.nextWord() }
        set(0x22, 16) { cpu in
            let target = cpu.nextWord()
            cpu.memory.writeWord(to: target, value: cpu.HL)
            cpu.memptr = target &+ 1
            cpu.recordDataBanked(target, value16Bit: cpu.HL)
        }
        set(0x23, 6) { cpu in cpu.HL.inc() }
        set(0x24, 4) { cpu in cpu.inc(.H) }
        set(0x25, 4) { cpu in cpu.dec(.H) }
        set(0x26, 7) { cpu in cpu.H = cpu.next() }
        // 0x27 DAA
        set(0x27, 4) { cpu in
            var rmeml: UInt8 = 0
            var rmemh = cpu.F & 0x01
            if (cpu.F & 0x10 > 0) || (cpu.A & 0x0f > 9) { rmeml = 6 }
            if (rmemh > 0) || (cpu.A > 0x99) { rmeml |= 0x60 }
            if cpu.A > 0x99 { rmemh = 1 }
            if cpu.F & 0x02 > 0 {
                if (cpu.F & 0x10 > 0) && ((cpu.A & 0x0f) < 6) { rmemh |= 0x10 }
                cpu.A = cpu.A &- rmeml
            } else {
                if (cpu.A & 0x0f) > 9 { rmemh |= 0x10 }
                cpu.A = cpu.A &+ rmeml
            }
            cpu.F = cpu.preserve(cpu.negative) | cpu.sz53pvTable[cpu.A] | rmemh
        }
        // 0x28 JR Z (7 not taken / 12 taken)
        t[0x28] = OpcodeInfo { cpu in
            let dis = cpu.next()
            if cpu.F & cpu.zero != 0 {
                cpu.relativeJump(twos: dis)
                return (1, 12)
            } else {
                return (1, 7)
            }
        }
        // 0x29 ADD HL,HL
        set(0x29, 11) { cpu in
            let addtemp = cpu.halfCarryOverflowCalculationAdd16Bit(value: cpu.HL, amount: cpu.HL)
            let carryMask: UInt8 = cpu.HL > addtemp.value ? 0x01 : 0x00
            cpu.memptr = cpu.HL &+ 1
            cpu.HL = addtemp.value
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | addtemp.halfCarryMask | carryMask | cpu.bits53OnH
        }
        set(0x2A, 16) { cpu in
            let address = cpu.nextWord()
            cpu.HL = cpu.memory.readWord(from: address)
            cpu.memptr = address &+ 1
            cpu.recordDataBanked(address, value16Bit: cpu.HL)
        }
        set(0x2B, 6) { cpu in cpu.HL.dec() }
        set(0x2C, 4) { cpu in cpu.inc(.L) }
        set(0x2D, 4) { cpu in cpu.dec(.L) }
        set(0x2E, 7) { cpu in cpu.L = cpu.next() }
        // 0x2F CPL
        set(0x2F, 4) { cpu in
            cpu.A = ~cpu.A
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow, cpu.carry) | cpu.bits53 | cpu.halfCarry | cpu.negative
        }

        // ---- 0x30 JR NC (7 not taken / 12 taken) ----
        t[0x30] = OpcodeInfo { cpu in
            let dis = cpu.next()
            if cpu.F & cpu.carry == 0 {
                cpu.relativeJump(twos: dis)
                return (1, 12)
            } else {
                return (1, 7)
            }
        }
        set(0x31, 10) { cpu in cpu.SP = cpu.nextWord() }
        set(0x32, 13) { cpu in
            let target = cpu.nextWord()
            cpu.memory.write(to: target, value: cpu.A)
            cpu.recordDataBanked(target, value8Bit: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: (target.lowByte() &+ 1))
        }
        set(0x33, 6) { cpu in cpu.SP.inc() }
        set(0x34, 11) { cpu in
            let masks = cpu.halfCarryOverflowCalculationAdd(value: cpu.memory.read(from: cpu.HL), amount: 0x01)
            cpu.memory.write(to: cpu.HL, value: masks.value)
            cpu.recordDataBanked(cpu.HL, value8Bit: masks.value)
            cpu.F = (cpu.F & cpu.carry) | masks.halfCarryMask | masks.overflowMask | cpu.sz53(masks.value)
        }
        set(0x35, 11) { cpu in
            let masks = cpu.halfCarryOverflowCalculationSub(value: cpu.memory.read(from: cpu.HL), amount: 0x01)
            cpu.memory.write(to: cpu.HL, value: masks.value)
            cpu.recordDataBanked(cpu.HL, value8Bit: masks.value)
            cpu.F = (cpu.F & cpu.carry) | masks.halfCarryMask | masks.overflowMask | cpu.sz53(masks.value) | cpu.negative
        }
        set(0x36, 10) { cpu in
            let nxt = cpu.next()
            cpu.memory.write(to: cpu.HL, value: nxt)
        }
        // 0x37 SCF
        set(0x37, 4) { cpu in
            let preserved = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow)
            let fiveThree = (cpu.q == 0 ? cpu.F & 0x28 : 0x00) | (cpu.A & 0x28)
            cpu.F = preserved | cpu.carry | fiveThree
            cpu.q = cpu.F
        }
        // 0x38 JR C (7 not taken / 12 taken)
        t[0x38] = OpcodeInfo { cpu in
            let dis = cpu.next()
            if cpu.F & cpu.carry != 0 {
                cpu.relativeJump(twos: dis)
                return (1, 12)
            } else {
                return (1, 7)
            }
        }
        // 0x39 ADD HL,SP
        set(0x39, 11) { cpu in
            let addtemp = cpu.halfCarryOverflowCalculationAdd16Bit(value: cpu.HL, amount: cpu.SP)
            let carryMask: UInt8 = cpu.HL > addtemp.value ? 0x01 : 0x00
            cpu.memptr = cpu.HL &+ 1
            cpu.HL = addtemp.value
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | addtemp.halfCarryMask | carryMask | cpu.bits53OnH
        }
        set(0x3A, 13) { cpu in
            let target = cpu.nextWord()
            cpu.memptr = target &+ 1
            cpu.A = cpu.memory.read(from: target)
            cpu.recordDataBanked(target, value8Bit: cpu.A)
        }
        set(0x3B, 6) { cpu in cpu.SP.dec() }
        set(0x3C, 4) { cpu in cpu.inc(.A) }
        set(0x3D, 4) { cpu in cpu.dec(.A) }
        set(0x3E, 7) { cpu in cpu.A = cpu.next() }
        // 0x3F CCF
        set(0x3F, 4) { cpu in
            let preserved = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow)
            let fiveThree = (cpu.q == 0 ? cpu.F & 0x28 : 0x00) | (cpu.A & 0x28)
            let hFlag = (cpu.F & cpu.carry) << 4
            let cFlag = hFlag > 0 ? 0x00 : cpu.carry
            cpu.F = preserved | cFlag | hFlag | fiveThree
            cpu.q = cpu.F
        }

        // ---- 0x40–0x6F, 0x78–0x7F LD r,r (no recordDataBanked) ----
        for op in (0x40...0x6F).map({ $0 }) + (0x78...0x7F).map({ $0 }) {
            let source = op & 0x07
            let target = (op >> 3) & 0x07
            t[op] = OpcodeInfo { cpu in
                let sourceValue = cpu.valueFromSource(source: UInt8(source))
                switch target {
                case 0: cpu.B = sourceValue
                case 1: cpu.C = sourceValue
                case 2: cpu.D = sourceValue
                case 3: cpu.E = sourceValue
                case 4: cpu.H = sourceValue
                case 5: cpu.L = sourceValue
                case 6: cpu.memory.write(to: cpu.HL, value: sourceValue)
                default: cpu.A = sourceValue
                }
                let ts = source == 0x06 ? 7 : 4
                return (1, ts)
            }
        }

        // ---- 0x70–0x75, 0x77 LD (HL),r / LD (HL),A ----
        for op in [0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x77] {
            let source = op & 0x07
            let target = (op >> 3) & 0x07
            t[op] = OpcodeInfo { cpu in
                let sourceValue = cpu.valueFromSource(source: UInt8(source))
                switch target {
                case 6: cpu.memory.write(to: cpu.HL, value: sourceValue)
                default:
                    cpu.A = sourceValue
                    if source == 0x07 {
                        cpu.recordDataBanked(cpu.HL, value8Bit: cpu.A)
                    }
                }
                return (1, 7)
            }
        }

        // 0x76 HALT
        t[0x76] = OpcodeInfo { cpu in
            cpu.isInHaltState = true
            return (1, 4)
        }

        // ---- 0x80–0xBF 8-bit ALU ----
        for op in 0x80...0xBF {
            let source = op & 0x07
            let kind = op >> 3  // 0x10..0x17 = ADD, 0x18.. ADC, 0x20 SUB, 0x28 SBC, 0x30 AND, 0x38 XOR, 0x40 OR, 0x48 CP
            t[op] = OpcodeInfo { cpu in
                let sourceValue = cpu.valueFromSource(source: UInt8(source))
                switch kind {
                case 0x10: // ADD
                    let m = cpu.carryHalfCarryOverflowCalculationAdd(value: cpu.A, amount: sourceValue)
                    cpu.A = m.value
                    cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A)
                case 0x11: // ADC
                    let m = cpu.carryHalfCarryOverflowCalculationAdd(value: cpu.A, amount: sourceValue, carryIn: cpu.F & cpu.carry)
                    cpu.A = m.value
                    cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A)
                case 0x12: // SUB
                    let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue)
                    cpu.A = m.value
                    cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A) | cpu.negative
                case 0x13: // SBC
                    let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue, carryIn: cpu.F & cpu.carry)
                    cpu.A = m.value
                    cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A) | cpu.negative
                case 0x14: // AND
                    cpu.A = cpu.A & sourceValue
                    cpu.F = cpu.sz53pv(cpu.A) | cpu.halfCarry
                case 0x15: // XOR
                    cpu.A = cpu.A ^ sourceValue
                    cpu.F = cpu.sz53pv(cpu.A)
                case 0x16: // OR
                    cpu.A = cpu.A | sourceValue
                    cpu.F = cpu.sz53pv(cpu.A)
                default: // CP
                    let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue)
                    cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | (cpu.sz53(m.value) & 0xC0) | cpu.negative | cpu.bits53(sourceValue)
                }
                let ts = source == 0x06 ? 7 : 4
                return (1, ts)
            }
        }

        // 0xC0 RET NZ (5 not taken / 11 taken)
        t[0xC0] = OpcodeInfo { cpu in
            if (cpu.F & cpu.zero) == 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xC1, 10) { cpu in cpu.BC = cpu.pop() }
        set(0xC2, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xC3, 10) { cpu in cpu.jump(cpu.nextWord()) }
        // 0xC4 CALL NZ (10 not taken / 17 taken)
        t[0xC4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        set(0xC5, 11) { cpu in cpu.push(cpu.BC) }
        set(0xC6, 7) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationAdd(value: cpu.A, amount: sourceValue)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A)
        }
        set(0xC7, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x00) }
        // 0xC8 RET Z
        t[0xC8] = OpcodeInfo { cpu in
            if (cpu.F & cpu.zero) != 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xC9, 10) { cpu in cpu.ret() }
        set(0xCA, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        // 0xCB → CB sub-decoder (self-accumulates) → (0,0)
        t[0xCB] = OpcodeInfo { cpu in
            cpu.opCodeCB()
            return (0, 0)
        }
        // 0xCC CALL Z
        t[0xCC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        set(0xCD, 17) { cpu in
            let target = cpu.nextWord()
            cpu.push(cpu.PC)
            cpu.jump(target)
        }
        set(0xCE, 7) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationAdd(value: cpu.A, amount: sourceValue, carryIn: cpu.F & cpu.carry)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A)
        }
        set(0xCF, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x08) }

        // ---- 0xD0–0xDF ----
        // 0xD0 RET NC
        t[0xD0] = OpcodeInfo { cpu in
            if (cpu.F & cpu.carry) == 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xD1, 10) { cpu in cpu.DE = cpu.pop() }
        set(0xD2, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xD3, 11) { cpu in
            let port = cpu.next()
            cpu.performOut(port: port, map: nil, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: port &+ 1)
        }
        // 0xD4 CALL NC
        t[0xD4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        set(0xD5, 11) { cpu in cpu.push(cpu.DE) }
        set(0xD6, 7) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A) | cpu.negative
        }
        set(0xD7, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x10) }
        // 0xD8 RET C
        t[0xD8] = OpcodeInfo { cpu in
            if (cpu.F & cpu.carry) != 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xD9, 4) { cpu in cpu.swapBC(); cpu.swapDE(); cpu.swapHL() }
        set(0xDA, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xDB, 11) { cpu in
            let oldA = UInt16(cpu.A) << 8
            let port = cpu.next()
            cpu.A = cpu.performIn(port: port, map: cpu.A)
            cpu.memptr = oldA &+ UInt16(port) &+ 1
        }
        // 0xDC CALL C
        t[0xDC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        // 0xDD → DD/FD sub-decoder (IX, migrated table), self-accumulates → (0,0)
        t[0xDD] = OpcodeInfo { cpu in
            cpu.opCodeDDFDViaTable(index: .IX)
            return (0, 0)
        }
        set(0xDE, 7) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue, carryIn: cpu.F & cpu.carry)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A) | cpu.negative
        }
        set(0xDF, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x18) }

        // ---- 0xE0–0xEF ----
        // 0xE0 RET PO
        t[0xE0] = OpcodeInfo { cpu in
            if (cpu.F & cpu.parityOverflow) == 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xE1, 10) { cpu in cpu.HL = cpu.pop() }
        set(0xE2, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xE3, 19) { cpu in
            let temp = cpu.HL
            cpu.HL = cpu.memory.readWord(from: cpu.SP)
            cpu.memory.writeWord(to: cpu.SP, value: temp)
            cpu.memptr = cpu.HL
        }
        // 0xE4 CALL PO
        t[0xE4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        set(0xE5, 11) { cpu in cpu.push(cpu.HL) }
        set(0xE6, 7) { cpu in
            let sourceValue = cpu.next()
            cpu.A = cpu.A & sourceValue
            cpu.F = cpu.sz53pv(cpu.A) | cpu.halfCarry
        }
        set(0xE7, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x20) }
        // 0xE8 RET PE
        t[0xE8] = OpcodeInfo { cpu in
            if (cpu.F & cpu.parityOverflow) != 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xE9, 4) { cpu in cpu.PC = cpu.HL }
        set(0xEA, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xEB, 4) { cpu in
            let temp = cpu.HL
            cpu.HL = cpu.DE
            cpu.DE = temp
        }
        // 0xEC CALL PE
        t[0xEC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        // 0xED → ED sub-decoder (migrated table), self-accumulates → (0,0)
        t[0xED] = OpcodeInfo { cpu in
            cpu.opCodeEDViaTable()
            return (0, 0)
        }
        set(0xEE, 7) { cpu in
            let sourceValue = cpu.next()
            cpu.A = cpu.A ^ sourceValue
            cpu.F = cpu.sz53pv(cpu.A)
        }
        set(0xEF, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x28) }

        // ---- 0xF0–0xFF ----
        // 0xF0 RET P
        t[0xF0] = OpcodeInfo { cpu in
            if (cpu.F & cpu.sign) == 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xF1, 10) { cpu in cpu.AF = cpu.pop() }
        set(0xF2, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xF3, 4) { cpu in cpu.iff1 = 0; cpu.iff2 = 0; cpu.eiDeferred = false }
        // 0xF4 CALL P
        t[0xF4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        set(0xF5, 11) { cpu in cpu.push(cpu.AF) }
        set(0xF6, 7) { cpu in
            let sourceValue = cpu.next()
            cpu.A = cpu.A | sourceValue
            cpu.F = cpu.sz53pv(cpu.A)
        }
        set(0xF7, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x30) }
        // 0xF8 RET M
        t[0xF8] = OpcodeInfo { cpu in
            if (cpu.F & cpu.sign) != 0 { cpu.ret(); return (1, 11) }
            return (1, 5)
        }
        set(0xF9, 6) { cpu in cpu.SP = cpu.HL }
        set(0xFA, 10) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xFB, 4) { cpu in cpu.iff1 = 1; cpu.iff2 = 1; cpu.eiDeferred = true }
        // 0xFC CALL M
        t[0xFC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (1, 17) }
            cpu.memptr = target
            return (1, 10)
        }
        // 0xFD → DD/FD sub-decoder (IY, migrated table), self-accumulates → (0,0)
        t[0xFD] = OpcodeInfo { cpu in
            cpu.opCodeDDFDViaTable(index: .IY)
            return (0, 0)
        }
        set(0xFE, 7) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue)
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | (cpu.sz53(m.value) & 0xC0) | cpu.negative | cpu.bits53(sourceValue)
        }
        set(0xFF, 11) { cpu in cpu.push(cpu.PC); cpu.jump(0x38) }

        let patterns = buildMainPatterns()
        for op in 0..<256 {
            t[op].accessPattern = patterns[op]
        }

        return t
    }
}
