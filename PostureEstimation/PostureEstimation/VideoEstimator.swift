import UIKit
import AVFoundation
import Vision
import Combine

//Pose estimator class inherits from AVCaptureVideoDataOutputSampleBufferDelegate and ObservableObject
class VideoEstimator: NSObject, ObservableObject {
    // Process
    let sequenceHandler = VNSequenceRequestHandler()

    //Using published var Body parts means that when bodyParts is updated all views will reflect this change
    // bodyParts is a dictionary with 19 points on the body and normalized point with a confidence value
    @Published var frames = [CGImage]()
    @Published var bodyPartsArray = [[VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]]()

    var subscriptions = Set<AnyCancellable>()
    
    func processedFrames() -> [CGImage] {
        return frames
    }
    

    func processVideoFile(url: URL) {
        let asset = AVAsset(url: url)
        let reader = try! AVAssetReader(asset: asset)
        let videoTrack = asset.tracks(withMediaType: .video).first!
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings:
                                                [kCVPixelBufferPixelFormatTypeKey as
                                                  String: Int(kCVPixelFormatType_32BGRA)])

        reader.add(output)
        reader.startReading()

        while true {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            autoreleasepool {
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!

                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .right, options: [:])

                let humanBodyRequest = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)

                do {
                    try imageRequestHandler.perform([humanBodyRequest])
                } catch {
                    print(error.localizedDescription)
                }

                let image = CIImage(cvPixelBuffer: imageBuffer)
                let context = CIContext(options: nil)
                let cgImage = context.createCGImage(image, from: image.extent)!

               frames.append(cgImage)
            }
        }
    }
    
    
    

    
    func bodyPoseHandler(request: VNRequest, error: Error?){
        guard let observations =
                request.results as? [VNHumanBodyPoseObservation],
              let observation = observations.first else {
            return
        }

        guard let recognizedPoints =
                try? observation.recognizedPoints(.all) else {
            return
        }

        var jointPoints = [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]()
        
        let bodyJointNames: [VNHumanBodyPoseObservation.JointName] = [
            .root,
            .neck,
            .rightShoulder,
            .rightElbow,
            .rightWrist,
            .leftShoulder,
            .leftElbow,
            .leftWrist,
            .rightHip,
            .rightKnee,
            .rightAnkle,
            .leftHip,
            .leftKnee,
            .leftAnkle
        ]

        for jointName in bodyJointNames {
            guard let point = recognizedPoints[jointName], point.confidence > 0 else { continue }
            jointPoints[jointName] = point
        }
        
        bodyPartsArray.append(jointPoints)

    }

    
    func createVideo(from frames: [CGImage], outputURL: URL, fps: Int32 = 30) -> AVPlayerItem {
        let avWriter = try! AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4)

        let width = frames.first!.width
        let height = frames.first!.height

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]

        let avWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: avWriterInput,
                                                                      sourcePixelBufferAttributes: nil)
        avWriter.add(avWriterInput)
        avWriter.startWriting()
        avWriter.startSession(atSourceTime: CMTime.zero)

        let frameDuration = CMTimeMake(value: 1, timescale: fps)
        var frameCount = 0

        for cgImage in frames {
            autoreleasepool {
                let presentationTime = CMTimeMake(value: Int64(frameCount), timescale: fps)
                guard let pixelBuffer = pixelBuffer(from: cgImage, width: width, height: height) else { return }
                if avWriterInput.isReadyForMoreMediaData {
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                } else {
                    print("Pixel buffer queue is full. Waiting...")
                }
                frameCount += 1
            }
        }

        avWriterInput.markAsFinished()
        avWriter.finishWriting {
            print("Finished writing video.")
        }

        let asset = AVURLAsset(url: outputURL)
        let video = AVPlayerItem(asset: asset)
        return video
    }


    private func pixelBuffer(from cgImage: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        let options = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                       kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options, &pixelBuffer)
        guard let targetPixelBuffer = pixelBuffer, status == kCVReturnSuccess else { return nil }
        CVPixelBufferLockBaseAddress(targetPixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(targetPixelBuffer),
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(targetPixelBuffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(targetPixelBuffer, [])
        return targetPixelBuffer
    }

}
