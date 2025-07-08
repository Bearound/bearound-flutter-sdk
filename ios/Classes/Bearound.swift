//
//  Bearound.swift
//  beaconDetector
//
//  Created by Arthur Sousa on 19/06/25.
//

import UIKit
import AdSupport
import CoreLocation

protocol BeaconActionsDelegate {
    func updateBeaconList(_ beacon: Beacon)
}

@available(iOS 13.0, *)
public class Bearound: BeaconActionsDelegate {
    private var clientToken: String
    private var beacons: Array<Beacon>
    
    public init(clientToken: String) {
        self.beacons = []
        self.clientToken = clientToken
        BeaconScanner.shared.delegate = self
        BeaconTracker.shared.delegate = self
    }
    
    func updateBeaconList(_ beacon: Beacon) {
        if let index = beacons.firstIndex(of: beacon) {
            beacons[index] = beacon
        } else {
            beacons.append(beacon)
        }
    }
    
    func removeBeacons(_ beacons: Array<Beacon>) {
        for beacon in beacons {
            self.beacons.removeAll { $0 == beacon }
        }
    }
}
