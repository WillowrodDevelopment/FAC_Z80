//
//  BaseTest.swift
//  Fake-A-ChipTests
//
//  Created by Mike Hall on 26/05/2023.
//

import XCTest
import FAC_Z80
import FAC_Common

class BaseTest: XCTestCase {

    let baseURL = "https://raw.githubusercontent.com/raddad772/jsmoo/main/misc/tests/GeneratedTests/z80/v1/"
    
    let expectation = XCTestExpectation(description: "Open a file asynchronously.")
    let z80 = Z80()
    let decoder = JSONDecoder()
    override func setUpWithError() throws {
        z80.resetProcessor()

    }

    func loadJson(_ testID: String) async {
        //let filename = getPath(forFile: "\(testID).json")
        let t = type(of: self)
        let bundle = Bundle(for: t.self)
        print("testBundle.bundlePath = \(bundle.bundlePath) ")
        guard
            let path = Bundle.main.path(forResource: testID, ofType: "json")
                // let path = bundle.path(forResource: testID, ofType: "json")
        else {
            XCTFail("Could not find \(testID)")
            return
        }
//        if let filePath = Bundle.main.path(forResource: testID, ofType: "json") {
            print("\(testID).json found in \(path)?")
            do {
                guard let data = try? Data(contentsOf: URL(string: path)!) else {
                    print("Failed to read data")
                    return
                }
                let json = try JSONDecoder().decode([TestModel].self, from: data) //JSONEncoder().encode(self)
                await executeTest(json)
                
            } catch {
                print("Something bad happened.... \(error.localizedDescription)")
            }
//        } else {
//            XCTFail("Could not find \(testID).json")
//        }
//        if let url = URL(string: "\(baseURL)\(testID).json"){
//                do {
//                    print("URL: \(url.absoluteString)")
//                    let (data, _) = try await URLSession.shared.data(from: url)
//                    let decoder = JSONDecoder()
//                    let model = try decoder.decode([TestModel].self, from: data)
//                    await executeTest(model)
//                } catch {
//                    print("Error processing test \(testID): \(error.localizedDescription)")
//                }
//           // return try decoder.decode([TestModel].self, from: data)
//        } else {
//            XCTFail("Could not find \(testID).json")
//        }
        
       // return []
    }

    func testRun(_ testID: String) {
        
        Task {
            await loadJson(testID.lowercased().replacingOccurrences(of: " ", with: "%20"))
            
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 60.0)
    }
    
