//
//  SampleProcessor.swift
//  Pods
//
//  Created by Andreas Okholm on 25/06/15.
//
//

import Foundation

enum AvgState {
    case DetectHigh
    case DetectLow
    case NotValid
}

enum DiffState {
    case DetectRising
    case DetectOpen
    case DetectFalling
    case Pause
    case DetectDrop
}

public struct Tick {
    public let time: Int64
    public let deltaTime: Int
}

public struct AudioSampleProcessor { // Audio Sample Processor State
    
    // Should be reset on each Tick
    struct TickProperties {
        var avgState = AvgState.DetectHigh
        var diffState = DiffState.DetectRising
        var samplesSinceTick = 0
        
        var avgPositive = false
        var diffFullOpen = false
        
        // One time set
        var gapBlock = 0
        var diffRiseThreshold = 0
        var avgDropHalf = 0
        
        // Running set
        var avgGapMax = 0
        var avgMax = 0
        var diffMax = 0
        var avgOpenMin = 0
    }
    
    // Updating on each tick
    struct FilteredValues {
        var avgMax = Int(INT16_MAX)
        var diffMax = Int(2*INT16_MAX)
        var diffGap = Int(1100) // updated under the diff state cycle
        var avgOpenMin = Int(INT16_MIN/2)
        var avgClosedMax = Int(0)
        
        static func updateVal( val: inout Int, newVal: Int) {
            val = (7*val + 3*newVal)/10
        }
    }
    
    // Primary running variables
    var avgBuffer = [Int](repeating: 0, count: 3)
    var avg = 0
    var diffBuffer = [Int](repeating: 0, count: 3)
    var diff = 0
    var bufferIndex = 0
    
    var tf = FilteredValues()
    var tp = TickProperties()
    
    public init() {
        
    }
    
    mutating func updateRunningStats(sample:Int) {
        // updateing primary statistics
        let bufferIndexLast = (bufferIndex + 2) % 3
        avg -= avgBuffer[bufferIndex]
        diff -= diffBuffer[bufferIndex]
        
        diffBuffer[bufferIndex] = abs(sample - avgBuffer[bufferIndexLast])
        avgBuffer[bufferIndex] = sample
        
        avg += avgBuffer[bufferIndex]
        diff += diffBuffer[bufferIndex]
        
        // next buffer index
        bufferIndex = (bufferIndex + 1) % 3
        
        tp.samplesSinceTick += 1
        
        // updating max/min values for current tick
        tp.avgMax = max(tp.avgMax, avg)
        tp.diffMax = max(tp.diffMax, diff)
        
        if tp.diffState == .DetectRising || tp.diffState == .DetectOpen {
            tp.avgOpenMin = min(tp.avgOpenMin, avg)
        }
        
        if tp.diffState == .DetectDrop {
            tp.avgGapMax = max(tp.avgGapMax, avg)
        }
    }
    
    mutating func updateFilteredValues() {
        FilteredValues.updateVal(val: &tf.avgMax, newVal: tp.avgMax)
        FilteredValues.updateVal(val: &tf.diffMax, newVal: tp.diffMax)
        FilteredValues.updateVal(val: &tf.avgOpenMin, newVal: tp.avgOpenMin)
        FilteredValues.updateVal(val: &tf.avgClosedMax, newVal: tp.avgGapMax)
    }
    
    mutating func updateStateAvg() -> Bool {
        switch tp.avgState {
        case .DetectHigh:
            if tp.samplesSinceTick < 60 {
                if avg*2 > tf.avgMax { tp.avgState = .DetectLow}
            }
            else {
                tp.avgState = .NotValid
            }
        case .DetectLow:
            if tp.samplesSinceTick < 90 {
                if avg*2 < tp.avgOpenMin && tf.avgMax + tp.avgOpenMin < 0 {
                    return true
                }
            }
            else {
                tp.avgState = .NotValid
            }
        case .NotValid:
            break
        }
        
        return false
    }
    
    mutating func updateStateDiff() -> Bool {
        switch tp.diffState {
        case .DetectRising:
            if diff*10 > 3*tf.diffMax {
                tp.diffState = .DetectOpen
            }
            
        case .DetectOpen:
            if avg*2 > tf.avgMax {
                tp.avgPositive = true
            }
            if diff*10 > 6*tf.diffMax {
                tp.diffFullOpen = true
            }
            if tp.avgPositive && tp.diffFullOpen {
                tp.diffState = .DetectFalling
            }
            
        case .DetectFalling:
            if diff*10 < 3*tf.diffMax {
                tp.diffState = .Pause
                let gapBlock = Int(Float(tp.samplesSinceTick)*2.3)
                tp.gapBlock = gapBlock > 5000 ? 5000 : gapBlock
            }
        case .Pause:
            if tp.samplesSinceTick > tp.gapBlock {
                tp.diffState = .DetectDrop
                
                FilteredValues.updateVal(val: &tf.diffGap, newVal: diff)
                tp.diffRiseThreshold = (10*tf.diffGap + (tf.diffMax - tf.diffGap))/10
                
                tp.avgDropHalf = (tf.avgClosedMax - tp.avgOpenMin)/2
            }
        case .DetectDrop:
            if (((avg < tp.avgGapMax - tp.avgDropHalf) && (diff > tp.diffRiseThreshold)) || 4*diff > 3*tf.diffMax) {
                return  true;
            }
        }
        
        return false
    }
    
    public mutating func processSamples(samples: [Int16], sampleTime: Int64) -> [Tick] {
        var ticks = [Tick]()
        var runningSampleTime = sampleTime - tp.samplesSinceTick
        
        for sample in samples {
            let sampleInt = Int(sample)
            updateRunningStats(sample: sampleInt)
            if (updateStateAvg() || updateStateDiff() || tp.samplesSinceTick == 7000) {
                // start of new gap detected
                runningSampleTime = runningSampleTime + tp.samplesSinceTick
                updateFilteredValues()
                ticks.append(Tick(time: runningSampleTime, deltaTime: tp.samplesSinceTick))
                tp = AudioSampleProcessor.TickProperties()
            }
        }
        
        return ticks
    }
}
