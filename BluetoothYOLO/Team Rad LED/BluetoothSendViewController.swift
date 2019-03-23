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
    @IBOutlet weak var sensitivitySlider: UISlider!
    @IBOutlet weak var strengthSlider: UISlider!
    
    @IBOutlet weak var sensitivityInfoButton: UIButton!
    @IBOutlet weak var strengthInfoButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set sliders to show the values assigned to them
        sensitivitySlider.setValue(bluetoothParams.sensitivity, animated: true)
        strengthSlider.setValue(Float(bluetoothParams.strength) / 255.0, animated: true)

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
    
    @IBAction func showSensitivityInfo(_ sender: Any) {
        let sensitivityInfoController = UIAlertController(title: "Sensitivity", message: "The alarm sensitivity controls how often you will be alerted. Low sensitivity is best for urban areas and high sensitivitity is best for rural.", preferredStyle: .alert)
        sensitivityInfoController.addAction(UIAlertAction(title: "Dismiss", style: .default))
        
        self.present(sensitivityInfoController, animated: true, completion: nil)
    }
    
    @IBAction func showStrengthInfo(_ sender: Any) {
        let strengthInfoController = UIAlertController(title: "Strength", message: "The alarm strength controls how strong the vibration feedback is.", preferredStyle: .alert)
        strengthInfoController.addAction(UIAlertAction(title: "Dismiss", style: .default))
        
        self.present(strengthInfoController, animated: true, completion: nil)
    }
}
