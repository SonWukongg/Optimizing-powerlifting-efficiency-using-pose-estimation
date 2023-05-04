import Foundation
import UIKit
import AVFoundation
import Vision
import SwiftUI

//Main bulk of code that lets us process frames
final class CameraViewController: UIViewController {
    private var cameraSession: AVCaptureSession?
    var delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    private var cameraView: CameraView { view as! CameraView }
    private let cameraQueue = DispatchQueue(
        label: "CameraOutput",
        qos: .userInteractive
    )
    
    //Load cameraView
    override func loadView() {
        view = CameraView()
    }
    
    //Initialize the AVCaptureSession and se the front camera as input
    //The model works on images so we need to grab sample frames from the feed using SampleBufferDelegate which passes data to swiftUI
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraSession == nil { //If AvCapturesession is null(nil)
                try prepareAVSession() //try prepare AVsession FUNCTION IS BELOW
                cameraView.previewLayer.session = cameraSession //previewlayer is the capture session
                cameraView.previewLayer.videoGravity = .resizeAspectFill //resize the video to fit fill the layers boundaries
            }
            cameraSession?.startRunning() //CameraSession might be nil if nil throws a error
        } catch {
            print(error.localizedDescription) //If camera session doesnt start throw error
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) { //Overide function for when view ends to stop camera session
        cameraSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    
    func prepareAVSession() throws {
        let session = AVCaptureSession()
        session.beginConfiguration() //Marks the beginning of changes to a running capture session
        session.sessionPreset = AVCaptureSession.Preset.high //sets the quality/bit rate of the output in this case its set to high
        
        guard let videoDevice = AVCaptureDevice.default( //setup AV capture device
                .builtInWideAngleCamera, //DEVICE TYPE - wide angle camera
                for: .video, //MEDIA TYPE - used for captureing videos
                position: .front) //POSITION - front camera not back camera
        else { return }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) // try to create device input using Capture device from above
        else { return }
        
        guard session.canAddInput(deviceInput) //Returns true if you can add a media input using the device input created above
        else { return } //If false return
        
        session.addInput(deviceInput) //If above is true then for the camera session assinput from above
        
        let dataOutput = AVCaptureVideoDataOutput() //Capture output that records videos and gives access to video frames for processing
        if session.canAddOutput(dataOutput) { //If true
            session.addOutput(dataOutput) //Session output is data ouput from AVCaptureVideoDataOutput
            dataOutput.setSampleBufferDelegate(delegate, queue: cameraQueue) //
        } else { return }
        
        session.commitConfiguration() //Commit changes to capture session
        cameraSession = session
    }
}



