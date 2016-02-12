//
//  VaavudSDK.swift
//  Pods
//
//  Created by Andreas Okholm on 24/06/15.
//
//

import Foundation
import CoreMotion

public class VaavudSleipnirAvailability: NSObject {
    public class func available() -> Bool {
        return VaavudSDK.shared.sleipnirAvailable()
    }
}

public class VaavudSDK: WindListener, LocationListener {
    public static let shared = VaavudSDK()
    
    private var windController = WindController()
    private var locationController = LocationController()
    private var pressureController: CMAltimeter? = { return CMAltimeter.isRelativeAltitudeAvailable() ? CMAltimeter() : nil }()
    
    public private(set) var session = VaavudSession()
    
    public var windSpeedCallback: (WindSpeedEvent -> Void)?
    public var trueWindSpeedCallback: (WindSpeedEvent -> Void)? // fixme: implement
    public var windDirectionCallback: (WindDirectionEvent -> Void)?
    public var trueWindDirectionCallback: (WindDirectionEvent -> Void)? // fixme: implement
    
    public var pressureCallback: (PressureEvent -> Void)?
    public var headingCallback: (HeadingEvent -> Void)?
    public var locationCallback: (LocationEvent -> Void)?
    public var velocityCallback: (VelocityEvent -> Void)?
    public var altitudeCallback: (AltitudeEvent -> Void)?
    public var courseCallback: (CourseEvent -> Void)?
    
    public var errorCallback: (ErrorEvent -> Void)?

    public var debugPlotCallback: ([[CGFloat]] -> Void)?

    public init() {
        windController.addListener(self)
        
        locationController.addListener(windController)
        locationController.addListener(self)
    }
    
    public func sleipnirAvailable() -> Bool {
        do { try locationController.start() }
        catch { return false }
        
        locationController.stop()
        
        do { try windController.start(false) }
        catch {
            return false
        }
        
        windController.stop()

        return true
    }
    
    func reset() {
        session = VaavudSession()
    }
        
    public func start(flipped: Bool) throws {
        reset()
        do {
            try locationController.start()
            try windController.start(flipped)
            startPressure()
        }
        catch {
//            newError(ErrorEvent(eventType: xx))
            throw error
        }
    }
    
    private func startPressure() {
        pressureController?.startRelativeAltitudeUpdatesToQueue(.mainQueue()) {
            altitudeData, error in
            if let kpa = altitudeData?.pressure.doubleValue {
                self.newPressure(PressureEvent(pressure: kpa*1000))
            }
            else {
                print("CMAltimeter error")
            }
        }
    }
    
    public func startLocationAndPressureOnly() throws {
        reset()
        try locationController.start()
        startPressure()
    }
    
    public func stop() {
        windController.stop()
        locationController.stop()
        pressureController?.stopRelativeAltitudeUpdates()
    }
    
    public func removeAllCallbacks() {
        windSpeedCallback = nil
        trueWindSpeedCallback = nil
        windDirectionCallback = nil
        trueWindDirectionCallback = nil
        
        pressureCallback = nil
        headingCallback = nil
        locationCallback = nil
        velocityCallback = nil
        errorCallback = nil
    }
    
    public func resetWindDirectionCalibration() {
        windController.resetCalibration()
    }
    
    // MARK: Common error event handling
    
    func newError(error: ErrorEvent) {
        errorCallback?(error)
    }
    
    // MARK: Pressure listener
    
    func newPressure(event: PressureEvent) {
        session.addPressure(event)
        pressureCallback?(event)
    }
    
    // MARK: Location listener

    func newHeading(event: HeadingEvent) {
        session.addHeading(event)
        headingCallback?(event)
    }
    
    func newLocation(event: LocationEvent) {
        session.addLocation(event)
        locationCallback?(event)
    }
    
    func newVelocity(event: VelocityEvent) {
        session.addVelocity(event)
        velocityCallback?(event)
    }
    
    func newCourse(event: CourseEvent) {
        session.addCourse(event)
        courseCallback?(event)
    }
    
    func newAltitude(event: AltitudeEvent) {
        session.addAltitude(event)
        altitudeCallback?(event)
    }
    
    // MARK: Wind listener
    
    public func newWindSpeed(event: WindSpeedEvent) {
        session.addWindSpeed(event)
        windSpeedCallback?(event)
    }
    
    func newTrueWindWindSpeed(event: WindSpeedEvent) {
        session.addTrueWindSpeed(event)
        trueWindSpeedCallback?(event)
    }

