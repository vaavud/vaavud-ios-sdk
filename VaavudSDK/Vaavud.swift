//
//  VaavudSDK.swift
//  Pods
//
//  Created by Andreas Okholm on 24/06/15.
//
//

import Foundation

public class VaavudSDK: WindListener, TemperatureListener, LocationListener {
    private var windController = WindController()
    private var locationController = LocationController()
    
    public private(set) var session = VaavudSession()
    
    public var windSpeedCallback: (Result<WindSpeedEvent> -> Void)?
    public var windDirectionCallback: (Result<WindDirectionEvent> -> Void)?
    public var temperatureCallback: (Result<TemperatureEvent> -> Void)?
    public var headingCallback: (Result<HeadingEvent> -> Void)?

    public var debugPlotCallback: ([[CGFloat]] -> Void)?

    public init() {
        windController.addListener(self)
        
        locationController.addListener(windController)
        locationController.addListener(self)
    }
    
    public func sleipnirAvailable() -> Bool {
        var error = false
        if locationController.start() == nil { error = true }
        locationController.stop()
        
        if windController.start() == nil { error = true }
        windController.stop()
        return error
    }
    
    func reset() {
        session = VaavudSession()
    }
    
    public func start() -> ErrorEvent? {
        reset()
        if let startLocationError = locationController.start() {
            return startLocationError
        }
        return windController.start()
    }

    public func stop() {
        windController.stop()
    }
    
    public func resetWindDirectionCalibration() {
        windController.resetCalibration()
    }
    
    // MARK: Temperature listener
    
    func newTemperature(result: Result<TemperatureEvent>) {
        temperatureCallback?(result)
    }
    
    // MARK: Location listener

    func newHeading(result: Result<HeadingEvent>) {
        headingCallback?(result)
        
        if let event = result.value { session.addHeading(event) }
    }
    
    // MARK: Wind listener
    
    func newWindSpeed(result: Result<WindSpeedEvent>) {
        windSpeedCallback?(result)
        
        if let event = result.value { session.addWindSpeed(event) }
    }
    
    func newWindDirection(result: Result<WindDirectionEvent>) {
        windDirectionCallback?(result)
        
        if let event = result.value { session.addWindDirection(event) }
    }
    
    func debugPlot(valuess: [[CGFloat]]) {
        debugPlotCallback?(valuess)
    }
    
    deinit {
        // perform the deinitialization
        println("DEINIT VaavudSDK")
    }
}

public struct VaavudSession {
    public let time = NSDate()
    public var meanSpeed: Double { return windSpeedSum/Double(windSpeeds.count) }
    
    public private(set) var meanDirection: Double = 0
    public private(set) var windSpeeds = [WindSpeedEvent]()
    public private(set) var windDirections = [WindDirectionEvent]()
    public private(set) var headings = [HeadingEvent]()
    
    private var windSpeedSum: Double = 0

    mutating func addHeading(event: HeadingEvent) {
        headings.append(event)
    }
    
    mutating func addWindSpeed(event: WindSpeedEvent) {
        windSpeeds.append(event)
        windSpeedSum += event.speed
        // Update frequency should be considered! (sum should be speed*timeDelta)
    }
    
    mutating func addWindDirection(event: WindDirectionEvent) {
        windDirections.append(event)
    }
    
    public func relativeTime(measurement: WindSpeedEvent) -> NSTimeInterval {
        return measurement.time.timeIntervalSinceDate(time)
    }
    
    func description(measurement: WindSpeedEvent) -> String {
        return "WindSpeedEvent (time rel:" + String(format: "% 5.2f", relativeTime(measurement)) + " speed:" + String(format: "% 5.2f", measurement.speed) + " UnixTime: \(measurement.time.timeIntervalSince1970))"
    }
}