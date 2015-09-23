//
//  VaavudSDK.swift
//  Pods
//
//  Created by Andreas Okholm on 24/06/15.
//
//

import Foundation

public class VaavudSleipnirAvailability: NSObject {
    public class func available() -> Bool {
        return VaavudSDK.sharedInstance.sleipnirAvailable()
    }
}

public class VaavudSDK: WindListener, TemperatureListener, LocationListener {
    public static let sharedInstance = VaavudSDK()
    
    private var windController = WindController()
    private var locationController = LocationController()
    
    public private(set) var session = VaavudSession()
    
    public var windSpeedCallback: (WindSpeedEvent -> Void)?
    public var windDirectionCallback: (WindDirectionEvent -> Void)?
    public var temperatureCallback: (TemperatureEvent -> Void)?
    public var headingCallback: (HeadingEvent -> Void)?
    public var locationCallback: (LocationEvent -> Void)?
    public var courseCallback: (CourseEvent -> Void)?
    public var speedCallback: (SpeedEvent -> Void)?
    public var errorCallback: (ErrorEvent -> Void)?

    public var debugPlotCallback: ([[CGFloat]] -> Void)?

    init() {
        windController.addListener(self)
        
        locationController.addListener(windController)
        locationController.addListener(self)
    }
    
    public func sleipnirAvailable() -> Bool {
        do { try locationController.start() }
        catch { return false }
        
        do { try windController.start() }
        catch { return false }

        return true
    }
    
    func reset() {
        session = VaavudSession()
    }
    
    public func start() throws {
        reset()
        try locationController.start()
        try windController.start()
    }

    public func stop() {
        windController.stop()
        locationController.stop()
    }
    
    public func resetWindDirectionCalibration() {
        windController.resetCalibration()
    }
    
    // MARK: Common error event handling
    
    func newError(error: ErrorEvent) {
        errorCallback?(error)
    }
    
    // MARK: Pressure listener
    
    func newPressure(event: TemperatureEvent) {
        temperatureCallback?(event)
    }

    // MARK: Temperature listener
    
    func newTemperature(event: TemperatureEvent) {
        temperatureCallback?(event)
    }
    
    // MARK: Location listener

    func newHeading(event: HeadingEvent) {
        headingCallback?(event)
        session.addHeading(event)
    }
    
    func newLocation(event: LocationEvent) {
        locationCallback?(event)
        session.addLocation(event)
    }
    
    func newCourse(event: CourseEvent) {
        courseCallback?(event)
        session.addCourse(event)
    }
    
    func newSpeed(event: SpeedEvent) {
        speedCallback?(event)
        session.addSpeed(event)
    }
    
    // MARK: Wind listener
    
    func newWindSpeed(event: WindSpeedEvent) {
        windSpeedCallback?(event)
        session.addWindSpeed(event)
    }
    
    func newWindDirection(event: WindDirectionEvent) {
        windDirectionCallback?(event)
        session.addWindDirection(event)
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
    public var meanSpeed: Double { return windSpeedSum/Double(windSpeeds.count) }
    
    public private(set) var meanDirection: Double = 0
    public private(set) var windSpeeds = [WindSpeedEvent]()
    public private(set) var windDirections = [WindDirectionEvent]()
    public private(set) var headings = [HeadingEvent]()
    public private(set) var locations = [LocationEvent]()
    public private(set) var courses = [CourseEvent]()
    public private(set) var speeds = [SpeedEvent]()
    public private(set) var temperatures = [TemperatureEvent]()
    public private(set) var pressures = [PressureEvent]()
    
    private var windSpeedSum: Double = 0

    // Location data
    
    mutating func addHeading(event: HeadingEvent) {
        headings.append(event)
    }
    
    mutating func addLocation(event: LocationEvent) {
        locations.append(event)
    }

    mutating func addCourse(event: CourseEvent) {
        courses.append(event)
    }

    mutating func addSpeed(event: SpeedEvent) {
        speeds.append(event)
    }

    // Wind data
    
    mutating func addWindSpeed(event: WindSpeedEvent) {
        windSpeeds.append(event)
        windSpeedSum += event.speed
        // Update frequency should be considered! (sum should be speed*timeDelta)
    }
    
    mutating func addWindDirection(event: WindDirectionEvent) {
        windDirections.append(event)
    }
    
    // Temprature data

    mutating func addTemperature(event: TemperatureEvent) {
        temperatures.append(event)
    }
    
    // Pressure data

    mutating func addPressure(event: PressureEvent) {
        pressures.append(event)
    }
    
    public func relativeTime(measurement: WindSpeedEvent) -> NSTimeInterval {
        return measurement.time.timeIntervalSinceDate(time)
    }
    
    func description(measurement: WindSpeedEvent) -> String {
        return "WindSpeedEvent (time rel:" + String(format: "% 5.2f", relativeTime(measurement)) + " speed:" + String(format: "% 5.2f", measurement.speed) + " UnixTime: \(measurement.time.timeIntervalSince1970))"
    }
}