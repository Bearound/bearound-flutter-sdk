//
//  BeaconParser.swift
//  beaconDetector
//
//  Created by Arthur Sousa on 16/06/25.
//

import Foundation

class BeaconParser {
    
    func getMajor(_ name: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: #"m(\d+)\.(\d+)"#),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
            if let majorRange = Range(match.range(at: 1), in: name) {
                let major = Int(name[majorRange]) ?? 0
                return String(major)
            }
        }
        return nil
    }
    
    func getMinor(_ name: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: #"m(\d+)\.(\d+)"#),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
            if let majorRange = Range(match.range(at: 1), in: name) {
                let major = Int(name[majorRange]) ?? 0
                return String(major)
            }
        }
        return nil
    }
    
    func getDistanceInMeters(rssi: Float, txPower: Float = -59) -> Float? {
        if rssi == 0 { return -1 } // RSSI inválido
        
        let ratio = rssi / txPower
        if ratio < 1 {
            return pow(ratio, 10)
        } else {
            return 0.89976 * pow(ratio, 7.7095) + 0.111
        }
    }
}
