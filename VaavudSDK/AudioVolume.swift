//
//  AudioVolume.swift
//  Pods
//
//  Created by Andreas Okholm on 08/07/15.
//
//

import Foundation

struct AudioResponse {
    let diff20: Int
    let rotations: Int
    let detectionErrors: Int
    let sN: Double
    
    var description: String {
        return "AResp (diff20: \(diff20), rotations: \(rotations), dErrors: \(detectionErrors), sN: \(sN))"
    }
}

// find the correct Volume
let volSteps = 101

enum searchType {
    case Diff
    case SequentialSearch
    case SteepestAccent
}

enum ExpState: Int {
    case Top
    case Explore
}

enum ExpDirection: Int {
    case Left = -1
    case Right = 1
}

struct VolumeTest{
    var volume = 0
    var sN = [Double](count: volSteps, repeatedValue: 0.0)
    var diff20 = [Int](count: volSteps, repeatedValue: 0)
    var counter = 0
    var description: String {
        return "Vol (volume: " + String(format: "%0.3f", getVolume()) + ")"
    }
    
    init() {}
    
    func getVolume() -> Float {
        return Float(volume)/Float(volSteps-1)
    }
    
    mutating func newVolume(resp: AudioResponse) -> Float{
        
        self.sN[volume] = resp.sN
        self.diff20[volume] = resp.diff20
        
        counter++
        volume = counter%volSteps
        
        return getVolume()
    }
    
    func testDictionary() -> [String: AnyObject] {
        return ["sN" : sN, "diff20": diff20]
    }
}



struct Volume{
    let noiseThreshold = 1100
    var volume = Int(volSteps/2)
    var sN = [Double](count: volSteps, repeatedValue: 0.0)
    var counter = 0
    
    var volState = searchType.Diff
    var expState = ExpState.Top
    var expDirection = ExpDirection.Left
    
    var description: String {
        return "Vol (volume: " + String(format: "%0.3f", getVolume()) + ", volState: \(volState.hashValue))"
    }
    
    init() {
        // load save state
        if let volume = NSUserDefaults.standardUserDefaults().valueForKey("vaavud_volume") as? Int {
            self.volume = volume
        }
        
        if let sNData = NSUserDefaults.standardUserDefaults().objectForKey("vaavud_sn") as? NSData {
            if let sN = NSKeyedUnarchiver.unarchiveObjectWithData(sNData) as? [Double] {
                self.sN = sN
                volState = .SteepestAccent
            }
        }
    }
    
    func getVolume() -> Float {
        return Float(volume)/Float(volSteps-1)
    }
    
    func save() {
        if volState == .SteepestAccent {
            let userDefaults = NSUserDefaults.standardUserDefaults()
            userDefaults.setValue(volume, forKey: "vaavud_volume")
            
            let sNData = NSKeyedArchiver.archivedDataWithRootObject(sN)
            NSUserDefaults.standardUserDefaults().setObject(sNData, forKey: "vaavud_sn")
            
            userDefaults.synchronize() // don't forget this!!!!
        }
    }
    
    mutating func returnToDiffState() {
        volState = .Diff
        counter = 0
        sN = [Double](count: volSteps, repeatedValue: 0.0)
    }
    
    mutating func newVolume(resp: AudioResponse) -> Float{
        
        counter++
        
        if resp.sN > 6 && resp.rotations >= 1 {
            volState = searchType.SteepestAccent
        }
        
        switch volState {
        case .Diff:
            var noiseDiff = abs(resp.diff20-noiseThreshold)
            var volumeChange: Int!
            if resp.diff20 >= noiseThreshold {
                volumeChange = volSteps*(-noiseDiff)/50000
            }
            if resp.diff20 < noiseThreshold {
                volumeChange = volSteps*noiseDiff/10000
            }
            volume = volume + volumeChange
            
            if counter > 15 {
                volState = .SequentialSearch
            }
            
        case .SequentialSearch:
            if counter > 45 {
                returnToDiffState()
                break
            }
            volume = counter%20*(volSteps/20)+volSteps/40 // 5, 15, 25 ... 95
            
        case .SteepestAccent:
            let signalIsGood = resp.sN > 1.2 && resp.rotations >= 1
            if signalIsGood {
                self.sN[volume] = self.sN[volume] == 0 ? resp.sN : self.sN[volume]*0.7 + 0.3*resp.sN
                counter = 0
            } else {
                if counter > 40 {
                    returnToDiffState()
                    break
                }
            }
            
            switch expState {
            case .Top:
                let bestSNVol = bestSNVolume()
                if self.sN[bestSNVol] < 6 {
                    returnToDiffState()
                    break
                }
                
                var volChange = bestSNVol - volume;
                volChange = (volChange >= 1 && volChange < 5) ? 1 : (volChange <= -1 && volChange > -5) ? -1 : volChange
                volume = volume + volChange
                if volChange == 0 {
                    expState = .Explore
                }
                
            case .Explore:
                switch expDirection {
                case .Left:
                    volume = volume-1
                    expDirection = .Right
                case .Right:
                    volume = volume+1
                    expDirection = .Left
                }
                expState = .Top
            }
        }
        volume = min(max(0,volume), volSteps-1)
        
        return getVolume()
    }
    
    func bestSNVolume() -> Int {
        var max = 0.0
        var maxi = 0
        for i in 0..<self.sN.count {
            if self.sN[i] > max {
                maxi = i
                max = self.sN[i]
            }
        }
        return maxi
    }
    
}
