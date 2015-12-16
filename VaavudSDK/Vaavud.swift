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
        return VaavudSDK.shared.sleipnirAvailable()
    }
}

public class VaavudSDK: WindListener, TemperatureListener, LocationListener {
    public static let shared = VaavudSDK()
    
    private var windController = WindController()
    private var locationController = LocationController()
    
    public private(set) var session = VaavudSession()
    
    public var windSpeedCallback: (WindSpeedEvent -> Void)?
    public var windDirectionCallback: (WindDirectionEvent -> Void)?
    public var trueWindDirectionCallback: (WindDirectionEvent -> Void)?
    public var temperatureCallback: (TemperatureEvent -> Void)?
    public var pressureCallback: (PressureEvent -> Void)?
    public var headingCallback: (HeadingEvent -> Void)?
    public var locationCallback: (LocationEvent -> Void)?
    public var velocityCallback: (VelocityEvent -> Void)?
    public var errorCallback: (ErrorEvent -> Void)?

    public var debugPlotCallback: ([[CGFloat]] -> Void)?

    private init() {
        windController.addListener(self)
        
        locationController.addListener(windController)
        locationController.addListener(self)
    }
    
    public func sleipnirAvailable() -> Bool {
        do { try locationController.start() }
        catch { return false }
        
        do { try windController.start() }
        catch { return false; }
        
        stop()

        return true
    }
    
    func reset() {
        session = VaavudSession()
    }
    
    public func start() throws {
        reset()
        do {
            try locationController.start()
            try windController.start()
        }
        catch {
//            newError(ErrorEvent(eventType: ErrorEvent.ErrorEventType))
            throw error
        }
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
    
    func newPressure(event: PressureEvent) {
        pressureCallback?(event)
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
    
    func newVelocity(event: VelocityEvent) {
        velocityCallback?(event)
        session.addVelocity(event)
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
    
    func newTrueWindDirection(event: WindDirectionEvent) {
        trueWindDirectionCallback?(event)
        session.addTrueWindDirection(event)
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
    public private(set) var trueWindDirections = [WindDirectionEvent]()
    public private(set) var headings = [HeadingEvent]()
    public private(set) var locations = [LocationEvent]()
    public private(set) var velocities = [VelocityEvent]()
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

    mutating func addVelocity(event: VelocityEvent) {
        velocities.append(event)
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
    
    public func relativeTime(measurement: WindSpeedEvent) -> NSTimeInterval {
        return measurement.time.timeIntervalSinceDate(time)
    }
    
    func description(measurement: WindSpeedEvent) -> String {
        return "WindSpeedEvent (time rel:" + String(format: "% 5.2f", relativeTime(measurement)) + " speed:" + String(format: "% 5.2f", measurement.speed) + " UnixTime: \(measurement.time.timeIntervalSince1970))"
    }
}