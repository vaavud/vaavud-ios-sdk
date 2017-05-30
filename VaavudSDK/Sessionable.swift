//
//  File.swift
//  VaavudSDK
//
//  Created by Diego Galindo on 5/16/17.
//  Copyright © 2017 Vaavud ApS. All rights reserved.
//

import Foundation
import RxSwift


class Sessionable: NSObject {
    
    public var lastSpeed: Variable<Double>!
    public var lastDirection: Variable<Double>!
    public var lastCourse: Variable<Double>!
    public var lastVelocity: Variable<Double>!
    
    
    
    
    let windSpeedCallback = PublishSubject<WindSpeedEvent>()
    let windDirectionCallback = PublishSubject<WindSpeedEvent>()
    let errorCallback = PublishSubject<ErrorEvent>()
    
    var session = VaavudSession()
    
    func startSdk() {
        fatalError("Start method should be overrided")
    }
    
    
    func stopSdk() {
        fatalError("Stop method should be overrided")
    }
    
    
    
    

}
