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
    
    func start() -> ErrorEvent? {
        if CLLocationManager.authorizationStatus() == .Denied {
            return ErrorEvent("Can not start since the app is not authorized to use location services, Denied", user: "Can not start since the app is not authorized to use location services, change phone settings!")
        }
        else if CLLocationManager.authorizationStatus() == .Restricted {
            return ErrorEvent("Can not start since the app is not authorized to use location services, Restricted", user: "Can not start since the app is not authorized to use location services")
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
        
        return nil
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if let locations = locations as? [CLLocation] {
            locations.map { loc in
                println("LC: latitude: \(loc.coordinate.latitude) and longitude: \(loc.coordinate.longitude)")
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateHeading newHeading: CLHeading!) {
        let event = Result(HeadingEvent(heading: newHeading.trueHeading))
        listeners.map { $0.newHeading(event) }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println(error.debugDescription)
    }
    
    deinit {
        // perform the deinitialization
        println("DEINIT Location Controller")
    }
}




