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

public class VaavudSDK: WindListener, LocationListener {
    public static let shared = VaavudSDK()
    
    private var windController = WindController()
    private var locationController = LocationController()
    
    public private(set) var session = VaavudSession()
    // For now we make the callbacks static functions as weird stuff is happening when they are instance variables.
    // E.g. assigning even an empty callback to any of them causes location and heading services to stop working ???
    // We should understand the root cause, but for now we need the quick fix to support the sailor app.
    public static var windSpeedCallback: (WindSpeedEvent -> Void)?
    public static var trueWindSpeedCallback: (WindSpeedEvent -> Void)? // fixme: implement
    public static var windDirectionCallback: (WindDirectionEvent -> Void)?
    public static var trueWindDirectionCallback: (WindDirectionEvent -> Void)? // fixme: implement
    
    public static var temperatureCallback: (TemperatureEvent -> Void)? // fixme: implement
    public static var pressureCallback: (PressureEvent -> Void)? // fixme: implement

    public static var headingCallback: (HeadingEvent -> Void)?
    public static var locationCallback: (LocationEvent -> Void)?
    public static var velocityCallback: (VelocityEvent -> Void)?
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
        
        locationController.stop()
        
        do { try windController.start(false) }
        catch { return false }
        
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
        }
        catch {
//            newError(ErrorEvent(eventType: xx))
            throw error
        }
    }
    
    public func startLocationOnly() throws {
        reset()
        try locationController.start()
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
        session.addPressure(event)
        VaavudSDK.pressureCallback?(event)
    }

    // MARK: Temperature listener
    
    func newTemperature(event: TemperatureEvent) {
        session.addTemperature(event)
        VaavudSDK.temperatureCallback?(event)
    }
    
    // MARK: Location listener

    func newHeading(event: HeadingEvent) {
        session.addHeading(event)
        VaavudSDK.headingCallback?(event)
    }
    
    func newLocation(event: LocationEvent) {
        session.addLocation(event)
        VaavudSDK.locationCallback?(event)
    }
    
    func newVelocity(event: VelocityEvent) {
        session.addVelocity(event)
        VaavudSDK.velocityCallback?(event)
    }
    
    // MARK: Wind listener
    
    public func newWindSpeed(event: WindSpeedEvent) {
        session.addWindSpeed(event)
        VaavudSDK.windSpeedCallback?(event)
    }
    
    func newTrueWindWindSpeed(event: WindSpeedEvent) {
        session.addTrueWindSpeed(event)
        VaavudSDK.trueWindSpeedCallback?(event)
    }

    func newWindDirection(event: WindDirectionEvent) {
        session.addWindDirection(event)
        VaavudSDK.windDirectionCallback?(event)
    }
    
    func newTrueWindDirection(event: WindDirectionEvent) {
        session.addTrueWindDirection(event)
        VaavudSDK.trueWindDirectionCallback?(event)
    }
    
    func debugPlot(valuess: [[CGFloat]]) {
        debugPlotCallback?(valuess)
    }
    
    public func test() {
        VaavudSDK.windSpeedCallback?(WindSpeedEvent(time: NSDate(), speed: 123))
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
    
    public var meanSpeed: Double { return windSpeeds.count > 0 ? windSpeedSum/Double(windSpeeds.count) : 0 }

    public var maxSpeed: Double = 0

    public var turbulence: Double? {
        return gustiness(windSpeeds.map { $0.speed })
//        return (windSpeedSquaredSum - windSpeedSum*windSpeedSum)/meanSpeed
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

    // Wind data
    
    mutating func addWindSpeed(event: WindSpeedEvent) {
        windSpeeds.append(event)

        let speed = event.speed
        windSpeedSum += speed
        windSpeedSquaredSum += speed*speed
        
        if speed > maxSpeed {
            maxSpeed = speed
        }
        
//        print("Session addWindSpeed \(event.speed) mean: \(meanSpeed)")

        // Fixme: Changing update frequency should be considered
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


public class VaavudLegacySDK: NSObject {
    //public static let shared = VaavudLegacySDK()

    public var windSpeedCallback: ((Double, NSDate) -> Void)?
    public var windDirectionCallback: ((Double, NSDate) -> Void)?
    public var trueWindSpeedCallback: (WindSpeedEvent -> Void)?
    public var trueWindDirectionCallback: (WindDirectionEvent -> Void)? // fixme: implement
    public var temperatureCallback: (TemperatureEvent -> Void)? // fixme: implement
    public var pressureCallback: (PressureEvent -> Void)? // fixme: implement
    public var headingCallback: ((Double, NSDate) -> Void)?
    public var locationCallback: ((Double, Double, NSDate) -> Void)?
    public var velocityCallback: ((Double, Double, NSDate) -> Void)?
    public var errorCallback: (ErrorEvent -> Void)?
    public var foo: Double = 10;

    private override init() {
        super.init()

        VaavudSDK.windSpeedCallback = { self.windSpeedCallback?($0.speed, $0.time) }
        VaavudSDK.windDirectionCallback = { self.windDirectionCallback?($0.direction, $0.time) }
        // VaavudSDK.shared.headingCallback = { self.headingCallback?($0.heading, $0.time) }
        // VaavudSDK.shared.locationCallback = { self.locationCallback?($0.lat, $0.lon, $0.time) }
        //VaavudSDK.shared.velocityCallback = { self.velocityCallback?($0.speed, $0.course, $0.time) }


    }
    
    public func start() {
        dispatch_async(dispatch_get_main_queue()) {
            do {
                try VaavudSDK.shared.start(false);
            } catch _ {
                print("Error starting sdk")
            }
        }
        sleep(1)
    }
    
    public func stop() {
        dispatch_async(dispatch_get_main_queue()) {
            VaavudSDK.shared.stop();
        }

    }

    
    public func test() {
        VaavudSDK.shared.test()
    }
    
    public func sleipnirAvailable() -> Bool {
        return true;
        return VaavudSDK.shared.sleipnirAvailable()
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


