//
//  TickProcessor.swift
//  Pods
//
//  Created by Andreas Okholm on 02/07/15.
//
//

import Foundation

let TPR = 15 // Teeth per revolution
let SAMPLE_FREQUENCY = 44100


public struct Rotation {
    public let sampleTime: Int64
    public let timeOneRotaion: Int
    public let relRotaionTime: Double
    public let heading: Float?
    public let relVelocities: [Float]
}

public struct TickTimeProcessor {
    
    struct StartProperties {
        var counter = 0
        var time = 0
        var timeLast = 0
        var startLocated = false
        var largeTooth = false
        
        mutating func updateProperties(newTime: Int) {
            counter += 1
            timeLast = time
            time = newTime
            largeTooth = isLargeTooth
            startLocated = detectStart
        }
        
        public var restart: Bool {
            return largeTooth && (counter % TPR != 0 || counter > 2*TPR)
        }
        
        private var detectStart: Bool {
            return largeTooth && counter == 2*TPR
        }
        
        private var isLargeTooth: Bool {
            // Check if time is between 120% and 140 % of last time
            let ratio = Float(time)/Float(timeLast)
            return ratio > 1.2 && ratio < 1.4
        }
    }
    
    struct RotationProperties {
        var index = -1
        // Process the tick on the opposite side of current index in order
        // for the speed of one rotation to be a good average
        var processIndex = 6
        var times = [Int](repeating: 0, count: TPR)
        var relVelocities = [Float](repeating: 0, count: TPR)
        
        var timeOneRotation = 0
        var timeOneRotationLast = 0
        
        var velocity: Float = 0
        var velocityLast: Float = 0
        
        mutating func updateProperties(time: Int) {
            velocityLast = velocity
            index = (index + 1) % TPR
            processIndex = (processIndex + 1) % TPR
            if index == 0 {
                timeOneRotationLast = timeOneRotation // At this time timeOneRotation Still reflect the rotationTimeAtIndex 14
            }
            
            timeOneRotation -= times[index]
            times[index] = time
            timeOneRotation += times[index]
            velocity = velocity(i: index)
            
            let avgVelocity = 360/Float(timeOneRotation)
            relVelocities[processIndex] = velocity(i:processIndex)/avgVelocity - 1
        }
        
        func velocity(i: Int) -> Float {
            return TickTimeProcessor.toothSize[i]/Float(times[i])
        }
        
        func velocityInRange() -> Bool {
            return fabs(velocity/velocityLast - 1) < 0.3
        }
        
        func relRotaionTime() -> Double {
            return Double(timeOneRotation)/Double(timeOneRotationLast) - 1
        }
    }
    
    public init() {}
    
    var sp = StartProperties()
    var rp = RotationProperties()
    
    var nextOutputSample: Int64 = 0
    var outputInterval: Int64 = 0
    
    static let toothSize: [Float] = (1...TPR).map {$0 < TPR ? 23.5 : 31}

    //    mutating func checkIfOutput(sampleTime: Int64) -> Bool {
    //        if sampleTime > nextOutputSample {
    //            var newNextOutputSample = nextOutputSample + outputInterval
    //            if sampleTime > newNextOutputSample {
    //                newNextOutputSample = sampleTime + outputInterval
    //            }
    //            nextOutputSample = newNextOutputSample
    //            return true
    //        }
    //        return false
    //    }
    
    
    public mutating func processTicks(ticks:[Tick], heading: Float?) -> (rotations: [Rotation], detectionErrors: Int) {
        
        var detectionErrors = 0
        var rotations = [Rotation]()
        
        func addRotation(tick: Tick) {
            
            //            if checkIfOutput(tick.time) {
            let rotation = Rotation(sampleTime: tick.time, timeOneRotaion: rp.timeOneRotation, relRotaionTime: rp.relRotaionTime(), heading: heading, relVelocities: rp.relVelocities)
            rotations.append(rotation)
            //            }
        }
        
        func reset() {
            detectionErrors += 1
            sp = StartProperties()
            rp = RotationProperties()
        }
        
        for tick in ticks {
            rp.updateProperties(time: tick.deltaTime)
            
            if !sp.startLocated {
                sp.updateProperties(newTime: tick.deltaTime)
                
                if sp.startLocated {
                    addRotation(tick: tick)
                }
                
                if sp.restart {
                    reset()
                }
            }
            else {
                if rp.velocityInRange() {
                    if rp.index == TPR - 1 {
                        addRotation(tick: tick)
                    }
                }
                else if tick.deltaTime == 7000 {
                    addRotation(tick: tick)
                    reset()
                }
                else {
                    reset()
                }
            }
        }
        
        return (rotations, detectionErrors)
    }
}
