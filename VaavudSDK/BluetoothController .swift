//
//  BluetoothController .swift
//  VaavudSDK
//
//  Created by Diego Galindo on 2/20/17.
//  Copyright © 2017 Vaavud ApS. All rights reserved.
//

import Foundation
import CoreBluetooth


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


public class BluetoothController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    
    private weak var listener: BluetoothListener?
    private var bluetoothListner: IBluetoothManager!
    
    
    func addBleListener(listener: IBluetoothManager){
        bluetoothListner = listener
    }
    
    func addListener(listener: BluetoothListener) {
        self.listener = listener
    }
    
    
    var manager:CBCentralManager!
    var peripheral:CBPeripheral?
    
    let BEAN_NAME = "ULTRASONIC"
    
    
    //Caracteristics
    let BEAN_DATA_UUID = CBUUID(string: "00002a39-0000-1000-8000-00805f9b34fb") // Datos
    let BEAN_BATTERY_STATUS_UUID = CBUUID(string: "0000a001-0000-1000-8000-00805f9b34fb") // Nivel de bateria 0) Standby 1)Low power 2)Normal
    let BEAN_ENABLE_SERVICES_UUID = CBUUID(string: "0000a003-0000-1000-8000-00805f9b34fb") // Activar 1
//    let BEAN_SCRATCH_UUID = CBUUID(string: "0000a007-0000-1000-8000-00805f9b34fb") // Offset 
    
    
    //Service
    let BEAN_SERVICE_UUID = CBUUID(string: "0000180d-0000-1000-8000-00805f9b34fb")
    
    
    func start() {
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func stop() {
        if let p = peripheral {
            manager.cancelPeripheralConnection(p)
        }
        
        manager.stopScan()
        manager = nil
        peripheral = nil
    }
    
    
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey)as? NSString {
            
             print("device = \(device)")
            
            if device.contains(BEAN_NAME) == true {
                self.manager.stopScan()
                
                print("Connected")
                
                self.peripheral = peripheral
                self.peripheral!.delegate = self
                
                manager.connect(peripheral, options: nil)
            }
        }
    }
    
    
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral error = \(error)")
        central.scanForPeripherals(withServices: [BEAN_SERVICE_UUID], options: nil)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        print("didDiscoverIncludedServicesFor error = \(error)")
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("didFailToConnect error = \(error)")
    }
    
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Looking for : \(BEAN_SERVICE_UUID.uuidString)")
        peripheral.discoverServices([BEAN_SERVICE_UUID])
        bluetoothListner.onVaavudBleFound()
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        print("Service connected, try to caracteristics : \(peripheral.services![0].uuid.uuidString) error = \(error)")
        
        peripheral.discoverCharacteristics([BEAN_DATA_UUID,BEAN_ENABLE_SERVICES_UUID],for: peripheral.services![0])
        
        //        for service in peripheral.services! {
        //            let thisService = service as CBService
        //
        //            if service.uuid == BEAN_SERVICE_UUID {
        //                peripheral.discoverCharacteristics(
        //                    nil,
        //                    for: thisService
        //                )
        //            }
        //        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        for characteristic in service.characteristics! {
            
            if characteristic.uuid == BEAN_DATA_UUID {
                self.peripheral!.setNotifyValue(true,for: characteristic)
                bluetoothListner.onBleReadyToWork()
                print("characteristic data found ")
            }
            else if characteristic.uuid == BEAN_ENABLE_SERVICES_UUID {
//                let bytes : [UInt8] = [ 0x01 ]
//                let data = Data(bytes:bytes)
//                print(data)
//        
//                peripheral.writeValue(data, for: characteristic,type: .withResponse)
            }
        }
        
    }
  
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("didWriteValueForCharacteristic \(characteristic.uuid) error = \(error)")
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
            bluetoothListner.onBleStatus(status: .on)
        } else if central.state == .unauthorized {
            bluetoothListner.onBleStatus(status: .unauthorized)
        }
        else{
            bluetoothListner.onBleStatus(status: .off)
        }
    }
    
    
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("---")
        print("speed: \(error)")
        print("speed: \(characteristic.uuid)")
        print("---")
    }

    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic.uuid == BEAN_DATA_UUID {
            
            if let v = characteristic.value {
                let val = v.hexEncodedString()
                
//                print(val)
                
                //Speed
                let s10 = val.substring(from: 0, to: 1)
                let s11 = val.substring(from: 2, to: 3)
                let h1 = Int(s11.appending(s10), radix: 16)
                let _h1 = Double(h1!) / 100
                
//                print("speed: \(_h1)")
                
                
                //Direction
                let s20 = val.substring(from: 4, to: 5)
                let s21 = val.substring(from: 6, to: 7)
                let h2 = Int(s21.appending(s20), radix: 16)!
//                print("Direction: \(h2)")
                
                //Battery
                let s30 = val.substring(from: 8, to: 9)
                let h3 = Int(s30, radix: 16)! * 10
//                print("Battery: \(h3)")
                
                //Temperature
                let s40 = val.substring(from: 10, to: 11)
                let h4 = Int(s40, radix: 16)! - 100
//                print("Temperature: \(h4)")
                
                
                //Escora
                let s50 = val.substring(from: 12, to: 13)
                let h5 = Int(s50, radix: 16)! - 90
//                print("Escora: \(h5)")
                
                
                //Cabeceo
                let s60 = val.substring(from: 14, to: 15)
                let h6 = Int(s60, radix: 16)! - 90
//                print("Cabeceo: \(h6)")
                
                
                //Compass
                let s70 = val.substring(from: 16, to: 17)
                let h7 = Int(s70, radix: 16)! * 2
//                print("Compass: \(h7)")
//                print(Date().ms)
                
                
                if let l = listener {
                    l.newReading(event: BluetoothEvent(windSpeed: _h1, windDirection: h2,battery:h3))
//                    l.extraInfo(event: BluetoothExtraEvent(compass: h7, battery: h3))
                }
                
//                if let _loc = lastLocation {
//                    let point = MeasurementPoint(speed: _h1, direction: h2, location: _loc, timestamp: Date().ticks)
//                    measurementPoints.insert(point, at: 0)
//                }
//                self.sendEvent(withName: "onNewRead", body: ["windSpeed":_h1, "windDirection": h2, "battery": h3, "temperature": h4, "escora":h5, "cabeceo":h6, "compass":h7] )
            }
        }
    }
    
    
    

    
    deinit {
        print("DEINIT Bluetooth controller")
    }

}
