//
//  Events.swift
//  Pods
//
//  Created by Gustaf Kugelberg on 20/08/15.
//
//

import Foundation

public class Box<T> {
    public let unbox: T
    
    init(_ value: T) {
        self.unbox = value
    }
}

public enum Result<T> {
    case Value(Box<T>)
    case Error(ErrorEvent)
    
    init(_ value: T) {
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

public struct ErrorEvent: Event, Dictionarifiable {
    public let time = NSDate()
    public let technicalDescription: String
    public let userDescription: String
    
    init(_ technical: String, user: String) {
        self.technicalDescription = technical
        self.userDescription = user
        
        println(technical)
    }
    
    init(_ error: String) {
        self.init(error, user: error)
    }

    var dict: [String : AnyObject] {
        return ["time" : time.timeIntervalSince1970, "technicalDescription" : technicalDescription, "userDescription" : userDescription]
    }
}

//public protocol VaavudListener: WindListener, TemperatureListener { }

protocol WindListener: class {
    func newWindSpeed(Result<WindSpeedEvent>)
    func newWindDirection(Result<WindDirectionEvent>)
    
    func debugPlot([[CGFloat]])
}

protocol LocationListener: class {
    func newHeading(Result<HeadingEvent>)
}

protocol TemperatureListener: class {
    func newTemperature(Result<TemperatureEvent>)
}