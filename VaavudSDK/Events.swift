//
//  Events.swift
//  Pods
//
//  Created by Gustaf Kugelberg on 20/08/15.
//
//

import Foundation
import AVFoundation
import CoreLocation

public class Box<T> {
    public let unbox: T
    
    init(_ value: T) {
        self.unbox = value
    }
}

public enum Result<T> {
    case Value(Box<T>)
    case Error(ErrorEvent)
    
    public init(_ value: T) {
        self = .Value(Box(value))
    }
    
    init(_ error: ErrorEvent) {
        self = .Error(error)
    }

    public var value: T? {
        switch self {
        case let .Value(val): return val.unbox
        case .Error: return nil
        }
    }
}

protocol Event {
    var time: NSDate { get }
}

protocol Dictionarifiable {
    var dict: [String : AnyObject] { get }
}

public struct WindSpeedEvent: Event, Dictionarifiable {
    public let time: NSDate
    public let speed: Double
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "speed" : speed]
    }
    
    public init(time: NSDate, speed: Double) {
        self.time = time
        self.speed = speed
    }
}

public struct WindDirectionEvent: Event, Dictionarifiable {
    public let time: NSDate
    public let globalDirection: Double

    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "globalDirection" : globalDirection]
    }
}

public struct TemperatureEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let temperature: Double
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "temperature" : temperature]
    }
}

public struct HeadingEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let heading: Double
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "heading" : heading]
    }
}

public enum VaavudError: ErrorType {
    case Unplugged
    case MultipleStart
    case AudioEngine(NSError)
    case AudioSessionCategory(NSError)
    case AudioSessionSampleRate(NSError)
    case AudioSessionBufferDuration(NSError)
    case LocationAuthorisation(CLAuthorizationStatus)
}

public struct ErrorEvent: Event, Dictionarifiable {
    public enum ErrorEventType {
        case AudioInterruption(AVAudioSessionInterruptionType)
        case AudioRouteChange(AVAudioSessionRouteChangeReason)
        case TemperatureReadingFailure
        case LocationManagerFailure(NSError)
    }
    
    public let time = NSDate()
    public let type: ErrorEventType

    public enum ErrorEventDomain {
        case WindReading
        case Temperature
        case Location
    }

    public let domain: ErrorEventDomain
    
    init(eventType: ErrorEventType) {
        type = eventType
        
        switch type {
        case .AudioInterruption, .AudioRouteChange:
            domain = .WindReading
        case .TemperatureReadingFailure:
            domain = .Temperature
        case .LocationManagerFailure:
            domain = .Location
        }
    }
    
    var dict: [String : AnyObject] {
        let description: String
        
        switch type {
        case let .AudioInterruption(interruptionType):
            description = "AudioSession interrupted (\(interruptionType))"
        case let .AudioRouteChange(routeChangeReason):
            description = "Audio route change (\(routeChangeReason))"
        case .TemperatureReadingFailure:
            description = "Temperature reading failed"
        case let .LocationManagerFailure(error):
            description = "Temperature reading failed with error: \(error.localizedDescription)"
        }
        
        return ["time" : time.timeIntervalSince1970, "description" : description]
    }
}

//public protocol VaavudListener: WindListener, TemperatureListener { }

protocol WindListener: class {
    func newError(error: ErrorEvent)
    func newWindSpeed(result: WindSpeedEvent)
    func newWindDirection(result: WindDirectionEvent)
    
    func debugPlot(pointss: [[CGFloat]])
}

protocol LocationListener: class {
    func newError(error: ErrorEvent)
    func newHeading(result: HeadingEvent)
}

protocol TemperatureListener: class {
    func newError(error: ErrorEvent)
    func newTemperature(result: TemperatureEvent)
}