    func newWindDirection(event: WindDirectionEvent) {
        session.addWindDirection(event)
        windDirectionCallback?(event)
    }
    
    func newTrueWindDirection(event: WindDirectionEvent) {
        session.addTrueWindDirection(event)
        trueWindDirectionCallback?(event)
    }
    
    func debugPlot(valuess: [[CGFloat]]) {
        debugPlotCallback?(valuess)
    }
    
    deinit {
        print("DEINIT VaavudSDK")
    }
}

public struct VaavudSession {
    public let time = NSDate()
    
    public private(set) var meanDirection: Double?
    public private(set) var windSpeeds = [WindSpeedEvent]()
    public private(set) var trueWindSpeeds = [WindSpeedEvent]()
    public private(set) var windDirections = [WindDirectionEvent]()
    public private(set) var trueWindDirections = [WindDirectionEvent]()
    public private(set) var headings = [HeadingEvent]()
    public private(set) var locations = [LocationEvent]()
    public private(set) var velocities = [VelocityEvent]()
    public private(set) var temperatures = [TemperatureEvent]()
    public private(set) var pressures = [PressureEvent]()
    public private(set) var altitud = [AltitudeEvent]()
    public private(set) var course = [CourseEvent]()
    
    
    public var meanSpeed: Double { return windSpeeds.count > 0 ? windSpeedSum/Double(windSpeeds.count) : 0 }

    public var maxSpeed: Double = 0

    public var turbulence: Double? {
        return gustiness(windSpeeds.map { $0.speed })
//        return (windSpeedSquaredSum - windSpeedSum*windSpeedSum)/meanSpeed
    }

    public var fireDict : FirebaseDictionary {
            return [//"meanDirection" : meanDirection,
                    "meanSpeed": meanSpeed,
                    "maxSpeed": maxSpeed,
                    "windSpeeds": windSpeeds.flatMap {
                        $0.fireDict
                    },
                    "trueWindSpeeds": trueWindSpeeds.flatMap {
                        $0.fireDict
                    },
                    "windDirections": windDirections.flatMap {
                        $0.fireDict
                    },
                    "headings": headings.flatMap {
                        $0.fireDict
                    },
                    "locations": locations.flatMap {
                        $0.fireDict
                    },
                    "velocities": velocities.flatMap {
                        $0.fireDict
                    },
                    "temperatures": temperatures.flatMap {
                        $0.fireDict
                    },
                    "pressures": pressures.flatMap {
                        $0.fireDict
                    },
                    "altitude": altitud.flatMap {
                        $0.fireDict
                    },
                    "course": course.flatMap {
                        $0.fireDict
                    }
            ]
    }
    
    // Private variables
    
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
    

    // Wind data
    
    mutating func addWindSpeed(event: WindSpeedEvent) {
        windSpeeds.append(event)

        let speed = event.speed
        windSpeedSum += speed
        windSpeedSquaredSum += speed*speed
        maxSpeed = max(speed, maxSpeed)

        // Fixme: variable update frequency should be considered
    }
    
    mutating func addTrueWindSpeed(event: WindSpeedEvent) {
        trueWindSpeeds.append(event)
    }
    
    mutating func addWindDirection(event: WindDirectionEvent) {
        meanDirection = mod(event.direction)
        windDirections.append(event)
    }
    
    mutating func addTrueWindDirection(event: WindDirectionEvent) {
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

    public func relativeTime(measurement: WindSpeedEvent) -> NSTimeInterval {
        return measurement.time.timeIntervalSinceDate(time)
    }
    
    func description(measurement: WindSpeedEvent) -> String {
        return "WindSpeedEvent (time rel:" + String(format: "% 5.2f", relativeTime(measurement)) + " speed:" + String(format: "% 5.2f", measurement.speed) + " UnixTime: \(measurement.time.timeIntervalSince1970))"
    }
}

func gustiness(speeds: [Double]) -> Double? {
    let n = Double(speeds.count)
    
    guard n > 0 else {
        return nil
    }

    let mean = speeds.reduce(0, combine: +)/n
    let squares = speeds.map { ($0 - mean)*($0 - mean) }
    let variance = squares.reduce(0, combine: +)/(n - 1)
    
//    let variance: Double = speeds.reduce(0) { $0 + ($1 - mean)*($1 - mean) }/(n - 1)
    
    return variance/mean
}




