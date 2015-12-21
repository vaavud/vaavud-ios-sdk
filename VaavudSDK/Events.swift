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
//import Firebase

public extension NSDate {
    convenience init(ms: NSNumber) {
        self.init(timeIntervalSince1970: Double(ms.longLongValue)/1000)
    }
    
    var ms: NSNumber {
        return NSNumber(longLong: Int64(round(timeIntervalSince1970*1000)))
    }
}

protocol Event {
    var time: NSDate { get }
}

public typealias FirebaseDictionary = [String : AnyObject]

public protocol Firebaseable {
    var fireDict: FirebaseDictionary { get }
}

public protocol FirebaseEntity {
    init?(dict: FirebaseDictionary)
}

//public protocol FirebaseTopEntity {
//    init?(snapshot: FDataSnapshot)
//}

public struct WindSpeedEvent: Event, Firebaseable {
    public let time: NSDate
    public let speed: Double
    
    public init(time: NSDate = NSDate(), speed: Double) {
        self.time = time
        self.speed = speed
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, speed = dict["speed"] as? Double else {
            return nil
        }
        
        self.time = NSDate(ms: time)
        self.speed = speed
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "speed" : speed]
    }
}

public struct WindDirectionEvent: Event, Firebaseable {
    public let time: NSDate
    public let direction: Double

    public init(time: NSDate = NSDate(), direction: Double) {
        self.time = time
        self.direction = direction
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, direction = dict["direction"] as? Double else {
            return nil
        }
        
        self.time = NSDate(ms: time)
        self.direction = direction
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "direction" : direction]
    }
}

public struct PressureEvent: Event, Firebaseable {
    public let time: NSDate
    public let pressure: Double
    
    public init(time: NSDate = NSDate(), pressure: Double) {
        self.time = time
        self.pressure = pressure
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, pressure = dict["pressure"] as? Double else {
            return nil
        }
        
        self.time = NSDate(ms: time)
        self.pressure = pressure
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "pressure" : pressure]
    }
}

public struct TemperatureEvent: Event, Firebaseable {
    public let time: NSDate
    public let temperature: Double
    
    public init(time: NSDate = NSDate(), temperature: Double) {
        self.time = time
        self.temperature = temperature
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, temperature = dict["temperature"] as? Double else {
            return nil
        }
        
        self.time = NSDate(ms: time)
        self.temperature = temperature
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "temperature" : temperature]
    }
}

public struct HeadingEvent: Event, Firebaseable {
    public let time: NSDate
    public let heading: Double
    
    public init(time: NSDate = NSDate(), heading: Double) {
        self.time = time
        self.heading = heading
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, heading = dict["heading"] as? Double else {
            return nil
        }
        
        self.time = NSDate(ms: time)
        self.heading = heading
    }

    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "heading" : heading]
    }
}

public struct LocationEvent: Event, Firebaseable {
    public let time: NSDate
    public let lat: CLLocationDegrees
    public let lon: CLLocationDegrees
    public let altitude: CLLocationDistance
    
    public init(time: NSDate = NSDate(), lat: CLLocationDegrees, lon: CLLocationDegrees, altitude: CLLocationDegrees) {
        self.time = time
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber,
            lat = dict["lat"] as? CLLocationDegrees,
            lon = dict["lon"] as? CLLocationDegrees,
            altitude = dict["altitude"] as? CLLocationDistance
            else {
                return nil
        }
        
        self.time = NSDate(ms: time)
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
    }
    
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "lat" : lat, "lon" : lon, "altitude" : altitude]
    }
}

public struct VelocityEvent: Event, Firebaseable {
    public let time: NSDate
    public let speed: CLLocationSpeed
    public let course: CLLocationDirection
    
    public init(time: NSDate = NSDate(), speed: CLLocationSpeed, course: CLLocationDirection) {
        self.time = time
        self.speed = speed
        self.course = course
    }
    
    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber,
            course = dict["course"] as? CLLocationDirection,
            speed = dict["speed"] as? CLLocationSpeed
            else {
                return nil
        }
        
        self.time = NSDate(ms: time)
        self.speed = speed
        self.course = course
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "speed" : speed, "course" : course]
    }
}

public enum VaavudAudioError: ErrorType, CustomStringConvertible {
    case Unplugged
    case MultipleStart
    case AudioEngine(NSError)
    case AudioSessionCategory(NSError)
    case AudioInputUnavailable
    case AudioSessionSampleRate(NSError)
    case AudioSessionBufferDuration(NSError)
    
    public var description: String {
        return "Error"
    }
}

public enum VaavudOtherError: ErrorType, CustomStringConvertible {
    case LocationAuthorisation(CLAuthorizationStatus)
    
    public var description: String {
        return "Error"
    }
}

public struct ErrorEvent: Event, Firebaseable, CustomStringConvertible {
    public enum ErrorEventType {
        case TemperatureReadingFailure
        case AudioInterruption(AVAudioSessionInterruptionType)
        case AudioRouteChange(AVAudioSessionRouteChangeReason)
        case AudioReconfigurationFailure(VaavudAudioError)
        case LocationManagerFailure(NSError)
        case HeadingUnavailable(NSError)
//        case ThrownAudioError(VaavudAudioError)
//        case ThrownOtherError(VaavudOtherError)
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
        case .AudioInterruption, .AudioRouteChange, .AudioReconfigurationFailure:
            domain = .WindReading
        case .TemperatureReadingFailure:
            domain = .Temperature
        case .LocationManagerFailure, .HeadingUnavailable:
            domain = .Location
        }
    }
    
    public init?(dict: FirebaseDictionary) {
        return nil
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "description" : description]
    }
    
    public var description: String {
        switch type {
        case let .AudioInterruption(interruptionType):
            return "AudioSession interrupted (\(interruptionType))"
        case let .AudioRouteChange(routeChangeReason):
            return "Audio route change (\(routeChangeReason))"
        case .TemperatureReadingFailure:
            return "Temperature reading failed"
        case let .LocationManagerFailure(error):
            return "Temperature reading failed with error: \(error.localizedDescription)"
        case let .AudioReconfigurationFailure(audioError):
            return "Audio reconfiguration failed with error: \(audioError)"
        case let .HeadingUnavailable(error):
            return "Heading unavailable, failed with error: \(error.localizedDescription)"
        }
    }
}

protocol WindListener: class {
    func newError(event: ErrorEvent)
    func newWindSpeed(event: WindSpeedEvent)
    func newWindDirection(event: WindDirectionEvent)
    
    func debugPlot(pointss: [[CGFloat]])
}

protocol LocationListener: class {
    func newError(event: ErrorEvent)
    func newHeading(event: HeadingEvent)
    func newLocation(event: LocationEvent)
    func newVelocity(event: VelocityEvent)
}

protocol TemperatureListener: class {
    func newError(event: ErrorEvent)
    func newTemperature(event: TemperatureEvent)
}
