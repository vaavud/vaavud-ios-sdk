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
    public var errorCallback: (ErrorEvent -> Void)?

    public var debugPlotCallback: ([[CGFloat]] -> Void)?

    init() {
        windController.addListener(self)
        
        locationController.addListener(windController)
        locationController.addListener(self)
    }
    
    // fixme: ask: need to be stopped always?
    public func sleipnirAvailable() -> Bool {
        defer { locationController.stop() }

        do { try locationController.start() }
        catch { return false }
        
        defer { windController.stop() }
        
        do { try windController.start() }
        catch { return false }

        return true
    }
    
    func reset() {
        session = VaavudSession()
    }
    
    public func start() throws {
        reset()
        defer { locationController.stop() }
        try locationController.start()
        
        defer { windController.stop() }
        try windController.start()
    }

    public func stop() {
        windController.stop()
    }
    
    public func resetWindDirectionCalibration() {
        windController.resetCalibration()
    }
    
    // MARK: Common error event handling
    
    func newError(error: ErrorEvent) {
        errorCallback?(error)
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
        // perform the deinitialization
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