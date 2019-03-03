//
//  TTC.swift
//  CycleSafe
//
//  Created by Pascale Walters on 2019-03-03.
//  Copyright © 2019 Vanguard Logic LLC. All rights reserved.
//

import Foundation
import AVFoundation

public func momentary_ttc(w1: CGFloat, w2: CGFloat, time: CFTimeInterval) -> Double {
    let ttc = Double(time) / ((Double(w2) / Double(w1)) - 1.0)
    return ttc
}

public func acceleration_ttc(tm1: Double, tm2: Double, time: Double, C: Double) -> Double {
    let ttc = tm2 * ( (1 - (1 - 2*C).squareRoot()) / C )
    return ttc
}
