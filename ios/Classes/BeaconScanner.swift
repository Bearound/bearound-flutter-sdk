//
//  BeaconScanner.swift
//  beaconDetector
//
//  Created by Arthur Sousa on 15/06/25.
//

import Foundation
import CoreBluetooth

class BeaconScanner: NSObject, CBCentralManagerDelegate {
    
    //-------------------------------
    // MARK: - Initial config
    //-------------------------------
    static let shared: BeaconScanner = BeaconScanner()
    
    //Accessable variables
    var delegate: BeaconActionsDelegate?
    
    //Internal variables
    private var isScanning: Bool
    private var cbManager: CBCentralManager!
    
    override init() {
        self.isScanning = false
        super.init()
        self.cbManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    deinit {
        self.stopScanning()
    }
    
    //-------------------------------
    // MARK: - Access Functions
    //-------------------------------
    func startScanning() {
        self.isScanning = true
    }
    
    func stopScanning() {
        self.isScanning = false
    }
    
    //-------------------------------
    // MARK: - Bluetooth Central Manager
    //-------------------------------
    func getCBManagerState() -> CBManagerState {
        return cbManager.state
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.cbManager = central
        switch cbManager.state {
        case .poweredOn:
            self.cbManager.scanForPeripherals(
                withServices: nil,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true
                ]
            )
        case .unauthorized:
            print("Permissão de Bluetooth negada")
        case .poweredOff:
            print("Bluetooth está desligado")
        case .unsupported:
            print("Dispositivo não suporta Bluetooth")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.contains("bearound") {
            guard let major = BeaconParser().getMajor(name) else { return }
            guard let minor = BeaconParser().getMinor(name) else { return }
            let address = peripheral.identifier.uuidString 
            let distance = BeaconParser().getDistanceInMeters(rssi: Float(truncating: RSSI))
            
            let beacon = Beacon(
                major: major,
                minor: minor,
                rssi: Int(truncating: RSSI),
                bluetoothName: name,
                bluetoothAddress: address,
                distanceMeters: distance,
                lastSeen: Date()
            )
            self.delegate?.updateBeaconList(beacon)
        }
    }
}
