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
        await resetProcessor()
        while shouldProcess {
            if processorSpeed == .paused {
                // A small 'hack' to stop the processor freezing when going into a pause state.
                do{
                    try await Task.sleep(nanoseconds: UInt64(0.001 * Double(NSEC_PER_SEC)))
                } catch {
                    print("Sleep error - \(error.localizedDescription)")
                }
            } else {
                preProcess()
                await fetchAndExecute()
                postProcess()
            }
            
        }
        print("Process complete")
    }
    
    func render() async {
        while frameStarted + (1.0 / Double((processorSpeed.rawValue))) >= Date().timeIntervalSince1970 {
            // Idle while we wait for frame to catch up
        }
        frameStarted = Date().timeIntervalSince1970
        frameCompleted = false
        await display()
        await handleInterupt()
    }
    
    private func handleInterupt() async {
        if iff2 == 1 { // If IFF2 is enabled, run the selected interupt mode
            if isInHaltState {
                // The Z80 will only come out of halt if interupts are enabled - to 'fix' this, this halt stop can be moved out of the if statement.
                PC = PC &+ 0x01
            }
            push(PC)
            switch interuptMode {
            case 0:
                PC = 0x0066
            case 1:
                PC = 0x0038
            default:
                let intAddress = (UInt16(I) * 256) + UInt16(R)
                PC = memoryReadWord(from: intAddress)
            }
            isInHaltState = false
        }
        
    }
    
    func preProcess() {
    }
    
    func postProcess() {
        
    }
    
    
    
    public func resume() {
        print("standard")
        processorSpeed = .standard
    }
    public func pause() {
            print("paused")
        processorSpeed = .paused
    }
    public func fast() {
        print("turbo")
        processorSpeed = .turbo
    }
    public func unrestricted() {
        print("unrestricted")
        processorSpeed = .unrestricted
    }
    public func reboot() {
        shouldProcess = false
        Task{
            await process()
        }
    }

}
