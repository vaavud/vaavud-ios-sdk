//
//  VaavudSDK.swift
//  Pods
//
//  Created by Andreas Okholm on 24/06/15.
//
//

import Foundation
import CoreMotion
import RxSwift

//public class VaavudSleipnirAvailability: NSObject {
//    public class func available() -> Bool {
//        return VaavudSDK.shared.sleipnirAvailable()
//    }
//}

public class VaavudSDK: WindListener, LocationListener,BluetoothListener {
    
    public static let shared = VaavudSDK()
    
    private var windController = WindController() //sleipnir
    
    private var bluetoothController = BluetoothController() //Ultrasonic
    
    private var medianFilter = MedianFilter() //All
    private var locationController = LocationControllerRx() //All
    private var pressureController: CMAltimeter? = { return CMAltimeter.isRelativeAltitudeAvailable() ? CMAltimeter() : nil }() //All
    
    public private(set) var session: VaavudSession!
    
    
    public var windSpeedCallback: ((WindSpeedEvent) -> Void)?
    public var trueWindSpeedCallback: ((TrueWindSpeedEvent) -> Void)?
//    public var windDirectionCallback: ((WindDirectionEvent) -> Void)?
    public var windDirectionCallback = PublishSubject<WindDirectionEvent>()
    
    public var trueWindDirectionCallback: ((TrueWindDirectionEvent) -> Void)?
    public var bluetoothCallback: ((BluetoothEvent) -> Void)?
    public var bluetoothExtraCallback: ((BluetoothExtraEvent) -> Void)?
    
    
    public var pressureCallback: ((PressureEvent) -> Void)?
    public var headingCallback: ((HeadingEvent) -> Void)?
//    public var locationCallback: ((LocationEvent) -> Void)?
    public var locationCallback = PublishSubject<LocationEvent>()

    
    
    public var velocityCallback: ((VelocityEvent) -> Void)?
    public var altitudeCallback: ((AltitudeEvent) -> Void)?
    public var courseCallback: ((CourseEvent) -> Void)?
    
    
    private var lastDirection: WindDirectionEvent?
    public var lastSpeed: WindSpeedEvent?
    private var lastCourse: CourseEvent?
    private var lastVelocity: VelocityEvent?
    private var lastLocation: LocationEvent?
    
    public var errorCallback: ((ErrorEvent) -> Void)?

    public var debugPlotCallback: (([[CGPoint]]) -> Void)?
    
    
    private var measurmentPointTimer: Timer!

