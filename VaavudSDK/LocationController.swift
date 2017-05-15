//
//  LocationController.swift
//  Vaavud
//
//  Created by Gustaf Kugelberg on 26/08/15.
//  Copyright (c) 2015 Andreas Okholm. All rights reserved.
//

import Foundation
import CoreLocation

class LocationController: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
	
    private weak var listener1: LocationListener?
    private weak var listener2: LocationListener?
    private var listeners: [LocationListener] { return [listener1, listener2].reduce([LocationListener]()) { if let l = $1 { return $0 + [l] } else { return $0 } } }

    func addListener(listener: LocationListener) {
        if listener1 == nil { listener1 = listener } else { listener2 = listener }
    }
    
    func start() throws {
        let status = CLLocationManager.authorizationStatus()
        if status == .denied || status == .restricted {
            throw VaavudOtherError.LocationAuthorisation(status)
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.distanceFilter = 1
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        locationManager.headingFilter = 1
        
        if UIDevice.current.orientation == .portraitUpsideDown {
            locationManager.headingOrientation = .portraitUpsideDown
        }
        locationManager.startUpdatingHeading()
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard status != .denied && status != .notDetermined && status != .restricted else { return }
        locationManager.startUpdatingHeading()
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let loc = locations.last!
        
        _ = listeners.map { $0.newLocation(event: LocationEvent(location: loc)) }
        
        
        if  loc.course >= 0 && loc.speed >= 0 {
            _ = listeners.map { $0.newVelocity(event: VelocityEvent(time: loc.timestamp, speed: locationManager.location!.speed, course: locationManager.location!.course)) }
        }
    
        if loc.altitude >= 0 {
            _ = listeners.map {$0.newAltitude(event: AltitudeEvent(altitude: loc.altitude))}
        }
        
//                if loc.course >= 0 {
        _ = listeners.map {$0.newCourse(event: CourseEvent(course: locationManager.location!.course))}
        //        }

    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        _ = listeners.map { $0.newHeading(event: HeadingEvent(heading: newHeading.trueHeading)) }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        _ = listeners.map { $0.newError(event: ErrorEvent(eventType: .LocationManagerFailure(error as NSError))) }

    }
    
    deinit {
        print("DEINIT Location Controller")
    }
}
