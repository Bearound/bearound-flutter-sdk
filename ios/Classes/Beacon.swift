//
//  Beacon.swift
//  beaconDetector
//
//  Created by Arthur Sousa on 16/06/25.
//

import Foundation
import CoreBluetooth

public struct Beacon: Codable, Equatable {
    var uuid = UUID(uuidString: "E25B8D3C-947A-452F-A13F-589CB706D2E5")!
    var major: String
    var minor: String
    var rssi: Int
    var bluetoothName: String?
    var bluetoothAddress: String?
    var distanceMeters: Float?
    var lastSeen: Date
    
    public static func ==(lhs: Beacon, rhs: Beacon) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor
    }
}
