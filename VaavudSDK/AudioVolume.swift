//
//  AudioVolume.swift
//  Pods
//
//  Created by Andreas Okholm on 08/07/15.
//
//

import Foundation

struct AudioResponse: CustomStringConvertible {
    let diff20: Int
    let rotations: Int
    let detectionErrors: Int
    let sN: Double
    
    var description: String {
        return "AResp (diff20: \(diff20), rotations: \(rotations), dErrors: \(detectionErrors), sN: \(sN))"
    }
}

// Find the correct Volume
let volSteps = 101

func volumeSetting(volume: Int) -> Float {
    return Float(volume)/Float(volSteps - 1)
}

enum SearchType {
    case Diff
    case SequentialSearch
    case SteepestAssent
}

enum ExpState {
    case Top
    case Explore
}

enum ExpDirection {
    case Left
    case Right
}

struct VolumeTest: CustomStringConvertible {
    var volume = 0
    var sN = [Double](repeating: 0.0, count: volSteps)
    var diff20 = [Int](repeating: 0, count: volSteps)
    var counter = 0
    var description: String {
        return String(format: "Vol (volume: %0.3f)", volumeSetting(volume: volume))
    }
    
    init() {}
    
    mutating func newVolume(resp: AudioResponse) -> Float {
        sN[volume] = resp.sN
        diff20[volume] = resp.diff20
        
        counter += 1
        volume = counter % volSteps
        
        return volumeSetting(volume: volume)
    }
    
    func debugDictionary() -> [String: Any] {
        return ["sN" : sN, "diff20": diff20]
    }
}

struct Volume: CustomStringConvertible {
    let noiseThreshold = 1100
    var volume = Int(volSteps/2)
    var sN = [Double](repeating: 0.0, count: volSteps)
    var counter = 0
    
    var volState = SearchType.Diff
    var expState = ExpState.Top
    var expDirection = ExpDirection.Left
    
    var description: String {
        return String(format: "Vol (volume: %0.3f", volumeSetting(volume: volume)) + ", volState: \(volState.hashValue))"
    }
    
    init() {
        // Load saved state
        if let volume = UserDefaults.standard.value(forKey: "vaavud_volume") as? Int {
            self.volume = volume
        }
        
        if let sNData = UserDefaults.standard.object(forKey: "vaavud_sn") as? NSData,
            let sN = NSKeyedUnarchiver.unarchiveObject(with: sNData as Data) as? [Double] {
                self.sN = sN
                volState = .SteepestAssent
        }
    }
    
    func save() {
        guard volState == .SteepestAssent else { return }
        
        let userDefaults = UserDefaults.standard
        userDefaults.setValue(volume, forKey: "vaavud_volume")
        
        let sNData = NSKeyedArchiver.archivedData(withRootObject: sN)
        userDefaults.set(sNData, forKey: "vaavud_sn")
        
        userDefaults.synchronize()
    }
    
    mutating func returnToDiffState() {
        volState = .Diff
        counter = 0
        sN = [Double](repeating: 0, count: volSteps)
    }
    
    mutating func newVolume(resp: AudioResponse) -> Float {
        counter += 1
        
        if resp.sN > 6 && resp.rotations >= 1 {
            volState = .SteepestAssent
        }
        
        switch volState {
        case .Diff:
            let noiseDiff = abs(resp.diff20 - noiseThreshold)
            let divisor = resp.diff20 >= noiseThreshold ? -50000 : 10000
            volume += volSteps*noiseDiff/divisor
            
            if counter > 15 {
                volState = .SequentialSearch
            }
            
        case .SequentialSearch:
            if counter > 45 {
                returnToDiffState()
                break
            }
            volume = counter % 20*(volSteps/20) + volSteps/40 // 5, 15, 25 ... 95
            
        case .SteepestAssent:
            let signalIsGood = resp.sN > 1.2 && resp.rotations >= 1
            
            if signalIsGood {
                sN[volume] = sN[volume] == 0 ? resp.sN : sN[volume]*0.7 + 0.3*resp.sN
                counter = 0
            }
            else if counter > 40 {
                returnToDiffState()
                break
            }
            
            switch expState {
            case .Top:
                let bestSNVol = findMax(array: sN)
                
                if sN[bestSNVol] < 6 {
                    returnToDiffState()
                    break
                }
                
                var volChange = bestSNVol - volume
                volChange = (volChange > 0 && volChange < 5) ? 1 : (volChange < 0 && volChange > -5) ? -1 : volChange
                volume = volume + volChange
                
                if volChange == 0 {
                    expState = .Explore
                }
                
            case .Explore:
                switch expDirection {
                case .Left:
                    volume = volume - 1
                    expDirection = .Right
                case .Right:
                    volume = volume + 1
                    expDirection = .Left
                }
                expState = .Top
            }
        }
        volume = min(max(0, volume), volSteps - 1)
        
        return volumeSetting(volume: volume)
    }
}

func findMax<T: Comparable>(array: [T]) -> Int {
    var max = array[0]
    var maxi = 0
    
    for i in 0..<array.count where array[i] > max {
        maxi = i
        max = array[i]
    }
    
    return maxi
}
