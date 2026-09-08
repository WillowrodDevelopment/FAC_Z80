import Foundation

// MARK: - DD/FD prefix table
//
// Faithful port of the switch in Z80+DDFD_OpCodes.swift. The same 256-opcode
// table serves both DD (index = IX) and FD (index = IY); the index is bound
// when the table is built. Unhandled opcodes are NOP-like and default to
// (2, 8), matching the switch's `var ts = 8; var mCycles = 2` with `break`.

extension OpcodeTableSet {

    static func buildDDFDTable(index: Z8016BitRegister) -> [OpcodeInfo] {
        var t = [OpcodeInfo](repeating: OpcodeInfo { _ in (2, 8) }, count: 256)

        func set(_ op: Int, _ ts: Int, _ body: @escaping (Z80) -> Void) {
            t[op] = OpcodeInfo { cpu in
                body(cpu)
                return (2, ts)
            }
        }

        // ---- Index-specific 8-bit ops ----
        set(0x04, 8) { $0.inc(.B) }
        set(0x05, 8) { $0.dec(.B) }
        set(0x06, 11) { $0.B = $0.next() }
        set(0x0C, 8) { $0.inc(.C) }
        set(0x0D, 8) { $0.dec(.C) }
        set(0x0E, 11) { $0.C = $0.next() }
        set(0x14, 8) { $0.inc(.D) }
        set(0x15, 8) { $0.dec(.D) }
        set(0x16, 11) { $0.D = $0.next() }
        set(0x1C, 8) { $0.inc(.E) }
        set(0x1D, 8) { $0.dec(.E) }
        set(0x1E, 11) { $0.E = $0.next() }
        set(0x3C, 8) { $0.inc(.A) }
        set(0x3D, 8) { $0.dec(.A) }
        set(0x3E, 11) { $0.A = $0.next() }

        // ---- ADD index,rp (0x09, 0x19, 0x29, 0x39) ----
        // 0x29 adds the index register to itself (ADD IX,IX / ADD IY,IY).
        let addOps: [(Int, (Z80) -> UInt16)] = [
            (0x09, { $0.BC }),
            (0x19, { $0.DE }),
            (0x39, { $0.SP }),
        ]
        for (op, rp) in addOps {
            t[op] = OpcodeInfo { cpu in
                let indexValue = cpu.valueOfIndex(index: index)
                let addtemp = cpu.halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: rp(cpu))
                let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
                cpu.writeIndex(index, value: addtemp.value)
                cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | addtemp.halfCarryMask | carryMask | cpu.bits53(addtemp.value.highByte())
                cpu.memptr = indexValue &+ 1
                return (2, 15)
            }
        }
        t[0x29] = OpcodeInfo { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            let addtemp = cpu.halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: indexValue)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            cpu.writeIndex(index, value: addtemp.value)
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | addtemp.halfCarryMask | carryMask | cpu.bits53(addtemp.value.highByte())
            cpu.memptr = indexValue &+ 1
            return (2, 15)
        }

        // ---- LD index ops ----
        set(0x21, 14) { cpu in cpu.writeIndex(index, value: cpu.nextWord()) }
        set(0x22, 20) { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            let target = cpu.nextWord()
            cpu.memory.writeWord(to: target, value: indexValue)
            cpu.memptr = target &+ 1
        }
        set(0x23, 10) { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            cpu.writeIndex(index, value: indexValue &+ 1)
        }
        set(0x24, 8) { cpu in cpu.inc(index, isHigh: true) }
        set(0x25, 8) { cpu in cpu.dec(index, isHigh: true) }
        set(0x26, 11) { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            cpu.writeIndex(index, value: cpu.wordFrom(high: cpu.next(), low: indexValue.lowByte()))
        }
        set(0x2A, 20) { cpu in
            let target = cpu.nextWord()
            cpu.writeIndex(index, value: cpu.memory.readWord(from: target))
            cpu.memptr = target &+ 1
        }
        set(0x2B, 10) { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            cpu.writeIndex(index, value: indexValue &- 1)
        }
        set(0x2C, 8) { cpu in cpu.inc(index, isHigh: false) }
        set(0x2D, 8) { cpu in cpu.dec(index, isHigh: false) }
        set(0x2E, 11) { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            cpu.writeIndex(index, value: cpu.wordFrom(high: indexValue.highByte(), low: cpu.next()))
        }

        // ---- INC/DEC (index+d) ----
        set(0x34, 23) { cpu in
            let displacedIndex = cpu.displacedIndex(index, displacement: cpu.next())
            let masks = cpu.halfCarryOverflowCalculationAdd(value: cpu.memory.read(from: displacedIndex), amount: 0x01)
            cpu.memory.write(to: displacedIndex, value: masks.value)
            cpu.F = (cpu.F & cpu.carry) | masks.halfCarryMask | masks.overflowMask | cpu.sz53(masks.value)
        }
        set(0x35, 23) { cpu in
            let displacedIndex = cpu.displacedIndex(index, displacement: cpu.next())
            let masks = cpu.halfCarryOverflowCalculationSub(value: cpu.memory.read(from: displacedIndex), amount: 0x01)
            cpu.memory.write(to: displacedIndex, value: masks.value)
            cpu.F = (cpu.F & cpu.carry) | masks.halfCarryMask | masks.overflowMask | cpu.sz53(masks.value) | cpu.negative
        }
        set(0x36, 19) { cpu in
            let displacedIndex = cpu.displacedIndex(index, displacement: cpu.next())
            cpu.memory.write(to: displacedIndex, value: cpu.next())
        }

        // ---- LD r,r matrix (0x40-0x5F, 0x66, 0x6E, 0x78-0x7F) ----
        let ldrr = [Int](0x40...0x5F) + [0x66, 0x6E] + [Int](0x78...0x7F)
        for op in ldrr {
            let source = op & 0x07
            let target = (op >> 3) & 0x07
            t[op] = OpcodeInfo { cpu in
                let sourceValue = cpu.valueFromSource(source: UInt8(source), index: index)
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
                return (2, source == 0x06 ? 19 : 8)
            }
        }
        // ---- LD index.H, r (0x60-0x65, 0x67) ----
        for op in [Int](0x60...0x65) + [0x67] {
            let source = op & 0x07
            t[op] = OpcodeInfo { cpu in
                let indexValue = cpu.valueOfIndex(index: index)
                let sourceValue = cpu.valueFromSource(source: UInt8(source), index: index)
                cpu.writeIndex(index, value: cpu.wordFrom(high: sourceValue, low: indexValue.lowByte()))
                return (2, 8)
            }
        }
        // ---- LD index.L, r (0x68-0x6D, 0x6F) ----
        for op in [Int](0x68...0x6D) + [0x6F] {
            let source = op & 0x07
            t[op] = OpcodeInfo { cpu in
                let indexValue = cpu.valueOfIndex(index: index)
                let sourceValue = cpu.valueFromSource(source: UInt8(source), index: index)
                cpu.writeIndex(index, value: cpu.wordFrom(high: indexValue.highByte(), low: sourceValue))
                return (2, 8)
            }
        }
        // ---- LD (index+d), r (0x70-0x75, 0x77) ----
        for op in [Int](0x70...0x75) + [0x77] {
            let source = op & 0x07
            t[op] = OpcodeInfo { cpu in
                let sourceValue = cpu.valueFromSource(source: UInt8(source))
                let displacedIndex = cpu.displacedIndex(index, displacement: cpu.next())
                cpu.memory.write(to: displacedIndex, value: sourceValue)
                return (2, 19)
            }
        }

        // ---- 8-bit ALU matrix (0x80-0xBF) ----
        for op in 0x80...0xBF {
            let source = op & 0x07
            let kind = op >> 3
            t[op] = OpcodeInfo { cpu in
                let sourceValue = cpu.valueFromSource(source: UInt8(source), index: index)
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
                return (2, source == 0x06 ? 19 : 8)
            }
        }

        // ---- 0xCB → DDFDCB sub-decoder (per-M-cycle, migrated table) ----
        t[0xCB] = OpcodeInfo { cpu in
            cpu.opCodeDDFDCBWithPattern(index: index)
            return (0, 0)
        }

        // ---- 0xE1, 0xE3, 0xE5, 0xE9, 0xF9 ----
        set(0xE1, 14) { cpu in cpu.writeIndex(index, value: cpu.pop()) }
        set(0xE3, 23) { cpu in
            let indexValue = cpu.valueOfIndex(index: index)
            let value = cpu.memory.readWord(from: cpu.SP)
            cpu.writeIndex(index, value: value)
            cpu.memory.writeWord(to: cpu.SP, value: indexValue)
            cpu.memptr = value
        }
        set(0xE5, 15) { cpu in cpu.push(cpu.valueOfIndex(index: index)) }
        set(0xE9, 8) { cpu in cpu.PC = cpu.valueOfIndex(index: index) }
        set(0xF9, 10) { cpu in cpu.SP = cpu.valueOfIndex(index: index) }

        // ---- Undocumented base-set reimplementations ----
        set(0x01, 14) { $0.BC = $0.nextWord() }
        set(0x02, 11) { cpu in
            cpu.memory.write(to: cpu.BC, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: (cpu.BC.lowByte() &+ 1))
        }
        set(0x03, 10) { $0.BC.inc() }
        set(0x07, 8) { cpu in
            let carryMask: UInt8 = (cpu.A & 0x80) > 0 ? 0x01 : 0x00
            cpu.A = cpu.A << 1 | carryMask
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        set(0x08, 8) { cpu in
            let spareAF = cpu.AF
            cpu.AF = cpu.AF2
            cpu.AF2 = spareAF
        }
        set(0x0A, 11) { cpu in
            cpu.A = cpu.memory.read(from: cpu.BC)
            cpu.memptr = cpu.BC &+ 1
        }
        set(0x0B, 10) { $0.BC.dec() }
        set(0x0F, 8) { cpu in
            let carryMask: UInt8 = cpu.A & 0x01
            cpu.A = cpu.A >> 1 | (carryMask > 0 ? 0x80 : 0x00)
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        t[0x10] = OpcodeInfo { cpu in // DJNZ
            let dis = cpu.next()
            cpu.B = cpu.B &- 0x01
            if cpu.B == 0 {
                return (2, 12)
            } else {
                cpu.relativeJump(twos: dis)
                return (2, 17)
            }
        }
        set(0x11, 14) { $0.DE = $0.nextWord() }
        set(0x12, 11) { cpu in
            cpu.memory.write(to: cpu.DE, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: (cpu.DE.lowByte() &+ 1))
        }
        set(0x13, 10) { $0.DE.inc() }
        set(0x17, 8) { cpu in
            let carryMask: UInt8 = (cpu.A & 0x80) > 0 ? 0x01 : 0x00
            cpu.A = cpu.A << 1 | cpu.F & 0x01
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        set(0x18, 16) { cpu in cpu.relativeJump(twos: cpu.next()) }
        set(0x1A, 11) { cpu in
            cpu.A = cpu.memory.read(from: cpu.DE)
            cpu.memptr = cpu.DE &+ 1
        }
        set(0x1B, 10) { $0.DE.dec() }
        set(0x1F, 8) { cpu in
            let carryMask: UInt8 = cpu.A & 0x01
            cpu.A = cpu.A >> 1 | (cpu.F & 0x01 > 0 ? 0x80 : 0x00)
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow) | carryMask | cpu.bits53
        }
        t[0x20] = OpcodeInfo { cpu in // JR NZ
            let dis = cpu.next()
            if cpu.F & cpu.zero > 0 {
                return (2, 11)
            } else {
                cpu.relativeJump(twos: dis)
                return (2, 16)
            }
        }
        set(0x27, 8) { cpu in // DAA
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
        t[0x28] = OpcodeInfo { cpu in // JR Z
            let dis = cpu.next()
            if cpu.F & cpu.zero == 0 {
                return (2, 11)
            } else {
                cpu.relativeJump(twos: dis)
                return (2, 16)
            }
        }
        set(0x2F, 8) { cpu in
            cpu.A = ~cpu.A
            cpu.F = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow, cpu.carry) | cpu.bits53 | cpu.halfCarry | cpu.negative
        }
        t[0x30] = OpcodeInfo { cpu in // JR NC
            let dis = cpu.next()
            if cpu.F & cpu.carry > 0 {
                return (2, 11)
            } else {
                cpu.relativeJump(twos: dis)
                return (2, 16)
            }
        }
        set(0x31, 14) { $0.SP = $0.nextWord() }
        set(0x32, 17) { cpu in
            let target = cpu.nextWord()
            cpu.memory.write(to: target, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: (target.lowByte() &+ 1))
        }
        set(0x33, 10) { $0.SP.inc() }
        set(0x37, 8) { cpu in
            let preserved = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow)
            let fiveThree = (cpu.q == 0 ? cpu.F & 0x28 : 0x00) | (cpu.A & 0x28)
            cpu.F = preserved | cpu.carry | fiveThree
            cpu.q = cpu.F
        }
        t[0x38] = OpcodeInfo { cpu in // JR C
            let dis = cpu.next()
            if cpu.F & cpu.carry == 0 {
                return (2, 11)
            } else {
                cpu.relativeJump(twos: dis)
                return (2, 16)
            }
        }
        set(0x3A, 17) { cpu in
            let target = cpu.nextWord()
            cpu.memptr = target &+ 1
            cpu.A = cpu.memory.read(from: target)
        }
        set(0x3B, 10) { $0.SP.dec() }
        set(0x3F, 8) { cpu in
            let preserved = cpu.preserve(cpu.sign, cpu.zero, cpu.parityOverflow)
            let fiveThree = (cpu.q == 0 ? cpu.F & 0x28 : 0x00) | (cpu.A & 0x28)
            let hFlag = (cpu.F & cpu.carry) << 4
            let cFlag = hFlag > 0 ? 0x00 : cpu.carry
            cpu.F = preserved | cFlag | hFlag | fiveThree
            cpu.q = cpu.F
        }
        set(0x76, 8) { $0.isInHaltState = true }

        // ---- 0xC0–0xFF (undocumented base reimplementations) ----
        t[0xC0] = OpcodeInfo { cpu in if (cpu.F & cpu.zero) == 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xC1, 14) { $0.BC = $0.pop() }
        set(0xC2, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xC3, 14) { cpu in cpu.jump(cpu.nextWord()) }
        t[0xC4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        set(0xC5, 15) { $0.push($0.BC) }
        set(0xC6, 11) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationAdd(value: cpu.A, amount: sourceValue)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A)
        }
        set(0xC7, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x00) }
        t[0xC8] = OpcodeInfo { cpu in if (cpu.F & cpu.zero) != 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xC9, 14) { cpu in cpu.ret() }
        set(0xCA, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        t[0xCC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.zero) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        set(0xCD, 21) { cpu in
            let target = cpu.nextWord()
            cpu.push(cpu.PC)
            cpu.jump(target)
        }
        set(0xCE, 11) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationAdd(value: cpu.A, amount: sourceValue, carryIn: cpu.F & cpu.carry)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A)
        }
        set(0xCF, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x08) }
        t[0xD0] = OpcodeInfo { cpu in if (cpu.F & cpu.carry) == 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xD1, 14) { $0.DE = $0.pop() }
        set(0xD2, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xD3, 15) { cpu in
            let port = cpu.next()
            cpu.performOut(port: port, map: nil, value: cpu.A)
            cpu.memptr = cpu.wordFrom(high: cpu.A, low: port &+ 1)
        }
        t[0xD4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        set(0xD5, 15) { $0.push($0.DE) }
        set(0xD6, 11) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A) | cpu.negative
        }
        set(0xD7, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x10) }
        t[0xD8] = OpcodeInfo { cpu in if (cpu.F & cpu.carry) != 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xD9, 8) { cpu in cpu.swapBC(); cpu.swapDE(); cpu.swapHL() }
        set(0xDA, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xDB, 15) { cpu in
            let oldA = UInt16(cpu.A) << 8
            let port = cpu.next()
            cpu.A = cpu.performIn(port: port, map: cpu.A)
            cpu.memptr = oldA &+ UInt16(port) &+ 1
        }
        t[0xDC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.carry) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        t[0xDD] = OpcodeInfo { cpu in cpu.opCodeDDFD(index: index); return (0, 0) }
        set(0xDE, 11) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue, carryIn: cpu.F & cpu.carry)
            cpu.A = m.value
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | cpu.sz53(cpu.A) | cpu.negative
        }
        set(0xDF, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x18) }
        t[0xE0] = OpcodeInfo { cpu in if (cpu.F & cpu.parityOverflow) == 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xE2, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        t[0xE4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        set(0xE6, 11) { cpu in
            let sourceValue = cpu.next()
            cpu.A = cpu.A & sourceValue
            cpu.F = cpu.sz53pv(cpu.A) | cpu.halfCarry
        }
        set(0xE7, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x20) }
        t[0xE8] = OpcodeInfo { cpu in if (cpu.F & cpu.parityOverflow) != 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xEA, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xEB, 8) { cpu in
            let temp = cpu.HL
            cpu.HL = cpu.DE
            cpu.DE = temp
        }
        t[0xEC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.parityOverflow) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        t[0xED] = OpcodeInfo { cpu in cpu.opCodeED(); return (0, 0) }
        set(0xEE, 11) { cpu in
            let sourceValue = cpu.next()
            cpu.A = cpu.A ^ sourceValue
            cpu.F = cpu.sz53pv(cpu.A)
        }
        set(0xEF, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x28) }
        t[0xF0] = OpcodeInfo { cpu in if (cpu.F & cpu.sign) == 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xF1, 14) { cpu in cpu.AF = cpu.pop() }
        set(0xF2, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) == 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xF3, 8) { cpu in cpu.iff1 = 0; cpu.iff2 = 0 }
        t[0xF4] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) == 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        set(0xF5, 15) { $0.push($0.AF) }
        set(0xF6, 11) { cpu in
            let sourceValue = cpu.next()
            cpu.A = cpu.A | sourceValue
            cpu.F = cpu.sz53pv(cpu.A)
        }
        set(0xF7, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x30) }
        t[0xF8] = OpcodeInfo { cpu in if (cpu.F & cpu.sign) != 0 { cpu.ret(); return (2, 15) }; return (2, 9) }
        set(0xFA, 14) { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) != 0 { cpu.jump(target) } else { cpu.memptr = target }
        }
        set(0xFB, 8) { cpu in cpu.iff1 = 1; cpu.iff2 = 1 }
        t[0xFC] = OpcodeInfo { cpu in
            let target = cpu.nextWord()
            if (cpu.F & cpu.sign) != 0 { cpu.push(cpu.PC); cpu.jump(target); return (2, 21) }
            cpu.memptr = target
            return (2, 14)
        }
        t[0xFD] = OpcodeInfo { cpu in cpu.opCodeDDFD(index: .IY); return (0, 0) }
        set(0xFE, 11) { cpu in
            let sourceValue = cpu.next()
            let m = cpu.carryHalfCarryOverflowCalculationSub(value: cpu.A, amount: sourceValue)
            cpu.F = m.halfCarryMask | m.overflowMask | m.carryMask | (cpu.sz53(m.value) & 0xC0) | cpu.negative | cpu.bits53(sourceValue)
        }
        set(0xFF, 15) { cpu in cpu.push(cpu.PC); cpu.jump(0x38) }

        let patterns = buildDDFDPatterns()
        for op in 0..<256 { t[op].accessPattern = patterns[op] }

        return t
    }
}
