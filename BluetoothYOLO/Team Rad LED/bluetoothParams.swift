//
//  bluetoothParams.swift
//  CycleSafe
//
//  Created by Pascale Walters on 2019-03-03.
//  Copyright © 2019 Vanguard Logic LLC. All rights reserved.
//

import Foundation
import CoreBluetooth

struct bluetoothParams {
    static var sensitivity = Float(0.3)
    
    static var strength = 100
    
    static var peripheral: CBPeripheral?
    
}
