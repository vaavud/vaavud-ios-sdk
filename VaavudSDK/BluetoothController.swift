//
//  BluetoothController .swift
//  VaavudSDK
//
//  Created by Diego Galindo on 2/20/17.
//  Copyright © 2017 Vaavud ApS. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxBluetoothKit


public enum BluetoothStatus {
    case on
    case off
    case unauthorized
}

public protocol IBluetoothManager {
    func onBleStatus(status: BluetoothStatus)
    func onBleReadyToWork()
    func onVaavudBleFound()
}

public struct Ultrasonic {
    public let windDirection: Int
    public let windSpeed: Double
    public let compass: Int
    public let battery: Int
    public let temperature: Int
    
    
    public var toDic: [String:Any] {
        var d : [String:Any] = [:]
        d["windDirection"] = windDirection
        d["windSpeed"] = windSpeed
        d["compass"] = compass
        d["battery"] = battery
        d["temperature"] = temperature
        
        return d
    }
}



public class BluetoothController: NSObject  {
    
    
    public override init() {}
    
    weak var listener: BluetoothListener?
    var bluetoothListner: IBluetoothManager!
    
    //Caracteristics
    let BEAN_DATA_UUID = CBUUID(string: "00002a39-0000-1000-8000-00805f9b34fb") // Datos
    let BEAN_BATTERY_STATUS_UUID = CBUUID(string: "0000a001-0000-1000-8000-00805f9b34fb") // Nivel de bateria 0) Standby 1)Low power 2)Normal
    let BEAN_ENABLE_SERVICES_UUID = CBUUID(string: "0000a003-0000-1000-8000-00805f9b34fb") // Activar 1
    let BEAN_ENABLE_COMPASS_UUID = CBUUID(string: "0000a008-0000-1000-8000-00805f9b34fb") // On/Off compass
    let BEAN_ADD_OFFSER_UUID = CBUUID(string: "0000a007-0000-1000-8000-00805f9b34fb") // Offset
    
    
    //Service
    let BEAN_SERVICE_UUID = CBUUID(string: "0000180d-0000-1000-8000-00805f9b34fb")
    
    
    //Ultrasonic connection
    var perifUltrasonic: Peripheral?
    
    //Main Service
    var mainService: Service?
    
    //Caracteristics from Main Service [rowData, calibrateCompass, ??]
    var caractRowData: Characteristic?
    var caractOffsetCompass: Characteristic?
    var caractEnableServices: Characteristic?
    
    
    //RxBluethooth
    private var scheduler: ConcurrentDispatchQueueScheduler!
    private let dispose = DisposeBag()
    
    
    let manager = BluetoothManager(queue: .main)
    
    

    public func onVerifyBle() -> Observable<BluetoothState> {
        
        let timerQueue = DispatchQueue(label: "com.vaavud.ble.timer")
        scheduler = ConcurrentDispatchQueueScheduler(queue:timerQueue)
        
        return manager.rx_state
            .filter { $0 == .poweredOn }
            .timeout(10.0, scheduler: scheduler)
            .take(1)
    }
    
    
    public let variable = Variable(false)
    
