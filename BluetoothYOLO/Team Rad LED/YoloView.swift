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

class YoloView: UIViewController {
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var debugImageView: UIImageView!
    
    // Disable this to see the energy impact of just running the neural net,
    // otherwise it also counts the GPU activity of drawing the bounding boxes.
    let drawBoundingBoxes = true
    
    // How many predictions we can do concurrently.
    static let maxInflightBuffers = 3
    
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
    //   private var t_a = [UUID: Double] = [:]
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
    }
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self as? VideoCaptureDelegate
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

    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
            
            let boundingBoxes = yolo.computeBoundingBoxes(features: features)
            let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
//            showOnMainThread(boundingBoxes, elapsed)
        } else {
            print("BOGUS!")
        }
        
        self.semaphore.signal()
    }

}
