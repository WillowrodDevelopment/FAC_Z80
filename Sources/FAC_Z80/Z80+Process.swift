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

            if controller.processorSpeed == .paused || controller.isAppInBackground {
                // Paused / backgrounded: show the static frame and idle at ~1 FPS.
                // No display() call — the last rendered frame stays on screen.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } else {
                await preProcess()
                fetchAndExecute()
                if frameBoundaryHit {
                    frameBoundaryHit = false
                    await fps()
                    await render()
                }
                await postProcess()
            }
            
        }
#if DEBUG
        print("Process complete")
#endif
    }
    
    func render() async {
        controller.frameCount += 1
        if controller.processorSpeed != .paused {
            let targetTime = frameStarted + (1.0 / Double(controller.processorSpeed.rawValue))
            let now = Date().timeIntervalSince1970
            if targetTime > now {
                let sleepNanos = UInt64((targetTime - now) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNanos)
            }
            frameStarted = Date().timeIntervalSince1970
            frameCompleted = false
        }
        // In unrestricted mode the CPU runs flat out: display is throttled to
        // ~50fps (every 20ms) so screen rendering can't become the bottleneck.
        if controller.processorSpeed == .unrestricted {
            let now = Date().timeIntervalSince1970
            if now - lastDisplayTime >= 0.02 {
                lastDisplayTime = now
                await display()
            }
        } else {
            await display()
        }
        handleInterupt()
//        if loggingService.isLoggingProcessor {
//                   loggingService.logProcessor(message: lastPCValues.map{"\($0)"}.joined(separator: "-"))
//                   lastPCValues.removeAll()
//        }
   
    }
    
    private func handleInterupt() {
        if controller.processorSpeed != .paused {
            if iff2 == 1 { // If IFF2 is enabled, run the selected interupt mode
                isInHaltState = false
                push(PC)
                switch interuptMode {
                case 0:
                    PC = 0x0066 // Unused on the ZX Spectrum
                case 1:
                    PC = 0x0038
                default:
                    let oldPC = PC
                    let intAddress = (UInt16(I) * 256) + 0xff // Assume the databus will send 0xFF as no external hardware available
                    PC = memory.readWord(from: intAddress)
                    recordJumpBanked(PC, type: .IM2, from: oldPC)
                }
            }
        }
    }
    

    
    public func standard() async {
        await resume()
    }
    
    public func resume() async {
#if DEBUG
        print("standard")
#endif
        await invalidateTimer()
        controller.breakpointHit = nil
        controller.processorSpeed = .standard
    }
    public func pause() async {
#if DEBUG
        print("paused")
#endif
        await invalidateTimer()
        controller.processorSpeed = .paused
    }
    
    public func step() async {
        guard !controller.isStepping else { return }
        controller.isStepping = true
        fetchAndExecute()
        if frameBoundaryHit {
            frameBoundaryHit = false
            await fps()
            await render()
        }
        controller.isStepping = false
        controller.processorSpeed = .paused
    }
    public func unrestricted() async {
#if DEBUG
        print("unrestricted")
#endif
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
}
