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

public extension Date {
    init(ms: NSNumber) {
        self.init(timeIntervalSince1970: Double(ms.int64Value)/1000)
    }
    
    var ms: NSNumber {
        return NSNumber(value: Int64(round(timeIntervalSince1970*1000)))
    }
}

protocol Event {
    var time: Date { get }
}

public typealias FirebaseDictionary = [String : Any]

public protocol Firebaseable {
    var fireDict: FirebaseDictionary { get }
}

public protocol FirebaseEntity {
    init?(dict: FirebaseDictionary)
}


//Bluetooth

extension Data {
    public func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    public func substring(from: Int?, to: Int?) -> String {
        if let start = from {
            guard start < self.characters.count else {
                return ""
            }
        }
        
        if let end = to {
            guard end >= 0 else {
                return ""
            }
        }
        
        if let start = from, let end = to {
            guard end - start >= 0 else {
                return ""
            }
        }
        
        let startIndex: String.Index
        if let start = from, start >= 0 {
            startIndex = self.index(self.startIndex, offsetBy: start)
        } else {
            startIndex = self.startIndex
        }
        
        let endIndex: String.Index
        if let end = to, end >= 0, end < self.characters.count {
            endIndex = self.index(self.startIndex, offsetBy: end + 1)
        } else {
            endIndex = self.endIndex
        }
        
        return self[startIndex ..< endIndex]
    }
}




///


public struct TrueWindSpeedEvent: Event, Firebaseable {
    public let time: Date
    public let speed: Double
    
    public init(time: Date = Date(), speed: Double) {
        self.time = time
        self.speed = speed
    }
    
    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let speed = dict["trueSpeed"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.speed = speed
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "trueSpeed" : speed]
    }
}


public struct WindSpeedEvent: Event, Firebaseable {
    public let time: Date
    public let speed: Double
    
    public init(time: Date = Date(), speed: Double) {
        self.time = time
        self.speed = speed
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let speed = dict["speed"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.speed = speed
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "speed" : speed]
    }
}

public struct TrueWindDirectionEvent: Event, Firebaseable {
    public let time: Date
    public let direction: Double
    
    public init(time: Date = Date(), direction: Double) {
        self.time = time
        self.direction = direction
    }
    
    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let direction = dict["trueDirection"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.direction = direction
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "trueDirection" : direction]
    }
}

public struct WindDirectionEvent: Event, Firebaseable {
    public let time: Date
    public let direction: Double

    public init(time: Date = Date(), direction: Double) {
        self.time = time
        self.direction = direction
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let direction = dict["direction"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.direction = direction
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "direction" : direction]
    }
}


public struct CourseEvent: Event, Firebaseable {
    
    
    public let time: Date
    public let course: Double
    
    
    public init(time: Date = Date(), course: Double){
        self.time = time
        self.course = course
    }
    
    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let pressure = dict["curse"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.course = pressure
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "course" : course]
    }
    
    
    
    
}

public struct PressureEvent: Event, Firebaseable {
    public let time: Date
    public let pressure: Double
    
    public init(time: Date = Date(), pressure: Double) {
        self.time = time
        self.pressure = pressure
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let pressure = dict["pressure"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.pressure = pressure
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "pressure" : pressure]
    }
}

public struct TemperatureEvent: Event, Firebaseable {
    public let time: Date
    public let temperature: Double
    
    public init(time: Date = Date(), temperature: Double) {
        self.time = time
        self.temperature = temperature
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let temperature = dict["temperature"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.temperature = temperature
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "temperature" : temperature]
    }
}

public struct BluetoothEvent: Event, Firebaseable {
    public let windSpeed: Double
    public let time: Date
    public let windDirection: Int
    public let battery: Int
    public let compass: Double
    
    public init(time: Date = Date(), windSpeed: Double, windDirection:Int, battery: Int, compass: Double){
        self.time = time
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.battery = battery
        self.compass = compass
    }
    
    public var fireDict: FirebaseDictionary{
        return ["time" : time.ms, "windSpeed" : windSpeed, "windDirection": windDirection,"compass": compass]
    }
}


public struct BluetoothExtraEvent: Event, Firebaseable{
    public let battery: Int
    public let compass: Int
    public let time: Date
    ///TODO add the rest when need it
    
    public init(time: Date = Date(), compass: Int, battery: Int){
        self.time = time
        self.battery = battery
        self.compass = compass
    }
    
