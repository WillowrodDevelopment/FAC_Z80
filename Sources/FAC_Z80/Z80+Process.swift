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
        standard()
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
        if controller.processorSpeed != .paused {
            while frameStarted + (1.0 / Double(controller.processorSpeed.rawValue)) >= Date().timeIntervalSince1970 {
                // Idle while we wait for frame to catch up
                
            }
            frameStarted = Date().timeIntervalSince1970
            frameCompleted = false
        }
    //    if controller.processorSpeed != .unrestricted {
            display()
     //   }
        handleInterupt()
        if loggingService.isLoggingProcessor {
                   loggingService.logProcessor(message: lastPCValues.map{"\($0)"}.joined(separator: "-"))
                   lastPCValues.removeAll()
        }
   
    }
    
    private func handleInterupt() {
        if controller.processorSpeed != .paused {
            if iff2 == 1 { // If IFF2 is enabled, run the selected interupt mode
                isInHaltState = false
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
            }
        }
    }
    
    func preProcess() {
        if PC >= 0xF66C && PC <= 0xF68E {
            loggingService.log("Reading: \(PC.hex())")
        }
    }
    
    func postProcess() {
        
    }
    
    public func standard() {
        resume()
    }
    
    public func resume() {
        print("standard")
        invalidateTimer()
        controller.processorSpeed = .standard
    }
    public func pause() {
            print("paused")
        invalidateTimer()
        controller.processorSpeed = .paused
    }
    public func fast() {
        print("turbo")
        invalidateTimer()
        controller.processorSpeed = .turbo
    }
    
    public func unrestricted() {
        print("unrestricted")
        invalidateTimer()
        displayTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        displayTimer?.fire()
        controller.processorSpeed = .unrestricted
    }
    
    func invalidateTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    @objc func fireTimer() {
     //   display()
    }
    
    public func reboot() {
        pause()
        shouldProcess = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Change `2.0` to the desired number of seconds.
            self.startProcess()
        }
    }

}
