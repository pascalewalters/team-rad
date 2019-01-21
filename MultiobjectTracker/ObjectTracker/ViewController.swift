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
    
    private let visionSequenceHandler = VNSequenceRequestHandler()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make the camera appear on the screen
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        
        // register to receive buffers from the camera
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        
        // begin the session
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // make sure the layer is the correct size
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            // make sure the pixel buffer can be converted
            let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        
        self.trackingRequests = [VNTrackObjectRequest]()
        for (_, observation) in lastObservation {
            // create the request
            let request = VNTrackObjectRequest(detectedObjectObservation: observation, completionHandler: self.handleVisionRequestUpdate)
            // set the accuracy to high
            // this is slower, but it works a lot better
            request.trackingLevel = .accurate
            trackingRequests.append(request)
        }
        
        // perform the request
        do {
            try self.visionSequenceHandler.perform(trackingRequests, on: pixelBuffer)
        } catch {
            print("Throws: \(error)")
        }
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        // Dispatch to the main queue because we are touching non-atomic, non-thread safe properties of the view controller

        DispatchQueue.main.async {
            // make sure we have an actual result
            guard let results = request.results as? [VNObservation] else { return }
            guard let observation = results.first as? VNDetectedObjectObservation else { return }
            
            // From https://developer.apple.com/documentation/vision/tracking_multiple_objects_or_rectangles_in_video
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
    
    @IBAction private func userTapped(_ sender: UITapGestureRecognizer) {
        // get the center of the tap
        let highlightView = createHighlightSquare()
        highlightView.center = sender.location(in: self.view)
        
        // convert the rect for the initial observation
        let originalRect = highlightView.frame
        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        
        // set the observation
        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.lastObservation[newObservation.uuid] = newObservation
        self.highlightViews[newObservation.uuid] = highlightView
        self.view.addSubview(highlightView)
    }
    
    @IBAction private func resetTapped(_ sender: UIBarButtonItem) {
        self.lastObservation = [:]
        highlightViews.forEach({ $0.value.removeFromSuperview() })
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

