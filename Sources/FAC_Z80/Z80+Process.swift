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
        await standard()
        while shouldProcess {
//            if PC == 36794 {
//                print("Kempston Fire Pressed")
//            }

            if controller.processorSpeed == .paused {
  //               A small 'hack' to stop the processor freezing when going into a pause state.
//                Task {
//                    do{
//                        try await Task.sleep(nanoseconds: UInt64(0.001 * Double(NSEC_PER_SEC)))
//                    } catch {
//                        print("Sleep error - \(error.localizedDescription)")
//                    }
//                }
                await render()
                let _ = controller.processorSpeed
            } else {
                await preProcess()
                //Task {
                await fetchAndExecute() //   await 
                //}
                await postProcess()
            }
            
        }
        print("Process complete")
    }
    
    func render() async {
        if controller.processorSpeed != .paused {
            while frameStarted + (1.0 / Double(controller.processorSpeed.rawValue)) >= Date().timeIntervalSince1970 {
                // Idle while we wait for frame to catch up
                
            }
            frameStarted = Date().timeIntervalSince1970
            frameCompleted = false
        }
    //    if controller.processorSpeed != .unrestricted {
        await display()
     //   }
        await handleInterupt()
//        if loggingService.isLoggingProcessor {
//                   loggingService.logProcessor(message: lastPCValues.map{"\($0)"}.joined(separator: "-"))
//                   lastPCValues.removeAll()
//        }
   
    }
    
    private func handleInterupt() async {
        if controller.processorSpeed != .paused {
            if iff2 == 1 { // If IFF2 is enabled, run the selected interupt mode
                isInHaltState = false
                await push(PC)
                switch interuptMode {
                case 0:
                    PC = 0x0066 // Unused on the ZX Spectrum
                case 1:
                    PC = 0x0038
                default:
                    let intAddress = (UInt16(I) * 256) + 0xff // Assume the databus will send 0xFF as no external hardware available
                    PC = await memory.readWord(from: intAddress)
                    await controller.memoryMap?.recordJump(PC, type: .IM2)
                }
            }
        }
    }
    

    
    public func standard() async {
        await resume()
    }
    
    public func resume() async {
        print("standard")
        await invalidateTimer()
        controller.processorSpeed = .standard
    }
    public func pause() async {
            print("paused")
        await invalidateTimer()
        controller.processorSpeed = .paused
    }
    public func fast() async {
        print("turbo")
        await invalidateTimer()
        controller.processorSpeed = .turbo
    }
    
    public func unrestricted() async {
        print("unrestricted")
        await invalidateTimer()
        displayTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        displayTimer?.fire()
        controller.processorSpeed = .unrestricted
    }
    
    func invalidateTimer() async {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    @objc func fireTimer() {
     //   display()
    }
    
    public func reboot() async {
        await pause()
        shouldProcess = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Change `2.0` to the desired number of seconds.
            self.startProcess()
        }
    }
}