    public var fireDict: FirebaseDictionary{
        return ["time" : time.ms, "compass" : compass, "battery": battery]
    }
}

public struct DataPoint: Firebaseable {
    
    let time = Date()
    let windSpeed: Double
    let windDirection: Double?
    let location: [String:Any]


    public var fireDict: FirebaseDictionary {
        var f : FirebaseDictionary = [:]
        f["timestamp"] = time.ms
        f["windSpeed"] = windSpeed
        f["windDirection"] = windDirection
        f["location"] = location
        return f
    }

}


public struct HeadingEvent: Event, Firebaseable {
    public let time: Date
    public let heading: Double
    
    public init(time: Date = Date(), heading: Double) {
        self.time = time
        self.heading = heading
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber, let heading = dict["heading"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.heading = heading
    }

    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "heading" : heading]
    }
}

public struct LocationEvent: Event, Firebaseable {
    public let time: Date
    public let lat: CLLocationDegrees
    public let lon: CLLocationDegrees
    public let altitude: CLLocationDistance?
    
    public init(location: CLLocation) {
        self.time = location.timestamp
        self.lat = location.coordinate.latitude
        self.lon = location.coordinate.longitude
        self.altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
    }
    
    public init(time: Date = Date(), lat: CLLocationDegrees, lon: CLLocationDegrees, altitude: CLLocationDegrees?) {
        self.time = time
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
    }

    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber,
            let lat = dict["lat"] as? CLLocationDegrees,
            let lon = dict["lon"] as? CLLocationDegrees,
            let altitude = dict["altitude"] as? CLLocationDistance
            else {
                return nil
        }
        
        self.time = Date(ms: time)
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
    }
    
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    public var location: CLLocation {
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    public var fireDict: FirebaseDictionary {
        var dict : FirebaseDictionary = ["lat" : lat, "lon" : lon]
        dict["altitude"] = altitude
        return dict
    }
}

public struct VelocityEvent: Event, Firebaseable {
    public let time: Date
    public let speed: CLLocationSpeed
    public let course: CLLocationDirection
    
    public init(time: Date = Date(), speed: CLLocationSpeed, course: CLLocationDirection) {
        self.time = time
        self.speed = speed
        self.course = course
    }
    
    public init?(dict: FirebaseDictionary) {
        guard let time = dict["time"] as? NSNumber,
            let course = dict["course"] as? CLLocationDirection,
            let speed = dict["speed"] as? CLLocationSpeed
            else {
                return nil
        }
        
        self.time = Date(ms: time)
        self.speed = speed
        self.course = course
    }
    
    public var fireDict: FirebaseDictionary {
        return ["time" : time.ms, "speed" : speed, "course" : course]
    }
}

public struct AltitudeEvent: Event, Firebaseable {
    public let time: Date
    public let altitude: Double
    
    public init(time: Date = Date(), altitude: Double){
        self.time = time
        self.altitude = altitude
    }
    
    public init?(dict: FirebaseDictionary){
        guard let time = dict["time"] as? NSNumber, let altitude  = dict["altitude"] as? Double else {
            return nil
        }
        
        self.time = Date(ms: time)
        self.altitude = altitude
    }
    
    public var fireDict: FirebaseDictionary{
        return ["time": time.ms, "altitude": altitude]
    }
}

public enum VaavudAudioError: Error, CustomStringConvertible {
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

public enum VaavudOtherError: Error, CustomStringConvertible {
    case LocationAuthorisation(CLAuthorizationStatus)
    case Altimeter
    
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
    
    public let time = Date()
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
            return "Location manager failed with error: \(error.localizedDescription)"
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
    func debugPlot(pointss: [[CGPoint]])
}

public protocol BluetoothListener: class {
    func newReading(event: BluetoothEvent)
    func extraInfo(event: BluetoothExtraEvent)
}

protocol LocationListener: class {
    func newError(event: ErrorEvent)
    func newHeading(event: HeadingEvent)
    func newLocation(event: LocationEvent)
    func newVelocity(event: VelocityEvent)
    func newAltitude(event: AltitudeEvent)
    func newCourse(event: CourseEvent)
}

protocol TemperatureListener: class {
    func newError(event: ErrorEvent)
    func newTemperature(event: TemperatureEvent)
}