    public func onConnectDevice() -> Observable<[Service]> {
        
        return manager.scanForPeripherals(withServices: [self.BEAN_SERVICE_UUID])
            .timeout(10.0, scheduler: scheduler)
//            .filter{ $0.peripheral.identifier == UUID(uuidString: "2958CC31-1E64-484A-AC59-F52D4A0536C4")}  // TODO remove in release
            .take(1)
            .flatMap{$0.peripheral.connect()}
            .timeout(10.0, scheduler: scheduler)
            .flatMap{Observable.from(optional: $0)}
            .flatMap({ obs -> Observable<[Service]> in
                self.perifUltrasonic = obs
                return obs.discoverServices([self.BEAN_SERVICE_UUID])
            })
            .flatMap({ serv -> Observable<[Service]> in
                
                if let s = serv.last {
                    self.mainService = s
                }
                
                return Observable.from(optional: serv)

            })
    }
    
    
    public func onreadOnce() -> Observable<Characteristic> {
        return variable.asObservable()
            .filter{$0}
            .flatMap{_ in self.mainService!.discoverCharacteristics([self.BEAN_DATA_UUID])}
            .flatMap{Observable.from($0)}
            .flatMap{$0.readValue()}
    }
    
    
    public func activateSensores() {
        
        guard let service = mainService else {
            fatalError("No Main service connected")
        }
        
        service.discoverCharacteristics([BEAN_ENABLE_SERVICES_UUID])
            .flatMap{Observable.from($0)}
            .flatMap({obs -> Observable<Characteristic> in
                let bytes : [UInt8] = [0x01]
                let data = Data(bytes:bytes)
                print(data)
                return obs.writeValue(data, type: .withResponse)
            }).subscribe(onNext: {
                print($0)
                self.variable.value = true
            })
    }
    
    
    public func readRowData() -> Observable<Characteristic> {
        return variable.asObservable()
            .filter{$0 == true}
            .flatMap{_ in self.mainService!.discoverCharacteristics([self.BEAN_DATA_UUID])}
            .flatMap{Observable.from($0)}
            .flatMap{ dt -> Observable<Characteristic> in
                self.caractRowData = dt
                return dt.setNotificationAndMonitorUpdates()
            }
    }
    
    
    public func calibrationCompass(activate: Data) -> Observable<Characteristic> {
        guard let service = mainService else {
            fatalError("No Main service connected")
        }
        
        return service.discoverCharacteristics([BEAN_ENABLE_COMPASS_UUID])
            .flatMap{Observable.from($0)}
            .flatMap({obs -> Observable<Characteristic> in
                print(activate)
                return obs.writeValue(activate, type: .withResponse)
            })
    }
    
    
    public func readOffSet() {
        self.mainService!.discoverCharacteristics([BEAN_ADD_OFFSER_UUID])
        .flatMap{Observable.from($0)}
        .flatMap{$0.readValue()}
            .subscribe(onNext: {
                print("offset")
                print($0.value!.hexEncodedString())
            }, onError: {
                print("offset Errpr")
                print($0)
            }, onCompleted: {
                print("offset final")
                
            })
    }

    
    public func addOffset(activate: Data) -> Observable<Characteristic> {
        guard let service = mainService else {
            fatalError("No Main service connected")
        }
        
        return service.discoverCharacteristics([BEAN_ADD_OFFSER_UUID])
            .flatMap{Observable.from($0)}
            .flatMap({obs -> Observable<Characteristic> in
                return obs.writeValue(activate, type: .withResponse)
            })
    }
    
    
    public func onDispose() {
        if let rowData = caractRowData {
            rowData.setNotifyValue(false)
                .subscribe(onNext: {
                    print("cancelled")
                    print($0)
                })
                .disposed(by: dispose)
        }
        
        if let per = perifUltrasonic {
            per.cancelConnection()
                .subscribe(onNext: {
                    print("cancelled")
                    print($0)
                })
                .disposed(by: self.dispose)
        }
        
        variable.value = false
        caractRowData = nil
        perifUltrasonic = nil
        mainService = nil
        caractOffsetCompass = nil
    }
    
    deinit {
        print("deinit bluethooth")
    }
    
    
    func onConnect() -> Observable<Any> {

        let timerQueue = DispatchQueue(label: "com.vaavud.ble.timer")
        scheduler = ConcurrentDispatchQueueScheduler(queue:timerQueue)
        
        let manager = BluetoothManager(queue: .main)
        return manager.rx_state
            .filter { $0 == .poweredOn }
            .timeout(10.0, scheduler: scheduler)
            .take(1)
            .flatMap { _ in manager.scanForPeripherals(withServices: [self.BEAN_SERVICE_UUID]) }
            .timeout(10.0, scheduler: scheduler)
            .do(onNext: {
                print($0)
            }, onError: {
                print($0)
            }, onCompleted: {
                 print($0)
            }, onSubscribe: {
                 print($0)
            }, onSubscribed: {
                 print($0)
            })
            .take(1)
            .flatMap{$0.peripheral.connect()}
            .flatMap{Observable.from(optional: $0)}
            .flatMap({ obs -> Observable<[Service]> in
                self.perifUltrasonic = obs
                return obs.discoverServices([self.BEAN_SERVICE_UUID])
            })
            .flatMap{Observable.from(optional: $0)}
    }
    
