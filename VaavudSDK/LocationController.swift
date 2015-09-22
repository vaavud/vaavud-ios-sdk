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
        if status == .Denied || status == .Restricted {
            throw VaavudError.LocationAuthorisation(status)
        }
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.distanceFilter = 10
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        locationManager.headingFilter = 5
        
        if UIDevice.currentDevice().orientation == .PortraitUpsideDown {
            locationManager.headingOrientation = .PortraitUpsideDown
        }
        locationManager.startUpdatingHeading()
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    // fixme
//    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        _ = locations.map { loc in
//            print("LC: latitude: \(loc.coordinate.latitude) and longitude: \(loc.coordinate.longitude)")
//        }
//    }
    
    func locationManager(manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        _ = listeners.map { $0.newHeading(HeadingEvent(heading: newHeading.trueHeading)) }
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
//        print(error.debugDescription)
        // fixme: send error event?
        _ = listeners.map { $0.newError(ErrorEvent(eventType: .LocationManagerFailure(error))) }
    }
    
    // fixme
    deinit {
        // perform the deinitialization
        print("DEINIT Location Controller")
    }
}