    func executeTest(_ models: [TestModel]) async {
        print("Running tests")
        models.forEach { model in
            setUpTest(model.initial, ports: model.ports)
            z80.fetchAndExecute()
            do {
               try checkTestResult(model)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func checkTestResult(_ model: TestModel) throws {
        let state = model.final
        let initial = model.initial
        XCTAssert(z80.A == state.a)
        if (z80.A != state.a) {
            print("A should be \(state.a.bin()) but is \(z80.A.bin()) (was A \(initial.a.bin()) F \(initial.f.bin()))")
        }
        XCTAssert(z80.B == state.b)
        if (z80.B != state.b) {
            print("B was \(initial.b.bin()) is \(z80.B.bin()) should be \(initial.b.bin()))")
        }
        XCTAssert(z80.C == state.c)
        if (z80.C != state.c) {
            print("C was \(initial.c.bin()) is \(z80.C.bin()) should be \(initial.c.bin()))")
        }
        XCTAssert(z80.D == state.d)
        if (z80.D != state.d) {
            print("D was \(initial.d.bin()) is \(z80.D.bin()) should be \(initial.d.bin()))")
        }
        XCTAssert(z80.E == state.e)
        if (!model.name.starts(with: "37") && !model.name.starts(with: "3F") && !model.name.starts(with: "ED B")){ // Do not test bits 3 & 5 for these tests
            XCTAssert(z80.F == state.f)
            if (z80.F != state.f) {
                print("F was \(initial.f.bin()) is \(z80.F.bin()) should be \(state.f.bin())) - \(model.name)")
//                print("\(model.name) - F should be \(state.f.bin()) but is \(z80.F.bin()) (was F \(initial.f.bin()) B \(initial.b.bin()) is B \(z80.B.bin()) should be B \(state.b.bin()))")
            }
        } else {
            XCTAssert((z80.F | 0x28) == (state.f | 0x28))
            if ((z80.F | 0x28) != (state.f | 0x28)) {
                print("\(model.name) - F should be \(state.f.bin()) but is \(z80.F.bin()) (was F \(initial.f.bin()) A \(initial.a.bin()) is A \(state.a.bin()))")
            }
        }
        XCTAssert(z80.H == state.h)
        if (z80.H != state.h) {
            print("H was \(initial.h.bin()) is \(z80.H.bin()) should be \(initial.h.bin()))")
        }
        XCTAssert(z80.L == state.l)
        if (z80.L != state.l) {
            print("L was \(initial.l.bin()) is \(z80.L.bin()) should be \(initial.l.bin()))")
        }
        XCTAssert(z80.BC2 == state.bc_)
        if (z80.BC2 != state.bc_) {
            print("BC2 was \(initial.bc_.bin()) is \(z80.BC2.bin()) should be \(initial.bc_.bin()))")
        }
        XCTAssert(z80.DE2 == state.de_)
        if (z80.DE2 != state.de_) {
            print("DE2 was \(initial.de_.bin()) is \(z80.DE2.bin()) should be \(initial.de_.bin()))")
        }
        XCTAssert(z80.AF2 == state.af_)
        if (z80.AF2 != state.af_) {
            print("AF2 was \(initial.af_.bin()) is \(z80.AF2.bin()) should be \(initial.af_.bin()))")
        }
        XCTAssert(z80.HL2 == state.hl_)
        if (z80.HL2 != state.hl_) {
            print("HL2 was \(initial.hl_.bin()) is \(z80.HL2.bin()) should be \(initial.hl_.bin()))")
        }
        XCTAssert(z80.I == state.i)
        if (z80.I != state.i) {
            print("I was \(initial.i.bin()) is \(z80.I.bin()) should be \(initial.i.bin()))")
        }
        XCTAssert(z80.R == state.r)
        if (z80.R != state.r) {
            print("R should be \(state.r) but is \(z80.R) - \(model.name)")
        }
        XCTAssert(z80.PC == state.pc)
        if (z80.PC != state.pc) {
            print("PC should be \(state.pc) but is \(z80.PC) (was PC \(initial.pc) F \(initial.f.bin()))")
        }
        XCTAssert(z80.SP == state.sp)
        if (z80.SP != state.sp) {
            print("SP should be \(state.sp) but is \(z80.SP) (was SP \(initial.sp) F \(initial.f.bin())) - \(model.name)")
        }
        XCTAssert(z80.IX == state.ix)
        if (z80.IX != state.ix) {
            print("IX should be \(state.ix) but is \(z80.IX) (was IX \(initial.ix) F \(initial.f.bin())) - \(model.name)")
        }
        XCTAssert(z80.IY == state.iy)
        if (z80.IY != state.iy) {
            print("IY should be \(state.iy) but is \(z80.IY) (was IY \(initial.iy) F \(initial.f.bin())) - \(model.name)")
        }
        XCTAssert(z80.memptr == state.wz)
        if (z80.memptr != state.wz) {
            print("memptr should be \(state.wz) but is \(z80.memptr) (was memptr \(initial.wz) F \(initial.f.bin())) - \(model.name)")
        }
        XCTAssert(z80.interuptMode == state.im)
        if (z80.interuptMode != state.im) {
            print("interuptMode should be \(state.im) but is \(z80.interuptMode) (was interuptMode \(initial.im) F \(initial.f.bin())) - \(model.name)")
        }

        XCTAssert(z80.iff1 == state.iff1)
        if (z80.iff1 != state.iff1) {
            print("iff1 should be \(state.iff1) but is \(z80.iff1) (was iff1 \(initial.iff1) F \(initial.f.bin())) - \(model.name)")
        }

        XCTAssert(z80.iff2 == state.iff2)
        if (z80.iff2 != state.iff2) {
            print("iff2 should be \(state.iff2) but is \(z80.iff2) (was iff2 \(initial.iff2) F \(initial.f.bin())) - \(model.name)")
        }


        if let ports = model.ports {
            ports.forEach { port in
                if port[2].fetchString() == "w" {
                    let targetPort = port[0].fetchUInt16().lowByte()
                    z80.hardwarePorts.writeSinglePort(port: targetPort, value: port[1].fetchUInt8())   //activeHardwarePorts[String(targetPort)] = port[1].fetchUInt8()
                }
            }
        }

        state.ram.forEach { item in
            let ramAddress = item[0]
            let ramValue = item[1]
            XCTAssert(z80.ram[0][ramAddress] == UInt8(ramValue))
            if z80.ram[0][item[0]] != UInt8(item[1]) {
                print("Mem at \(item[0]) should be \(item[1]) but is \(z80.ram[item[0]])")
            }
        }

    }

    func setUpTest(_ state: TestState, ports: [[Port]]? = nil) {

        z80.A = state.a
        z80.B = state.b
        z80.C = state.c
        z80.D = state.d
        z80.E = state.e
        z80.F = state.f
        z80.H = state.h
        z80.L = state.l
        z80.BC2 = state.bc_
        z80.DE2 = state.de_
        z80.AF2 = state.af_
        z80.HL2 = state.hl_
        z80.I = state.i
        z80.R = state.r
        z80.PC = state.pc
        z80.SP = state.sp
        z80.IX = state.ix
        z80.IY = state.iy
        z80.interuptMode = state.im
        z80.iff1 = state.iff1
        z80.iff2 = state.iff2
        z80.interuptsEnabled = (state.ei == 1)

        z80.modified53 = state.q > 0

        z80.memptr = state.wz

        if let ports {
            ports.forEach { port in
                if port[2].fetchString() == "r" {
                    let targetPort = port[0].fetchUInt16()
                    
                    z80.hardwarePorts.writeSinglePort(port: UInt8(targetPort), value: port[1].fetchUInt8())
                    //z80.activeHardwarePorts[targetPort.hex()] = port[1].fetchUInt8()
                }
            }
        }
        state.ram.forEach { item in
            let ramAddress = item[0]
            let ramValue = item[1]
            z80.ram[0][ramAddress] = UInt8(ramValue)
            //z80.memory[item[0]] = UInt8(item[1])
        }


            z80.tStates = 0
    }


}
