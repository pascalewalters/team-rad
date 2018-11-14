//
//  UartModuleViewController.swift
//  Basic Chat
//
//  Created by Trevor Beaton on 12/4/16.
//  Copyright © 2016 Vanguard Logic LLC. All rights reserved.
//





import UIKit
import CoreBluetooth
import Foundation

class UartModuleViewController: UIViewController, CBPeripheralManagerDelegate {
    
    //UI
    @IBOutlet weak var pin5Button: UIButton!
    @IBOutlet weak var pin6Button: UIButton!
    @IBOutlet weak var pin10Button: UIButton!
    @IBOutlet weak var pin11Button: UIButton!
    @IBOutlet weak var pin12Button: UIButton!
    @IBOutlet weak var pin13Button: UIButton!
    
    //Data
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    private var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"Back", style:.plain, target:nil, action:nil)
        //Create and start the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        //-Notification for updating the text view with incoming text
        updateIncomingData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        self.baseTextView.text = ""
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // peripheralManager?.stopAdvertising()
        // self.peripheralManager = nil
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        
    }
    
    func updateIncomingData () {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Notify"), object: nil , queue: nil){
            notification in
            let appendString = "\n"
            let myFont = UIFont(name: "Helvetica Neue", size: 15.0)
            let myAttributes2 = [NSFontAttributeName: myFont!, NSForegroundColorAttributeName: UIColor.red]
            let attribString = NSAttributedString(string: "[Incoming]: " + (characteristicASCIIValue as String) + appendString, attributes: myAttributes2)
            let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
            
            newAsciiText.append(attribString)
            
        }
    }
    
    @IBAction func clickToggle5(_ sender: AnyObject) {
        outgoingData5()
    }
    
    @IBAction func clickToggle6(_ sender: AnyObject) {
        outgoingData6()
    }
    
    @IBAction func clickToggle10(_ sender: AnyObject) {
        outgoingData10()
    }
    
    @IBAction func clickToggle11(_ sender: AnyObject) {
        outgoingData11()
    }
    
    @IBAction func clickToggle12(_ sender: AnyObject) {
        outgoingData12()
    }
    
    @IBAction func clickToggle13(_ sender: AnyObject) {
        outgoingData13()
    }
    
    var pin5IsOn = false
    var pin6IsOn = false
    var pin10IsOn = false
    var pin11IsOn = false
    var pin12IsOn = false
    var pin13IsOn = false
    
    func outgoingData5() {
        if pin5IsOn {
            writeValue2(data: "1", pin: 5)
        } else {
            writeValue2(data: "0", pin: 5)
        }
        
        pin5IsOn = !pin5IsOn
    }
    
    func outgoingData6() {
        if pin6IsOn {
            writeValue2(data: "1", pin: 6)
        } else {
            writeValue2(data: "0", pin: 6)
        }
        
        pin6IsOn = !pin6IsOn
    }
    
    func outgoingData10() {
        if pin10IsOn {
            writeValue2(data: "1", pin: 10)
        } else {
            writeValue2(data: "0", pin: 10)
        }
        
        pin10IsOn = !pin10IsOn
    }
    
    func outgoingData11() {
        if pin11IsOn {
            writeValue2(data: "1", pin: 11)
        } else {
            writeValue2(data: "0", pin: 11)
        }
        
        pin11IsOn = !pin11IsOn
    }
    
    func outgoingData12() {
        if pin12IsOn {
            writeValue2(data: "1", pin: 12)
        } else {
            writeValue2(data: "0", pin: 12)
        }
        
        pin12IsOn = !pin12IsOn
    }
    
    func outgoingData13() {
        if pin13IsOn {
            writeValue2(data: "1", pin: 13)
        } else {
            writeValue2(data: "0", pin: 13)
        }
        
        pin13IsOn = !pin13IsOn
    }
    
    // Write functions
//    func writeValue(data: String){
//        let data = "06:" + data
//        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
//        //change the "data" to valueString
//        if let blePeripheral = blePeripheral{
//            if let txCharacteristic = txCharacteristic {
//                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
//            }
//        }
//    }
    
    func writeValue2(data: String, pin: Int){
        let data = String(format: "%02d", pin) + ":" + data
        print(data)
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        //change the "data" to valueString
        if let blePeripheral = blePeripheral{
            if let txCharacteristic = txCharacteristic {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    func writeCharacteristic(val: Int8){
        var val = val
        let ns = NSData(bytes: &val, length: MemoryLayout<Int8>.size)
        blePeripheral!.writeValue(ns as Data, for: txCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    
    
    //MARK: UITextViewDelegate methods
//    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
//        if textView === baseTextView {
//            //tapping on consoleview dismisses keyboard
//            inputTextField.resignFirstResponder()
//            return false
//        }
//        return true
//    }
//
//    func textFieldDidBeginEditing(_ textField: UITextField) {
//        scrollView.setContentOffset(CGPoint(x:0, y:250), animated: true)
//    }
//
//    func textFieldDidEndEditing(_ textField: UITextField) {
//        scrollView.setContentOffset(CGPoint(x:0, y:0), animated: true)
//    }
//
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
    //Check when someone subscribe to our characteristic, start sending the data
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Device subscribe to characteristic")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("\(error)")
            return
        }
    }
}

