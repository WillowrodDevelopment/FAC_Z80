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
                serviceInterrupts()
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
        // Fallback: guarantee the maskable INT fires once per frame even if no
        // instruction boundary landed inside the INT window. The primary path
        // is per-instruction in serviceInterrupts().
        if !intServicedThisFrame && iff1 == 1 && controller.processorSpeed != .paused {
            intServicedThisFrame = true
            serviceMaskableInterrupt()
        }
//        if loggingService.isLoggingProcessor {
//                   loggingService.logProcessor(message: lastPCValues.map{"\($0)"}.joined(separator: "-"))
//                   lastPCValues.removeAll()
//        }
   
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
        serviceInterrupts()
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
