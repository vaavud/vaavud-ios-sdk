//
//  LocationControllerRx.swift
//  VaavudSDK
//
//  Created by Diego Galindo on 5/17/17.
//  Copyright © 2017 Vaavud ApS. All rights reserved.
//

import Foundation
import RxSwift
import CoreLocation


class LocationControllerRx {
    
    var locationManager = CLLocationManager()
    var locationDisponsable: Disposable!
    var headingDisponsable: Disposable!
    var errorDisponsable: Disposable!
    public weak var mainListener: LocationListener?
    public weak var windListener: LocationListener?
    
    
    deinit {
        print("DEINIT:: LocationControllerRx")
    }
    
    
    func stop() {
        locationDisponsable.dispose()
        headingDisponsable.dispose()
        errorDisponsable.dispose()
        
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }
    
    
    func start() {
        
        //        headingDisponsable = locationManager.rx
        //            .didChangeAuthorizationStatus
        //            .filter {
        //                print($0)
        //                return $0 == .authorizedWhenInUse
        //            }
        //            .flatMap { _ in self.locationManager.rx.didUpdateHeading}
        headingDisponsable = self.locationManager.rx.didUpdateHeading.subscribe(onNext: {
            self.mainListener?.newHeading(event: HeadingEvent(heading: $0.trueHeading))
            self.windListener?.newHeading(event: HeadingEvent(heading: $0.trueHeading))
        },onDisposed: {
            print("onDisposed")
        })
        
        //        locationDisponsable = locationManager.rx
        //            .didChangeAuthorizationStatus
        //            .filter { $0 == .authorizedWhenInUse}
        //            .flatMap { _ in self.locationManager.rx.didUpdateLocations}
        locationDisponsable = self.locationManager.rx.didUpdateLocations.subscribe(onNext: {
            if let latlon = $0.last {
                
                if latlon.course > 0 {
                    self.mainListener?.newCourse(event: CourseEvent(course: latlon.course))
                }
                
                if latlon.speed > 0 && latlon.course > 0 {
                    self.mainListener?.newVelocity(event: VelocityEvent(speed: latlon.speed, course: latlon.course))
                }
                
                if latlon.altitude > 0 {
                    self.mainListener?.newAltitude(event: AltitudeEvent(altitude: latlon.altitude))
                }
                
                self.mainListener?.newLocation(event: LocationEvent(lat: latlon.coordinate.latitude, lon: latlon.coordinate.longitude, altitude: latlon.altitude))
            }
        },onDisposed: {
            print("onDisposed 2")
        })
        
//        errorDisponsable = locationManager.rx
//            .didChangeAuthorizationStatus
//            .filter { $0 == .authorizedWhenInUse}
//            .flatMap { _ in self.locationManager.rx.didFailWithError}
           errorDisponsable = self.locationManager.rx.didFailWithError
                .subscribe(onNext: {
                self.mainListener?.newError(event: ErrorEvent(eventType: .LocationManagerFailure($0 as NSError)))
            })
        
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = 5
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        locationManager.headingFilter = 10
        locationManager.startUpdatingHeading()
        
        if UIDevice.current.orientation == .portraitUpsideDown {
            locationManager.headingOrientation = .portraitUpsideDown
        }
    }
    
}
