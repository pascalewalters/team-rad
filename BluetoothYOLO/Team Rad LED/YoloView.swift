//
//  YoloView.swift
//  CycleSafe
//
//  Created by Pascale Walters on 2019-03-02.
//  Copyright © 2019 Vanguard Logic LLC. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import CoreMedia
import CoreBluetooth

class YoloView: UIViewController, CBPeripheralManagerDelegate {
    
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var debugImageView: UIImageView!
    @IBOutlet weak var toggleDisplayButton: UIButton!
    
    var displayOn = true
    
    // How many predictions we can do concurrently.
    static let maxInflightBuffers = 3
    
    // Bluetooth stuff
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    var strength: Int!
    
    let yolo = YOLO()
    
    var videoCapture: VideoCapture!
    var requests = [VNCoreMLRequest]()
    var startTimes: [CFTimeInterval] = []
    
    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []
    
    let ciContext = CIContext()
    var resizedPixelBuffers: [CVPixelBuffer?] = []
    
    var framesDone = 0
    var frameCapturingStartTime = CACurrentMediaTime()
    
    var inflightBuffer = 0
    let semaphore = DispatchSemaphore(value: YoloView.maxInflightBuffers)
    
    private var lastObservation: [UUID: VNDetectedObjectObservation] = [:]
    private var trackingRequests: [VNTrackObjectRequest] = []
    private var visionSequenceHandler = VNSequenceRequestHandler()
    
    private var width1: [UUID: CGFloat] = [:]
    private var time1: [UUID: CFTimeInterval] = [:]
    private var width2: [UUID: CGFloat] = [:]
    private var time2: [UUID: CFTimeInterval] = [:]
    private var t_m1: [UUID: Double] = [:]
    private var t_m2: [UUID: Double] = [:]
    //  private var t_a = 0.0
    private var t_a: [UUID: Double] = [:]
    
    private var previous1: [UUID: [CGFloat]] = [:]
    private var previous2: [UUID: [CGFloat]] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        timeLabel.text = ""
        
        setUpBoundingBoxes()
        setUpCoreImage()
        setUpVision()
        setUpCamera()
        
        frameCapturingStartTime = CACurrentMediaTime()
        
        guard let peripheral = bluetoothParams.peripheral else { print("no peripheral"); return}
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        // Disable idle timer to prevent phone from going to sleep
        UIApplication.shared.isIdleTimerDisabled = true
        
