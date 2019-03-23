//
//  HomeScreen.swift
//  CycleSafe
//
//  Created by Pascale Walters on 2019-03-02.
//  Copyright © 2019 Vanguard Logic LLC. All rights reserved.
//

import UIKit
import CoreBluetooth

class HomeScreen: UIViewController {

    @IBOutlet weak var startRideButton: UIButton!
    @IBOutlet weak var sensitivityButton: UIButton!
    @IBOutlet weak var pairButton: UIButton!
    
    var peripheral: CBPeripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        startRideButton.layer.cornerRadius = 8
        startRideButton.clipsToBounds = true
        startRideButton.widthAnchor.constraint(equalToConstant: 175.0).isActive = true
        
        sensitivityButton.layer.cornerRadius = 8
        sensitivityButton.clipsToBounds = true
        sensitivityButton.widthAnchor.constraint(equalToConstant: 175.0).isActive = true
        
        pairButton.layer.cornerRadius = 8
        pairButton.clipsToBounds = true
        pairButton.widthAnchor.constraint(equalToConstant: 175.0).isActive = true
    }

    @IBAction func clickStartRide(_ sender: Any) {
        if bluetoothParams.peripheral == nil {
            let unpairedWarningController = UIAlertController(title: "Warning", message: "You need to pair your device.", preferredStyle: .alert)
            unpairedWarningController.addAction(UIAlertAction(title: "Dismiss", style: .default))
            
            self.present(unpairedWarningController, animated: true, completion: nil)
        } else {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let yoloViewController = storyBoard.instantiateViewController(withIdentifier: "YoloView")
            
            self.present(yoloViewController, animated: true, completion: nil)
        }
    }
}