    // MARK: Extra functions
    
    
    

    
//    public func workWithRowData(val: String){
//        print(val)
//        
//        //Speed
//        let s10 = val.substring(from: 0, to: 1)
//        let s11 = val.substring(from: 2, to: 3)
//        let h1 = Int(s11.appending(s10), radix: 16)
//        let _h1 = Double(h1!) / 100
//        
//        print("speed: \(_h1)")
//        
//        //Direction
//        let s20 = val.substring(from: 4, to: 5)
//        let s21 = val.substring(from: 6, to: 7)
//        let h2 = Int(s21.appending(s20), radix: 16)!
//        print("Direction: \(h2)")
//        
//        //Battery
//        let s30 = val.substring(from: 8, to: 9)
//        let h3 = Int(s30, radix: 16)! * 10
//        print("Battery: \(h3)")
//        
//        //Temperature
//        let s40 = val.substring(from: 10, to: 11)
//        let h4 = Int(s40, radix: 16)! - 100
//        print("Temperataure: \(h4)")
//        
//        
//        //Escora
//        let s50 = val.substring(from: 12, to: 13)
//        let h5 = Int(s50, radix: 16)! - 90
//        print("Escora: \(h5)")
//        
//        
//        //Cabeceo
//        let s60 = val.substring(from: 14, to: 15)
//        let h6 = Int(s60, radix: 16)! - 90
//        print("Cabeceo: \(h6)")
//        
//        
//        //Compass
//        let s70 = val.substring(from: 16, to: 17)
//        let s71 = val.substring(from: 18, to: 19)
//        
//        let h7 = Int(s71.appending(s70) , radix: 16)!
//        print("Compass: \(h7)")
//        //                print(Date().ms)
//        
//    }
    
    
    public class func workWithRowData(val: String) -> Ultrasonic {
        
        //    print(val)
        
        //Speed
        let s10 = val.substring(from: 0, to: 1)
        let s11 = val.substring(from: 2, to: 3)
        let h1 = Int(s11.appending(s10), radix: 16)
        let windSpeed = Double(h1!) / 100
        
        //    print("speed: \(_h1)")
        
        //Direction
        let s20 = val.substring(from: 4, to: 5)
        let s21 = val.substring(from: 6, to: 7)
        let windDirection = Int(s21.appending(s20), radix: 16)!
        //    print("Direction: \(h2)")
        
        //Battery
        let s30 = val.substring(from: 8, to: 9)
        let h3 = Int(s30, radix: 16)! * 10
        //    print("Battery: \(h3)")
        
        //    //Temperature
        let s40 = val.substring(from: 10, to: 11)
        let h4 = Int(s40, radix: 16)! - 100
        //    print("Temperataure: \(h4)")
        //
        //
        //    //Escora
        //    let s50 = val.substring(from: 12, to: 13)
        //    let h5 = Int(s50, radix: 16)! - 90
        //    print("Escora: \(h5)")
        //
        //
        //    //Cabeceo
        //    let s60 = val.substring(from: 14, to: 15)
        //    let h6 = Int(s60, radix: 16)! - 90
        //    print("Cabeceo: \(h6)")
        
        
        //Compass
        let s70 = val.substring(from: 16, to: 17)
        let s71 = val.substring(from: 18, to: 19)
        let compass = Int(s71.appending(s70) , radix: 16)!
        
        //    print("Compass: \(h7)")
        
        return Ultrasonic(windDirection: windDirection, windSpeed: windSpeed, compass: compass, battery: h3, temperature: h4)
    }
    
    
}


