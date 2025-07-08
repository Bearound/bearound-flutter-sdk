//
//  BeaconTracker.swift
//  beaconDetector
//
//  Created by Arthur Sousa on 19/06/25.
//

import Foundation
import CoreLocation

@available(iOS 13.0, *)
class BeaconTracker: NSObject, CLLocationManagerDelegate {
    
    //-------------------------------
    // MARK: - Initial config
    //-------------------------------
    static let shared: BeaconTracker = BeaconTracker()
    
    //Accessable variables
    var delegate: BeaconActionsDelegate?
    
    //Internal variables
    private var locationManager: CLLocationManager
    private var beaconRegion: CLBeaconRegion
    
    override init() {
        self.locationManager = CLLocationManager()
        self.beaconRegion = CLBeaconRegion(uuid:  UUID(uuidString: "E25B8D3C-947A-452F-A13F-589CB706D2E5")!, identifier: "BeaconRegion")
        super.init()
        self.locationManager.delegate = self
        self.beaconRegion.notifyEntryStateOnDisplay = true
        self.beaconRegion.notifyOnEntry = true
        self.beaconRegion.notifyOnExit = true
    }
    
    //-------------------------------
    // MARK: - Access Functions
    //-------------------------------
    func startTracking() {
        locationManager.startMonitoring(for: beaconRegion)
        locationManager.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
    }
    
    func stopTracking() {
        locationManager.stopMonitoring(for: beaconRegion)
        locationManager.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
    }
    
    
    //-------------------------------
    // MARK: - Core Location Manager
    //-------------------------------
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
            startTracking()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        for beacon in beacons {
            let beacon = Beacon(
                major: String(describing: beacon.major),
                minor: String(describing: beacon.minor),
                rssi: beacon.rssi,
                bluetoothName: nil,
                bluetoothAddress: nil,
                distanceMeters: BeaconParser().getDistanceInMeters(rssi: Float(beacon.rssi)),
                lastSeen: Date()
            )
            self.delegate?.updateBeaconList(beacon)
        }
    }
}