        let value = UIInterfaceOrientation.landscapeLeft.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeLeft
    }

    override var shouldAutorotate: Bool {
        return true
    }
    
    // MARK: - Initialization
    
    func setUpBoundingBoxes() {
        for _ in 0..<YOLO.maxBoundingBoxes {
            boundingBoxes.append(BoundingBox())
        }
        
        // Make colors for the bounding boxes. There is one color for each class,
        // 20 classes in total.
        for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
            for g: CGFloat in [0.3, 0.7] {
                for b: CGFloat in [0.4, 0.8] {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1)
                    colors.append(color)
                }
            }
        }
    }
    
    func setUpCoreImage() {
        // Since we might be running several requests in parallel, we also need
        // to do the resizing in different pixel buffers or we might overwrite a
        // pixel buffer that's already in use.
        for _ in 0..<YOLO.maxBoundingBoxes {
            var resizedPixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(nil, YOLO.inputWidth, YOLO.inputHeight,
                                             kCVPixelFormatType_32BGRA, nil,
                                             &resizedPixelBuffer)
            
            if status != kCVReturnSuccess {
                print("Error: could not create resized pixel buffer", status)
            }
            resizedPixelBuffers.append(resizedPixelBuffer)
        }
    }
    
    func setUpVision() {
        guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
            print("Error: could not create Vision model")
            return
        }
        
        for _ in 0..<YoloView.maxInflightBuffers {
            let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            
            // NOTE: If you choose another crop/scale option, then you must also
            // change how the BoundingBox objects get scaled when they are drawn.
            // Currently they assume the full input image is used.
            request.imageCropAndScaleOption = .scaleFill
            requests.append(request)
        }
    }
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.desiredFrameRate = 240
        videoCapture.setUp(sessionPreset: AVCaptureSession.Preset.hd1280x720) { success in
            if success {
                // Add the video preview into the UI.
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // Add the bounding box layers to the UI, on top of the video preview.
                for box in self.boundingBoxes {
                    box.addToLayer(self.videoPreview.layer)
                }
                
                // Once everything is set up, we can start capturing live video.
                self.videoCapture.start()
            }
        }
    }
    
    // MARK: - Toggle display
    
    @IBAction func tapToggleDisplayButton(_ sender: Any) {
        if displayOn {
            self.videoPreview.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        } else {
            setUpCamera()
        }
        
        displayOn = !displayOn
    }
    
    // MARK: - UI stuff
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        resizePreviewLayer()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Doing inference
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer, inflightIndex: Int) {
        // Measure how long it takes to predict a single video frame. Note that
        // predict() can be called on the next frame while the previous one is
        // still being processed. Hence the need to queue up the start times.
        startTimes.append(CACurrentMediaTime())
        
        // Vision will automatically resize the input image.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        let request = requests[inflightIndex]
        
        // Because perform() will block until after the request completes, we
        // run it on a concurrent background queue, so that the next frame can
        // be scheduled in parallel with this one.
        DispatchQueue.global().async {
            try? handler.perform([request])
        }
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
//            if self.framesDone % 5 == 0 {
                let boundingBoxes = yolo.computeBoundingBoxes(features: features)
                let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
                showOnMainThread(boundingBoxes, elapsed)
//            }
        } else {
            print("BOGUS!")
        }
        
        self.semaphore.signal()
        self.framesDone += 1
    }
    
    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], _ elapsed: CFTimeInterval) {
        DispatchQueue.main.async {
            // For debugging, to make sure the resized CVPixelBuffer is correct.
            //var debugImage: CGImage?
            //VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
            //self.debugImageView.image = UIImage(cgImage: debugImage!)
            self.show(predictions: boundingBoxes)
            
            let fps = self.measureFPS()
            self.timeLabel.text = String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps)
        }
    }
    
    func measureFPS() -> Double {
        // Measure how many frames were actually delivered per second.
//        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
        let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
//        if frameCapturingElapsed > 1 {
//            framesDone = 0
//            frameCapturingStartTime = CACurrentMediaTime()
//        }
        return currentFPSDelivered
    }
    
    func calculateTTC(convertedRect: CGRect, tracked_id: UUID) {
        width2[tracked_id] = convertedRect.size.width
        time2[tracked_id] = CACurrentMediaTime()
        
        guard let t1 = time1[tracked_id] else { return }
        guard let t2 = time2[tracked_id] else { return }
        let delta_t = t2 - t1
        
        if width1[tracked_id] != width2[tracked_id] && width1[tracked_id] != 0 {
            guard let w1 = width1[tracked_id] else { return }
            guard let w2 = width2[tracked_id] else { return }
            let t = momentary_ttc(w1: w1, w2: w2, time: delta_t)
            t_m2[tracked_id] = t
            
            if t_m1[tracked_id] != nil && t_m2[tracked_id] != nil {
                guard let tm1 = t_m1[tracked_id] else { return }
                guard let tm2 = t_m2[tracked_id] else { return }
                let C = ((tm2 - tm1) / delta_t) + 1.0
                if C < 0 {
                    //                    t_a = acceleration_ttc(tm1: tm1, tm2: tm2, time: delta_t, C: C)
                    t_a[tracked_id] = acceleration_ttc(tm1: tm1, tm2: tm2, time: delta_t, C: C)
                    guard let ttc_val = t_a[tracked_id] else { return }
                    // THIS IS THE VALUE TO CHANGE
                    if ttc_val > 0.0  && ttc_val < 3.0 {
                        print(ttc_val)
                        
                        // Send on to bluetooth module (0-255 depending on slider value as a string)
                        writeValue(data: bluetoothParams.strength)
                    }
                }
            }
            
            // Update values
            width1[tracked_id] = width2[tracked_id]
            time1[tracked_id] = time2[tracked_id]
            if t_m2[tracked_id] != nil {
                t_m1[tracked_id] = t_m2[tracked_id]
            }
        }
        
        if t_a[tracked_id] == nil {
            t_a[tracked_id] = 100.0
        }
    }
    
    func writeValue(data: Int){
        let data = String(data)
        print(data)
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        //change the "data" to valueString
        if let blePeripheral = blePeripheral{
            if let txCharacteristic = txCharacteristic {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }

    func show(predictions: [YOLO.Prediction]) {
        for i in 0..<boundingBoxes.count {
            if i < predictions.count {
                let prediction = predictions[i]
                
                // Set by slider (alarm sensitivity)
                if prediction.score < bluetoothParams.sensitivity { return }
                if labels[prediction.classIndex] != "vehicle" { return }
                
//                writeValue(data: bluetoothParams.strength)
                
                // The predicted bounding box is in the coordinate space of the input
                // image, which is a square image of 416x416 pixels. We want to show it
                // on the video preview, which is as wide as the screen and has a 16:9
                // aspect ratio. The video preview also may be letterboxed at the top
                // and bottom.
                let width = view.bounds.width
                let height = width * 16 / 9
                let scaleX = width / CGFloat(YOLO.inputWidth)
                let scaleY = height / CGFloat(YOLO.inputHeight)
                let top = (view.bounds.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                var matchCarID: UUID? = nil
                
                guard let previewLayer = self.videoCapture.previewLayer else { return }
                
                var convertedRect = previewLayer.metadataOutputRectConverted(fromLayerRect: rect)
                convertedRect.origin.y = 1 - convertedRect.origin.y
                
                let delta_x_obj = convertedRect.origin.x + 0.5 * convertedRect.size.width
                let delta_y_obj = convertedRect.origin.y + 0.5 * convertedRect.size.height
                
                // Find matching tracked car
                for (tracked_id, observation) in self.lastObservation {
                    let bb = observation.boundingBox
                    
                    let delta_x_t = bb.origin.x + 0.5 * bb.size.width
                    let delta_y_t = bb.origin.y + 0.5 * bb.size.height
                    
                    if (bb.origin.x <= delta_x_obj &&
                        delta_x_obj <= (bb.origin.x + bb.size.width) &&
                        bb.origin.y <= delta_y_obj &&
                        delta_y_obj <= (bb.origin.y + bb.size.height) &&
                        convertedRect.origin.x <= delta_x_t &&
                        delta_x_t <= (convertedRect.origin.x + convertedRect.size.width) &&
                        convertedRect.origin.y <= delta_y_t &&
                        delta_y_t <= (convertedRect.origin.y + convertedRect.size.height)) {
                        
                        matchCarID = tracked_id
                    }
                }
                
                // TODO: delete objects that leave
                
                // If match does not exist, create new tracking object
                if matchCarID == nil {
                    // Create tracking object
                    let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
                    self.lastObservation[newObservation.uuid] = newObservation
                    
                    // Index widths and times
                    // width1 should be an average of the previous 5-10 frames
                    // Before adding to the dictionary, accumulate average
                    width1[newObservation.uuid] = convertedRect.size.width
                    time1[newObservation.uuid] = CACurrentMediaTime()
                    
                    matchCarID = newObservation.uuid
                }
                
                guard let tracked_id = matchCarID else { return }
                //        previous2[tracked_id].addObject(convertedRect.size.width)
                
                if previous2[tracked_id] == nil {
                    previous2[tracked_id] = [convertedRect.size.width]
                } else {
                    guard let prev2 = previous2[tracked_id] else { return }
                    previous2[tracked_id] = prev2 + [convertedRect.size.width]
                }
                
                if previous2[tracked_id]?.count == 15 {
                    guard let prev2 = previous2[tracked_id] else { return }
                    width2[tracked_id] = average(prev2)
                    
                    // Handle if there is no value for width1
                    if width1[tracked_id] == nil {
                        width1[tracked_id] = width2[tracked_id]
                    }
                    
                    calculateTTC(convertedRect: convertedRect, tracked_id: tracked_id)
                    
                    width1[tracked_id] = width2[tracked_id]
                    // May also want to clear the array (to test)
                    //            previous2[tracked_id]?.removeLast()
                    previous2[tracked_id]? = []
                }
                
                // Show the bounding box.
                //        let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                
                if displayOn {
                    guard let ttc_val = t_a[tracked_id] else { return }
                    let label = String(format: "%@ %.5f", labels[prediction.classIndex], ttc_val)
                    let color = colors[prediction.classIndex]
                    boundingBoxes[i].show(frame: rect, label: label, color: color)
                }
            } else {
                boundingBoxes[i].hide()
            }
        }
    }
    
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

extension YoloView: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        
        //    // make sure the pixel buffer can be converted
        //    guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        if let pixelBuffer = pixelBuffer {
            // The semaphore will block the capture queue and drop frames when
            // Core ML can't keep up with the camera.
            semaphore.wait()
            
            self.trackingRequests = [VNTrackObjectRequest]()
            for (_, observation) in self.lastObservation {
                // create the request
                let request = VNTrackObjectRequest(detectedObjectObservation: observation, completionHandler: self.handleVisionRequestUpdate)
                // set the accuracy to high
                // this is slower, but it works a lot better
                request.trackingLevel = .accurate
                trackingRequests.append(request)
            }
            
            // perform the request
            self.visionSequenceHandler = VNSequenceRequestHandler()
            do {
                try self.visionSequenceHandler.perform(trackingRequests, on: pixelBuffer)
            } catch {
                print("Throws: \(error.localizedDescription)")
            }
            
            // For better throughput, we want to schedule multiple prediction requests
            // in parallel. These need to be separate instances, and inflightBuffer is
            // the index of the current request.
            let inflightIndex = inflightBuffer
            inflightBuffer += 1
            if inflightBuffer >= YoloView.maxInflightBuffers {
                inflightBuffer = 0
            }
            
            // This method should always be called from the same thread!
            // Ain't nobody likes race conditions and crashes.
            self.predictUsingVision(pixelBuffer: pixelBuffer, inflightIndex: inflightIndex)
            
        }
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        // Dispatch to the main queue because we are touching non-atomic, non-thread safe properties of the view controller
        
        DispatchQueue.main.async {
            // make sure we have an actual result
            guard let results = request.results as? [VNObservation] else { return }
            guard let observation = results.first as? VNDetectedObjectObservation else { return }
            
            self.lastObservation[observation.uuid] = observation
            
            // check the confidence level before updating the UI
            guard observation.confidence >= 0.3 else {
                // hide the rectangle when we lose accuracy so the user knows something is wrong
                // FIXME
                //                if let view = self.highlightViews[observation.uuid] {
                //                    view.removeFromSuperview()
                //                    self.highlightViews.removeValue(forKey: observation.uuid)
                //                }
                self.lastObservation.removeValue(forKey: observation.uuid)
                return
            }
            
            // calculate view rect
            var transformedRect = observation.boundingBox
            transformedRect.origin.y = 1 - transformedRect.origin.y
            
            guard let previewLayer = self.videoCapture.previewLayer else { return }
            var convertedRect = previewLayer.metadataOutputRectConverted(fromLayerRect: transformedRect)
            convertedRect.origin.y = 1 - convertedRect.origin.y
            
            //            guard let view = self.highlightViews[observation.uuid] else {
            //                return
            //            }
            
            // move the highlight view
            //            view.frame = convertedRect
        }
    }
    
}


