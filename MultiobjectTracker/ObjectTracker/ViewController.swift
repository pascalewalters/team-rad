//
//  ViewController.swift
//  ObjectTracker
//
//  Created by Jeffrey Bergier on 6/8/17.
//  Copyright © 2017 Saturday Apps. All rights reserved.
//  Modified by Pascale Walters on 21/1/19
//

import AVFoundation
import Vision
import UIKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet private weak var cameraView: UIView?
    
    private var visionSequenceHandler = VNSequenceRequestHandler()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
        else { return session }
        session.addInput(input)
        return session
    }()
    
    // New stuff
    private var highlightViews: [UUID: UIView] = [:]
    private var lastObservation: [UUID: VNDetectedObjectObservation] = [:]
    private var trackingRequests: [VNTrackObjectRequest] = []
    
    private var width1: [UUID: CGFloat] = [:]
    private var time1: [UUID: CFTimeInterval] = [:]
    private var width2: [UUID: CGFloat] = [:]
    private var time2: [UUID: CFTimeInterval] = [:]
    private var t_m1: [UUID: Double] = [:]
    private var t_m2: [UUID: Double] = [:]
    
    let yolo = YOLO()
    
    // How many predictions we can do concurrently.
    static let maxInflightBuffers = 3
    
    let semaphore = DispatchSemaphore(value: ViewController.maxInflightBuffers)

    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []
    var resizedPixelBuffers: [CVPixelBuffer?] = []
    var requests = [VNCoreMLRequest]()
    var startTimes: [CFTimeInterval] = []
    var framesDone = 0
    var frameCapturingStartTime = CACurrentMediaTime()
    var inflightBuffer = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set up bounding boxes
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
        
        // set up core image
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
        
        // set up vision
        guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
            print("Error: could not create Vision model")
            return
        }
        
        for _ in 0..<ViewController.maxInflightBuffers {
            let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            
            // NOTE: If you choose another crop/scale option, then you must also
            // change how the BoundingBox objects get scaled when they are drawn.
            // Currently they assume the full input image is used.
            request.imageCropAndScaleOption = .scaleFill
            requests.append(request)
        }
        
        // make the camera appear on the screen
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        
        // Add the bounding box layers to the UI, on top of the video preview.
        for box in self.boundingBoxes {
            box.addToLayer(self.cameraLayer)
        }
        
        // register to receive buffers from the camera
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        
        // begin the session
        self.captureSession.startRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print(#function)
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
            
            let boundingBoxes = yolo.computeBoundingBoxes(features: features)
            let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
            // TODO: For each bounding box, create a new observation
            // boundingBoxes are in YOLO coordinates
            showOnMainThread(boundingBoxes, elapsed)
        } else {
            print("BOGUS!")
        }
        
        self.semaphore.signal()
    }
    
    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], _ elapsed: CFTimeInterval) {
        DispatchQueue.main.async {
            // For debugging, to make sure the resized CVPixelBuffer is correct.
            //var debugImage: CGImage?
            //VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
            //self.debugImageView.image = UIImage(cgImage: debugImage!)
            //        if boundingBoxes.count < 1 { return }
            self.show(predictions: boundingBoxes)
            
//            print(self.measureFPS())
            // Don't have this IBOutlet
//            self.timeLabel.text = String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps)
        }
    }
    
    func measureFPS() -> Double {
        // Measure how many frames were actually delivered per second.
        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
        let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
        if frameCapturingElapsed > 1 {
            framesDone = 0
            frameCapturingStartTime = CACurrentMediaTime()
        }
        return currentFPSDelivered
    }
    
    func show(predictions: [YOLO.Prediction]) {
        for i in 0..<boundingBoxes.count {
            if i < predictions.count {
                let prediction = predictions[i]
                print(labels[prediction.classIndex])
//                if labels[prediction.classIndex] != "bicycle" && labels[prediction.classIndex] != "bus" && labels[prediction.classIndex] != "car" && labels[prediction.classIndex] != "motorbike" { continue }
                
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
                
                var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: rect)
                convertedRect.origin.y = 1 - convertedRect.origin.y
                
                let delta_x_obj = convertedRect.origin.x + 0.5 * convertedRect.size.width
                let delta_y_obj = convertedRect.origin.y + 0.5 * convertedRect.size.height
                
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
                        // Matching object already exists
                        matchCarID = tracked_id
                    }
                }
                
                // TODO: delete objects that leave
                // TODO: handle for too many tracking objects
                
                if matchCarID == nil {
                    // TODO: implement desired width and height?
//                    if (rect.origin.x + rect.size.width < desired_w / 2) &&
//                        (rect.origin.y < (desired_h / 4)) {
                    
                    // Create tracking object
                    let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
                    self.lastObservation[newObservation.uuid] = newObservation
                    
                    // Index widths and times
                    width1[newObservation.uuid] = convertedRect.size.width
                    time1[newObservation.uuid] = CACurrentMediaTime()
//                    }
                }
                
                for (tracked_id, observation) in self.lastObservation {
                    let bb = observation.boundingBox

                    width2[tracked_id] = bb.size.width
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
//
                            if C < 0 {
                                let t_a = acceleration_ttc(tm1: tm1, tm2: tm2, time: delta_t, C: C)
                                if t_a > 0 {
////                                    print("Car ID is: {track}, the following is t_m, t_a and current frame".format(track=tracked_id))
//                                    print(t_m2[tracked_id])
                                    print(t_a)
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
                }
                
                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
                
                
            } else {
                boundingBoxes[i].hide()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // make sure the layer is the correct size
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            // make sure the pixel buffer can be converted
            let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        
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
        
        // Attempt to handle the error (doesn't work)
//        do {
//            try self.visionSequenceHandler.perform(trackingRequests, on: pixelBuffer)
//        } catch {
//            do {
//                self.visionSequenceHandler = VNSequenceRequestHandler()
//                try self.visionSequenceHandler.perform(trackingRequests, on: pixelBuffer)
//            } catch {
//                print("Throws: \(error.localizedDescription)")
//            }
//        }
        
        // The semaphore will block the capture queue and drop frames when
        // Core ML can't keep up with the camera.
        semaphore.wait()
        
        // For better throughput, we want to schedule multiple prediction requests
        // in parallel. These need to be separate instances, and inflightBuffer is
        // the index of the current request.
        let inflightIndex = inflightBuffer
        inflightBuffer += 1
        if inflightBuffer >= ViewController.maxInflightBuffers {
            inflightBuffer = 0
        }
        
        self.predictUsingVision(pixelBuffer: pixelBuffer, inflightIndex: inflightIndex)
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
                if let view = self.highlightViews[observation.uuid] {
                    view.removeFromSuperview()
                    self.highlightViews.removeValue(forKey: observation.uuid)
                }
                return
            }
            
            // calculate view rect
            var transformedRect = observation.boundingBox
            transformedRect.origin.y = 1 - transformedRect.origin.y
            let convertedRect = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
            
            guard let view = self.highlightViews[observation.uuid] else {
                return
            }
            
            // move the highlight view
            view.frame = convertedRect
        }
    }
    
//    @IBAction private func userTapped(_ sender: UITapGestureRecognizer) {
//        // get the center of the tap
//        let highlightView = createHighlightSquare()
//        highlightView.center = sender.location(in: self.view)
//
//        // convert the rect for the initial observation
//        let originalRect = highlightView.frame
//        print(originalRect.origin)
//        print(originalRect)
//        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
//        convertedRect.origin.y = 1 - convertedRect.origin.y
//        print(convertedRect)
//
//        // set the observation
//        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
//        self.lastObservation[newObservation.uuid] = newObservation
//        self.highlightViews[newObservation.uuid] = highlightView
//        self.view.addSubview(highlightView)
//    }
    
    @IBAction private func resetTapped(_ sender: UIBarButtonItem) {
        self.lastObservation = [:]
//        highlightViews.forEach({ $0.value.removeFromSuperview() })
        print("reset")
    }
    
    private func createHighlightSquare() -> UIView {
        // get the center of the tap
        let highlightView = UIView()
        highlightView.frame.size = CGSize(width: 120, height: 120)
        highlightView.layer.borderColor = UIColor.red.cgColor
        highlightView.layer.borderWidth = 4
        highlightView.backgroundColor = .clear
        return highlightView
    }
}

