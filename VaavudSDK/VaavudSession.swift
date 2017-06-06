//
//  VaavudSession.swift
//  VaavudSDK
//
//  Created by Diego Galindo on 5/18/17.
//  Copyright © 2017 Vaavud ApS. All rights reserved.
//

import Foundation


public enum VaavudDevice: String {
    case ultrasonic = "Ultrasonic"
    case sleipnir = "sleipnir"
    case mjolnir = "mjolnir"
    
    
    public func index() -> Int {
        switch self {
        case .ultrasonic:
            return 2
        case .mjolnir:
            return 0
        case .sleipnir:
            return 1
        }
    }
    
    
}


public struct VaavudSession {
    public let time = Date()
    
    public private(set) var meanDirection: Double?
    public private(set) var meanTrueDirection: Double?
    public private(set) var windSpeeds = [WindSpeedEvent]()
    public private(set) var trueWindSpeeds = [TrueWindSpeedEvent]()
    public private(set) var windDirections = [WindDirectionEvent]()
    public private(set) var trueWindDirections = [TrueWindDirectionEvent]()
    public private(set) var headings = [HeadingEvent]()
    public private(set) var locations = [LocationEvent]()
    public private(set) var velocities = [VelocityEvent]()
    public private(set) var temperatures = [TemperatureEvent]()
    public private(set) var pressures = [PressureEvent]()
    public private(set) var altitud = [AltitudeEvent]()
    public private(set) var course = [CourseEvent]()
    public private(set) var points = [DataPoint]()
    public private(set) var windMeter : VaavudDevice!
    
    public var meanSpeed: Double { return windSpeeds.count > 0 ? windSpeedSum/Double(windSpeeds.count) : 0 }
    public var meanTrueSpeed: Double { return trueWindSpeeds.count > 0 ? trueWindSpeedSum/Double(trueWindSpeeds.count) : 0 }
    
    public var maxSpeed: Double = 0
    public var trueMaxSpeed: Double = 0
    
    public var turbulence: Double? {
        return gustiness(speeds: windSpeeds.map { $0.speed })
        //        return (windSpeedSquaredSum - windSpeedSum*windSpeedSum)/meanSpeed
    }
    
    // Private variables
    
    private var trueWindSpeedSum: Double = 0
    private var trueWindSpeedSquaredSum: Double = 0
    private var windSpeedSum: Double = 0
    private var windSpeedSquaredSum: Double = 0
    
    // Location data
    
    mutating func addHeading(event: HeadingEvent) {
        headings.append(event)
    }
    
    mutating func addLocation(event: LocationEvent) {
        locations.append(event)
    }
    
    mutating func addVelocity(event: VelocityEvent) {
        velocities.append(event)
    }
    
    mutating func addAltitude(event: AltitudeEvent) {
        altitud.append(event)
    }
    
    mutating func addCourse(event: CourseEvent) {
        course.append(event)
    }
    
    mutating func setWindMeter(vaavudDevice: VaavudDevice){
        windMeter = vaavudDevice
    }
    
    mutating func addPoint(point: DataPoint) {
        points.append(point)
    }
    
    // Wind data
    
    mutating func addWindSpeed(event: WindSpeedEvent) {
        windSpeeds.append(event)
        
        let speed = event.speed
        windSpeedSum += speed
        windSpeedSquaredSum += speed*speed
        maxSpeed = max(speed, maxSpeed)
        
        // Fixme: variable update frequency should be considered
    }
    
    mutating func addTrueWindSpeed(event: TrueWindSpeedEvent) {
        trueWindSpeeds.append(event)
        
        let speed = event.speed
        trueWindSpeedSum += speed
        trueWindSpeedSquaredSum += speed*speed
        trueMaxSpeed = max(speed, trueMaxSpeed)
    }
    
    mutating func addWindDirection(event: WindDirectionEvent) {
        meanDirection = mod(angle: event.direction)
        windDirections.append(event)
    }
    
    mutating func addTrueWindDirection(event: TrueWindDirectionEvent) {
        meanTrueDirection = mod(angle: event.direction)
        trueWindDirections.append(event)
    }
    
    // Temprature data
    
    mutating func addTemperature(event: TemperatureEvent) {
        temperatures.append(event)
    }
    
    // Pressure data
    
    mutating func addPressure(event: PressureEvent) {
        pressures.append(event)
    }
    
    // Helper function
    
    public func relativeTime(measurement: WindSpeedEvent) -> TimeInterval {
        return measurement.time.timeIntervalSince(time)
    }
    
    func description(measurement: WindSpeedEvent) -> String {
        return "WindSpeedEvent (time rel:" + String(format: "% 5.2f", relativeTime(measurement: measurement)) + " speed:" + String(format: "% 5.2f", measurement.speed) + " UnixTime: \(measurement.time.timeIntervalSince1970))"
    }
    
    
    public var dict: FirebaseDictionary {
        
        var session:FirebaseDictionary = [:]
        
        
        session["windMean"] = meanSpeed
        session["trueWindMean"] = meanTrueSpeed
        
        
//        if let headings = headings.last {
//            session["headings"] = headings.heading
//        }
        
        if let location = locations.last {
            session["location"] = location.fireDict
        }
        
//        if let velocity = velocities.last {
//            session["velocity"] = velocity.speed
//        }
        
        if let temperature = temperatures.last {
            session["temperature"] = temperature.temperature
        }
        
        if let pressure = pressures.last {
            session["pressure"] = pressure.pressure
        }
        
//        if let altitude = altitud.last {
//            session["altitude"] = altitude.altitude
//        }
        
//        if let course = course.last {
//            session["course"] = course.course
//        }
        
        
        session["timeStart"] = time.ms
        session["timeEnd"] = Date().ms
        session["windDirection"] = meanDirection
        if meanTrueDirection != nil && !meanTrueDirection!.isNaN {
            session["trueWindDirection"] = meanTrueDirection
        }
        session["windMeter"] = windMeter.rawValue
        session["windMax"] = maxSpeed
        session["trueWindMax"] = trueMaxSpeed
        session["turbulence"] = turbulence
        
        return session
    }
}

func gustiness(speeds: [Double]) -> Double? {
    let n = Double(speeds.count)
    
    guard n > 0 else {
        return nil
    }
    
    let mean = speeds.reduce(0, +)/n
    let squares = speeds.map { ($0 - mean)*($0 - mean) }
    let variance = squares.reduce(0, +)/(n - 1)
    
    //    let variance: Double = speeds.reduce(0) { $0 + ($1 - mean)*($1 - mean) }/(n - 1)
    
    return variance/mean
}
