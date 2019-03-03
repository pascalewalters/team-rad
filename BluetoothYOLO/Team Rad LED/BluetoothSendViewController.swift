//
//  BluetoothSendViewController.swift
//  CycleSafe
//
//  Created by Pascale Walters on 2019-03-02.
//  Copyright © 2019 Vanguard Logic LLC. All rights reserved.
//

import UIKit
import Foundation

class BluetoothSendViewController: UIViewController {
    
    //UI
    @IBOutlet weak var back: UIButton!
    @IBOutlet weak var sensitivitySlider: UISlider!
    @IBOutlet weak var strengthSlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func sensitivityValueChanged(_ slider: UISlider) {
        let sensitivity = Float(slider.value)
        print("Sensitivity: \(sensitivity)")
        bluetoothParams.sensitivity = sensitivity
    }
    
    @IBAction func strengthValueChanged(_ slider: UISlider) {
        let strength = Int(slider.value * 255)
        print("Strength: \(strength)")
        bluetoothParams.strength = strength
    }
}
