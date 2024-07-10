//
//  Z80+Process.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 08/06/2023.
//

import Foundation
import FAC_Common

extension Z80 {
    public func process() {
        shouldProcess = true
        resetProcessor()
        while shouldProcess {
            if controller.processorSpeed == .paused {
  //               A small 'hack' to stop the processor freezing when going into a pause state.
//                Task {
//                    do{
//                        try await Task.sleep(nanoseconds: UInt64(0.001 * Double(NSEC_PER_SEC)))
//                    } catch {
//                        print("Sleep error - \(error.localizedDescription)")
//                    }
//                }
                render()
                let _ = controller.processorSpeed
            } else {
                preProcess()
                //Task {
                 fetchAndExecute() //   await 
                //}
                postProcess()
            }
            
        }
        print("Process complete")
    }
    
    func render() {
 //       print("FS: \(frameStarted + (1.0 / Double(processorSpeed.rawValue))) - Now: \(Date().timeIntervalSince1970) - Speed: \(processorSpeed.rawValue)")
        if controller.processorSpeed != .paused {
            while frameStarted + (1.0 / Double(controller.processorSpeed.rawValue)) >= Date().timeIntervalSince1970 {
                // Idle while we wait for frame to catch up
                
            }
            frameStarted = Date().timeIntervalSince1970
            frameCompleted = false
        }
        display()
        handleInterupt()
    }
    
    private func handleInterupt() {
        if controller.processorSpeed != .paused {
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
    }
    
    func preProcess() {
    }
    
    func postProcess() {
        
    }
    
    
    
    public func resume() {
        print("standard")
        controller.processorSpeed = .standard
    }
    public func pause() {
            print("paused")
        controller.processorSpeed = .paused
    }
    public func fast() {
        print("turbo")
        controller.processorSpeed = .turbo
    }
    public func unrestricted() {
        print("unrestricted")
        controller.processorSpeed = .unrestricted
    }
    public func reboot() {
        controller.processorSpeed = .paused
        shouldProcess = false
        Task{
            startProcess()
            controller.processorSpeed = .standard
        }
    }

}
