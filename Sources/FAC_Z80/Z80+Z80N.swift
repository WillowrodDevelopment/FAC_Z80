import Foundation
import FAC_Common

extension Z80 {

    // MARK: - Z80N: arithmetic (all preserve flags)

    func z80nMulDE() {
        DE = UInt16(D) * UInt16(E)
    }

    func z80nAddHLA() { HL = HL &+ UInt16(A) }
    func z80nAddDEA() { DE = DE &+ UInt16(A) }
    func z80nAddBCA() { BC = BC &+ UInt16(A) }
    func z80nAddHLNN() { HL = HL &+ nextWord() }
    func z80nAddDENN() { DE = DE &+ nextWord() }
    func z80nAddBCNN() { BC = BC &+ nextWord() }

    // MARK: - Z80N: bit / shift (all preserve flags)

    func z80nSwapNib() {
        A = ((A & 0xF0) >> 4) | ((A & 0x0F) << 4)
    }

    func z80nMirrorA() {
        var a = A
        a = ((a & 0xF0) >> 4) | ((a & 0x0F) << 4)
        a = ((a & 0xCC) >> 2) | ((a & 0x33) << 2)
        a = ((a & 0xAA) >> 1) | ((a & 0x55) << 1)
        A = a
    }

    /// PIXELDN: advance HL one pixel row in the ZX screen-address layout.
    /// The FPGA extracts Y = H[4:3] ++ L[7:5] ++ H[2:0], increments it, and
    /// redistributes, preserving H[7:5] and L[4:0].
    func z80nPixelDN() {
        let h = H, l = L
        var y = (UInt16(h & 0x18) << 3) | (UInt16(l & 0xE0) >> 2) | UInt16(h & 0x07)
        y = (y + 1) & 0xFF
        H = (h & 0xE0) | UInt8((y & 0xC0) >> 3) | UInt8(y & 0x07)
        L = UInt8((y & 0x38) << 2) | (l & 0x1F)
    }

    /// PIXELAD: HL = screen address of the pixel (D = Y, E = X).
    func z80nPixelAD() {
        let y = D, x = E
        var addr: UInt16 = 0x4000
        addr |= (UInt16(y) & 0xC0) << 5 // Y bits 7-6 -> A12-A11
        addr |= (UInt16(y) & 0x07) << 8 // Y bits 2-0 -> A10-A8
        addr |= (UInt16(y) & 0x38) << 2 // Y bits 5-3 -> A7-A5
        addr |= UInt16(x) >> 3          // X bits 7-3 -> A4-A0
        HL = addr
    }

    /// SETAE: A = $80 >> (E & 7) — per-pixel mask (leftmost pixel E&7==0 -> bit 7).
    func z80nSetAE() {
        A = 0x80 >> (E & 7)
    }

    /// JP (C): PC = (PC & 0xC000) | (IN(C) << 6). The jump target comes from
    /// the byte read from the port (BC), landing on one of 256 64-byte slots.
    func z80nJPC() {
        let portValue = performIn(port: C, map: B)
        PC = (PC & 0xC000) | (UInt16(portValue) << 6)
    }

    /// TEST n: A & n -> flags only (S, Z, P/V parity, H set); A preserved.
    func z80nTest(_ n: UInt8) {
        F = halfCarry | sz53pv(A & n)
    }

    func z80nBSLA() {
        let shift = Int(B & 0x1F)
        if shift >= 16 { DE = 0 } else { DE = DE << shift }
    }

    func z80nBSRA() {
        let shift = Int(B & 0x1F)
        let sign = DE & 0x8000
        if shift == 0 { return }
        if shift >= 16 {
            DE = sign != 0 ? 0xFFFF : 0
            return
        }
        var out = DE >> shift
        if sign != 0 { out |= 0xFFFF << (16 - shift) }
        DE = out
    }

    func z80nBSRL() {
        let shift = Int(B & 0x1F)
        if shift >= 16 { DE = 0 } else { DE = DE >> shift }
    }

    func z80nBSRF() {
        let shift = Int(B & 0x1F)
        if shift == 0 { return }
        if shift >= 16 { DE = 0xFFFF; return }
        DE = (DE >> shift) | (0xFFFF << (16 - shift))
    }

    func z80nBRLC() {
        let shift = Int(B & 0x0F)
        if shift == 0 { return }
        DE = (DE << shift) | (DE >> (16 - shift))
    }

    // MARK: - Z80N: stack

    /// PUSH nn — the 16-bit immediate is big-endian (hi byte first).
    func z80nPushNN() {
        let hi = next()
        let lo = next()
        push((UInt16(hi) << 8) | UInt16(lo))
    }

    // MARK: - Z80N: block transfer (transparent blits, keyed on A)

    /// One step of LDIX: copy (HL) to (DE) unless the source byte equals A
    /// (the sprite "transparent" colour key); HL++, DE++, BC--.
    func z80nLdix() -> (m: Int, t: Int) {
        let val = memory.read(from: HL)
        if val != A { memory.write(to: DE, value: val) }
        HL = HL &+ 1
        DE = DE &+ 1
        BC = BC &- 1
        z80nBlockFlags(val)
        return (2, 16)
    }

    /// LDDX: copy (HL) to (DE) unless == A; HL advances, DE decrements.
    func z80nLddx() -> (m: Int, t: Int) {
        let val = memory.read(from: HL)
        if val != A { memory.write(to: DE, value: val) }
        HL = HL &+ 1
        DE = DE &- 1
        BC = BC &- 1
        z80nBlockFlags(val)
        return (2, 16)
    }

    /// LDWS: copy (HL) to (DE); 8-bit INC L, INC D (bitmap-row helper).
    func z80nLdws() -> (m: Int, t: Int) {
        let val = memory.read(from: HL)
        memory.write(to: DE, value: val)
        L = L &+ 1
        D = D &+ 1
        F = (F & carry) | sz53(val)
        return (2, 14)
    }

    /// LDPIRX step: copy pattern byte to (DE); source = (HL & 0xFFF8) | (DE & 7).
    /// Skip when the pattern byte equals A. DE++, BC--, HL preserved.
    func z80nLdpirx() -> (m: Int, t: Int) {
        let src = (HL & 0xFFF8) | (DE & 0x0007)
        let val = memory.read(from: src)
        if val != A { memory.write(to: DE, value: val) }
        DE = DE &+ 1
        BC = BC &- 1
        z80nBlockFlags(val)
        return (2, 16)
    }

    /// OUTINB: output (HL) to port (BC); HL++.
    func z80nOutinb() -> (m: Int, t: Int) {
        let value = memory.read(from: HL)
        performOut(port: C, map: B, value: value)
        HL = HL &+ 1
        return (2, 16)
    }

    /// Shared flag update for LDIX/LDDX/LDPIRX: N=0, H=0, P/V = (BC != 0),
    /// F3/F5 from (val + A) as classic LDI.
    func z80nBlockFlags(_ val: UInt8) {
        F = F & ~(negative | halfCarry | parityOverflow)
        if BC != 0 { F |= parityOverflow }
        let t = val &+ A
        F = (F & ~(five | three)) | (t & three) | ((t << 4) & five)
    }
}