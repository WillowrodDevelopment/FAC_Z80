//
//  Z80+Process.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 08/06/2023.
//

import Foundation
import FAC_Common

extension Z80 {
    public func process() async {
        shouldProcess = true
        resetProcessor()
        while shouldProcess {
            if isInHaltState {
                mCyclesAndTStates(m: 0, t: 4)
            } else if processorSpeed != .paused {
                preProcess()
                fetchAndExecute()
                postProcess()
            }
            
        }
    }
    
    func render() {
        // To run at 50 FPS we should allow the processor to 'catch up' every frame.
        // TODO: Add clause to run unlimited
        while frameStarted + (1.0 / Double((processorSpeed.rawValue))) >= Date().timeIntervalSince1970 {
        }
        frameStarted = Date().timeIntervalSince1970
        frameCompleted = false
        //fps()
        display()
        handleInterupt()
    }
    
    private func handleInterupt() {
        if iff2 == 1 { // If IFF2 is enabled, run the selected interupt mode
            
            push(PC)
            switch interuptMode {
            case 0:
                PC = 0x0066
            case 1:
                PC = 0x0038
            default:
                let intAddress = (UInt16(I) * 256) + UInt16(R)
                PC = memoryReadWord(from: intAddress)
                if miscDebug {
                    print("IM2 triggered at \(intAddress.hex()) and processes from \(PC.hex())")
                }
                
            }
            isInHaltState = false
        }
        
    }
    
    func preProcess() {
    }
    
    func postProcess() {
        
    }
    

}
