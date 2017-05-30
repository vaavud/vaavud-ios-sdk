//
//  BleSdk.swift
//  VaavudSDK
//
//  Created by Diego Galindo on 5/16/17.
//  Copyright © 2017 Vaavud ApS. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxBluetoothKit
import CoreLocation



class BleSdk: Sessionable {
    
    //Caracteristics
    let BEAN_DATA_UUID = CBUUID(string: "00002a39-0000-1000-8000-00805f9b34fb") // Datos
    let BEAN_BATTERY_STATUS_UUID = CBUUID(string: "0000a001-0000-1000-8000-00805f9b34fb") // Nivel de bateria 0) Standby 1)Low power 2)Normal
    let BEAN_ENABLE_SERVICES_UUID = CBUUID(string: "0000a003-0000-1000-8000-00805f9b34fb") // Activar 1
    let BEAN_ENABLE_COMPASS_UUID = CBUUID(string: "0000a008-0000-1000-8000-00805f9b34fb") // On/Off compass
    let BEAN_ADD_OFFSER_UUID = CBUUID(string: "0000a007-0000-1000-8000-00805f9b34fb") // Offset
    
    //Service
    let BEAN_SERVICE_UUID = CBUUID(string: "0000180d-0000-1000-8000-00805f9b34fb")
    
    
    private let manager = BluetoothManager(queue: .main)
    private var scheduler: ConcurrentDispatchQueueScheduler!
    
    
    public let servicesEnabled = Variable(false)
    private var mainService : Service?
    
    
    func connect() -> Observable<Bool> {
        return Observable.create { sub in
            
            
            let timerQueue = DispatchQueue(label: "com.vaavud.ble.timer")
            self.scheduler = ConcurrentDispatchQueueScheduler(queue:timerQueue)
            
            self.manager.rx_state
                .filter { $0 == .poweredOn }
                .timeout(10.0, scheduler: self.scheduler)
                .take(1)
                .flatMap { _ in self.manager.scanForPeripherals(withServices: [self.BEAN_SERVICE_UUID]) }
                .timeout(10.0, scheduler: self.scheduler)
                //            .filter{ $0.peripheral.identifier == UUID(uuidString: "2958CC31-1E64-484A-AC59-F52D4A0536C4")}  // TODO remove in realse
                .take(1)
                .flatMap{$0.peripheral.connect()}
                .timeout(10.0, scheduler: self.scheduler)
                .flatMap{$0.discoverServices([self.BEAN_SERVICE_UUID])}
                .subscribe(onNext: {
                    self.mainService = $0.last
                    sub.onNext(true)
                }, onError: {
                    print($0)
                }, onCompleted: {
                    sub.onCompleted()
                }).dispose()
            
            
            return Disposables.create()
        }
    }
    
    func readCharacteristic() -> Observable<Characteristic> {
        activateServives()
        
        return servicesEnabled
            .asObservable()
            .timeout(10, scheduler: scheduler)
            .filter{$0}
            .flatMap{ _ in self.mainService!.discoverCharacteristics([self.BEAN_DATA_UUID]) }
            .flatMap {Observable.from($0)}
        //            .flatMap { $0.readValue() }
    }
    
    
    func activateServives() {
        
        if servicesEnabled.value {
            return
        }
        
        mainService?.discoverCharacteristics([BEAN_ENABLE_SERVICES_UUID])
            .flatMap{Observable.from($0)}
            .flatMap({obs -> Observable<Characteristic> in
                let bytes : [UInt8] = [0x01]
                let data = Data(bytes:bytes)
                return obs.writeValue(data, type: .withResponse)
            }).subscribe(onNext: { _ in
                self.servicesEnabled.value = true
            }).dispose()
    }
    
    func addOffset(activate: Data) -> Observable<Characteristic>? {
        return mainService?.discoverCharacteristics([BEAN_ADD_OFFSER_UUID])
            .flatMap{Observable.from($0)}
            .flatMap { $0.writeValue(activate, type: .withResponse) }
    }
    
    override func startSdk() {
        
    }
    
    
    override func stopSdk() {
        //        return session
        //Kill everything
    }
}


class test {
    
    let ble = BleSdk()
    let disposeBag = DisposeBag()
    
    
    func initCallbacks() {
        
        let locationManager = CLLocationManager()
        locationManager.rx
            .didChangeAuthorizationStatus.filter { $0 == .authorizedWhenInUse }
            .flatMap{ _ in locationManager.rx.didUpdateLocations}
            .subscribe(onNext: {
                print($0.last?.coordinate)
            })

        
        
        
        
        ble.windSpeedCallback
            .asObserver()
            .subscribe(onNext: {
            print($0)
        }).addDisposableTo(disposeBag)
        
        
        ble.windDirectionCallback
            .asObserver()
            .delay(5, scheduler: MainScheduler.instance)
            .subscribe(onNext: {
                print($0)
            })
            .addDisposableTo(disposeBag)
    }
    
    
    public func initSdk() {
        ble.connect().subscribe(onNext: {
            print($0)
        }, onError: {
            print($0)
        }, onCompleted: {
        })
            .addDisposableTo(disposeBag)
    }
    
    
    func btnGetRowData() {
        ble
            .readCharacteristic()
            .flatMap{ $0.setNotificationAndMonitorUpdates() }
            .subscribe(onNext: {
                print($0) // print result
            }, onError: {
                print($0)
            }, onCompleted: {
                print("done")
            })
            .addDisposableTo(disposeBag)
    }
    
    
    func btnGetValues() {
        
        ble
            .readCharacteristic()
            .flatMap{ $0.readValue() }
            .subscribe(onNext: {
                print($0) // print result
            }, onError: {
                print($0)
            }, onCompleted: {
                print("done")
            })
            .addDisposableTo(disposeBag)
    }
    
    
    
}