    public init() {
        windController.addListener(listener: self)
        locationController.mainListener = self
        locationController.windListener = windController
//        locationController.addListener(listener: windController)
//        locationController.addListener(listener: self)
//        bluetoothController.addListener(listener: self)
    }
    
    
    @objc func savePoint() {
        guard let lastSpeed = lastSpeed, let lastLocation = lastLocation else {
            return
        }
        let point = DataPoint(windSpeed: lastSpeed.speed, windDirection: lastDirection?.direction, location: lastLocation.fireDict)
        session.addPoint(point: point)
    }
    
//    public func sleipnirAvailable() -> Bool {
//        do { try locationController.start() }
//        catch { return false }
//        
//        locationController.stop()
//        
//        do { try windController.start(flipped: false) }
//        catch {
//            return false
//        }
//        
//        windController.stop()
//
//        return true
//    }
    
    
    func estimateTrueWind(time: Date) {
        
        let direction: Double? = lastDirection?.direction
        let speed: Double? = lastSpeed?.speed
        let course: Double? = lastCourse?.course
        let velocity: Double? = lastVelocity?.speed
        
        if let direction = direction, let speed = speed, let course = course, let velocity = velocity {

            let alpha = direction - course
            let rad = alpha * Double.pi / 180.0 //Radias
            
            let trueSpeed = sqrt(pow(speed,2.0) + pow(velocity,2) - 2.0 * speed * velocity * Double(cos(rad)) )
            
            if (trueSpeed >= 0) && !trueSpeed.isNaN {
                let trueSpeedEvent = TrueWindSpeedEvent(time: time, speed: trueSpeed)
                trueWindSpeedCallback?(trueSpeedEvent)
            } else {
                let trueSpeedEvent = TrueWindSpeedEvent(time: time, speed: speed)
                trueWindSpeedCallback?(trueSpeedEvent)

            }
            
            var trueDirection: Double
            if(0 < rad && Double.pi > rad) {
                let temp = ((speed * cos(rad)) - velocity) / trueSpeed
                trueDirection = acos(temp)
            }
            else{
                trueDirection = (-1) * acos(speed * Double(cos(rad)) - velocity / trueSpeed)
            }
            
            trueDirection = trueDirection * 180 / Double.pi
            
            if (trueDirection != -1) && !trueDirection.isNaN {
                let directionEvent = TrueWindDirectionEvent(direction: trueDirection)
                trueWindDirectionCallback?(directionEvent)
            }
            
            if let _ = lastSpeed, let _ = lastDirection {
                session.addTrueWindDirection(event: TrueWindDirectionEvent(direction: trueDirection))
                session.addTrueWindSpeed(event: TrueWindSpeedEvent(time: time, speed: trueSpeed))
            }
            
        } else {
            if let speed = speed {
                let trueSpeedEvent = TrueWindSpeedEvent(time: time, speed: speed)
                trueWindSpeedCallback?(trueSpeedEvent)
                session.addTrueWindSpeed(event: trueSpeedEvent)
            }
        }
    }

    
    func reset() {
        measurmentPointTimer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: (#selector(savePoint)), userInfo: nil, repeats: true)
        session = VaavudSession()
    }
    
    private var offset : [String:Any] = [:]
    public func startWithBluetooth(offset: [String:Any]) { //ultrasonic
        self.offset = offset
        reset()
        session.setWindMeter(vaavudDevice: .ultrasonic)
        
        locationController.start()
        medianFilter.clear()
        startPressure()
    }
    
        
    public func start(flipped: Bool) throws {  //sleipnir: flipped = front or back
        reset()
        do {
            session.setWindMeter(vaavudDevice: .sleipnir)
            locationController.start()
            try windController.start(flipped: flipped)
            startPressure()
        }
        catch {
//            newError(ErrorEvent(eventType: xx))
            throw error
        }
    }
    
    
    public func startLocationAndPressureOnly() { //mjolnir
        reset()
        session.setWindMeter(vaavudDevice: .mjolnir)
        locationController.start()
        startPressure()
    }
    
    
    private func startPressure() {
        pressureController?.startRelativeAltitudeUpdates(to: .main) {
            altitudeData, error in
            if let kpa = altitudeData?.pressure.doubleValue {
                self.newPressure(event: PressureEvent(pressure: kpa*1000))
            }
            else {
                print("CMAltimeter error")
            }
        }
    }
    
    
    public func stop() -> VaavudSession {
        
        measurmentPointTimer.invalidate()
        locationController.stop()
        pressureController?.stopRelativeAltitudeUpdates()
        
        if session.windMeter == .ultrasonic {
            //TODO
        }
        else if session.windMeter == .sleipnir {
            windController.stop()
        }
        
        return session
    }
    
    public func removeAllCallbacks() {
        windSpeedCallback = nil
        trueWindSpeedCallback = nil
//        windDirectionCallback = nil
        windDirectionCallback.dispose()
        trueWindDirectionCallback = nil
        bluetoothCallback = nil
        pressureCallback = nil
        headingCallback = nil
//        locationCallback = nil
        locationCallback.dispose()
        velocityCallback = nil
        errorCallback = nil
    }
    
    public func resetWindDirectionCalibration() {
        windController.resetCalibration()
    }
    
    // MARK: Common error event handling
    
    func newError(event error: ErrorEvent) {
        errorCallback?(error)
    }
    
    // MARK: Pressure listener
    
    func newPressure(event: PressureEvent) {
        session.addPressure(event: event)
        pressureCallback?(event)
    }
    
    // MARK: Location listener

    func newHeading(event: HeadingEvent) {
        session.addHeading(event: event)
        headingCallback?(event)
    }
    
    func newLocation(event: LocationEvent) {
        lastLocation = event
        session.addLocation(event: event)
//        locationCallback?(event)
        locationCallback.onNext(event)
    }
    
    func newVelocity(event: VelocityEvent) {
        session.addVelocity(event: event)
        velocityCallback?(event)
        lastVelocity = event
    }
    
    func newCourse(event: CourseEvent) {
        session.addCourse(event: event)
        courseCallback?(event)
        lastCourse = event
    }
    
    func newAltitude(event: AltitudeEvent) {
        session.addAltitude(event: event)
        altitudeCallback?(event)
    }
    
    
    // MARK: bluetooth listener
    
    
    public func newReading(event: BluetoothEvent) {
        
        medianFilter.addValues(newValue: event.windSpeed, newDirection: Int(event.windDirection))
        
        let windSpeedE = WindSpeedEvent(speed: event.windSpeed)
        let windDirectionE = WindDirectionEvent(direction: Double(event.windDirection))
        
        session.addWindSpeed(event: windSpeedE)
        session.addWindDirection(event: windDirectionE)
        
        lastSpeed = windSpeedE
        lastDirection = windDirectionE
        
        estimateTrueWind(time: event.time)

        
        bluetoothCallback?(event)
    }
    
    
    public func extraInfo(event: BluetoothExtraEvent) {
        bluetoothExtraCallback?(event)
    }

    
    
    // MARK: Wind listener
    
    public func newWindSpeed(event: WindSpeedEvent) {
        session.addWindSpeed(event: event)
        windSpeedCallback?(event)
        lastSpeed = event
        estimateTrueWind(time: event.time)
    }
    
    func newTrueWindWindSpeed(event: TrueWindSpeedEvent) {
        session.addTrueWindSpeed(event: event)
//        trueWindSpeedCallback?(event)
    }

    func newWindDirection(event: WindDirectionEvent) {
        session.addWindDirection(event: event)
//        windDirectionCallback?(event)
        windDirectionCallback.onNext(event)
        lastDirection = event
        if lastSpeed != nil {
            estimateTrueWind(time: lastSpeed!.time)
        }

    }
    
    func newTrueWindDirection(event: TrueWindDirectionEvent) {
        session.addTrueWindDirection(event: event)
//        trueWindDirectionCallback?(event)
    }
    
    func debugPlot(pointss valuess: [[CGPoint]]) {
        debugPlotCallback?(valuess)
    }
    
    deinit {
        print("DEINIT VaavudSDK")
    }
}






