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
}

public struct WindDirectionEvent: Event, Dictionarifiable {
    public let time: NSDate
    public let globalDirection: Double

    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "globalDirection" : globalDirection]
    }
}

public struct PressureEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let pressure: Double
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "pressure" : pressure]
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

public struct LocationEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let latitude: CLLocationDegrees
    public let longitude: CLLocationDegrees
    public let altitude: CLLocationDistance
    
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "latitude" : latitude, "longitude" : longitude, "altitude" : altitude]
    }
}

public struct CourseEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let course: CLLocationDirection
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "course" : course]
    }
}

public struct SpeedEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let speed: CLLocationSpeed
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "speed" : speed]
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

public struct ErrorEvent: Event, Dictionarifiable, CustomStringConvertible {
    public enum ErrorEventType {
        case TemperatureReadingFailure
        case AudioInterruption(AVAudioSessionInterruptionType)
        case AudioRouteChange(AVAudioSessionRouteChangeReason)
        case AudioReconfigurationFailure(VaavudAudioError)
        case LocationManagerFailure(NSError)
        case HeadingUnavailable(NSError)
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
    
    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "description" : description]
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
    func newCourse(event: CourseEvent)
    func newSpeed(event: SpeedEvent)
}

protocol TemperatureListener: class {
    func newError(event: ErrorEvent)
    func newTemperature(event: TemperatureEvent)
}
