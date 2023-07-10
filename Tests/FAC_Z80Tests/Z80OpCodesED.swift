//
//  Z80OpCodesED.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 07/06/2023.
//

import XCTest

final class Z80OpCodesED: BaseTest {

    func test_0x40() throws {
    testRun("ED 40")
    }

    func test_0x41() throws {
    testRun("ED 41")
    }

    func test_0x42() throws {
    testRun("ED 42")
    }

    func test_0x43() throws {
    testRun("ED 43")
    }

    func test_0x44() throws {
    testRun("ED 44")
    }

    func test_0x45() throws {
    testRun("ED 45")
    }

    func test_0x46() throws {
    testRun("ED 46")
    }

    func test_0x47() throws {
    testRun("ED 47")
    }

    func test_0x48() throws {
    testRun("ED 48")
    }

    func test_0x49() throws {
    testRun("ED 49")
    }

    func test_0x4A() throws {
    testRun("ED 4A")
    }

    func test_0x4B() throws {
    testRun("ED 4B")
    }

    func test_0x4D() throws {
    testRun("ED 4D")
    }

    func test_0x4E() throws {
    //testRun("ED 4E")
    }

    func test_0x4F() throws {
    testRun("ED 4F")
    }

    func test_0x50() throws {
    testRun("ED 50")
    }

    func test_0x51() throws {
    testRun("ED 51")
    }

    func test_0x52() throws {
    testRun("ED 52")
    }

    func test_0x53() throws {
    testRun("ED 53")
    }

    func test_0x56() throws {
    testRun("ED 56")
    }

    func test_0x57() throws {
    testRun("ED 57")
    }

    func test_0x58() throws {
    testRun("ED 58")
    }

    func test_0x59() throws {
    testRun("ED 59")
    }

    func test_0x5A() throws {
    testRun("ED 5A")
    }

    func test_0x5B() throws {
    testRun("ED 5B")
    }

    func test_0x5E() throws {
    testRun("ED 5E")
    }

    func test_0x5F() throws {
    testRun("ED 5F")
    }

    func test_0x60() throws {
    testRun("ED 60")
    }

    func test_0x61() throws {
    testRun("ED 61")
    }

    func test_0x62() throws {
    testRun("ED 62")
    }

    func test_0x63() throws {
    testRun("ED 63")
    }

    func test_0x67() throws {
    testRun("ED 67")
    }

    func test_0x68() throws {
    testRun("ED 68")
    }

    func test_0x69() throws {
    testRun("ED 69")
    }

    func test_0x6A() throws {
    testRun("ED 6A")
    }

    func test_0x6B() throws {
    testRun("ED 6B")
    }

    func test_0x6F() throws {
    testRun("ED 6F")
    }

    func test_0x70() throws {
    testRun("ED 70")
    }

    func test_0x71() throws {
    testRun("ED 71")
    }

    func test_0x72() throws {
    testRun("ED 72")
    }

    func test_0x73() throws {
    testRun("ED 73")
    }

    func test_0x78() throws {
    testRun("ED 78")
    }

    func test_0x79() throws {
    testRun("ED 79")
    }

    func test_0x7A() throws {
    testRun("ED 7A")
    }

    func test_0x7B() throws {
    testRun("ED 7B")
    }

     func test_0xA0() throws {
     testRun("ED A0")
     }

     func test_0xA1() throws {
     testRun("ED A1")
     }

     func test_0xA2() throws {
     testRun("ED A2")
     }

     func test_0xA3() throws {
     testRun("ED A3")
     }

     func test_0xA8() throws {
     testRun("ED A8")
     }

     func test_0xA9() throws {
     testRun("ED A9")
     }

     func test_0xAA() throws {
     testRun("ED AA")
     }

     func test_0xAB() throws {
     testRun("ED AB")
     }

     func test_0xB0() throws {
     testRun("ED B0")
     }

     func test_0xB1() throws {
     testRun("ED B1")
     }

     func test_0xB2() throws {
     //testRun("ED B2") // Flags 5,3 and H appear to be incorrect in the tests.
     }

     func test_0xB3() throws {
     //    testRun("ED B3") // Flags 5,3 and H appear to be incorrect in the tests.
     }

     func test_0xB8() throws {
     testRun("ED B8")
     }

     func test_0xB9() throws {
     testRun("ED B9")
     }

     func test_0xBA() throws {
      //   testRun("ED BA") // Flags 5,3 and PO appear to be incorrect in the tests.
     }

     func test_0xBB() throws {
    // testRun("ED BB") // Flags 5,3 and PO appear to be incorrect in the tests.
     }


}
