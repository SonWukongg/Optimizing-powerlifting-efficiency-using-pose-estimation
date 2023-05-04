import UIKit
import AVFoundation
import AVKit
import Vision
import CoreMedia
import SwiftUI


class benchViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var imageView = UIImageView()
    var imageIndex = 0
    var imageCount = 0
    let videoEstimator = VideoEstimator()
    var createVideoButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemPink
        
        let button = UIButton(type: .system)
        button.setTitle("Select Video", for: .normal)
        button.addTarget(self, action: #selector(selectVideo), for: .touchUpInside)
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        
        // Create the button and set it to be hidden
        createVideoButton = UIButton(type: .system)
        createVideoButton.setTitle("Create Video", for: .normal)
        createVideoButton.addTarget(self, action: #selector(createVideoBut), for: .touchUpInside)
        createVideoButton.translatesAutoresizingMaskIntoConstraints = false
        createVideoButton.isHidden = true
        view.addSubview(createVideoButton)
        createVideoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        createVideoButton.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 20).isActive = true
    }
    
    func createVideo(from images: AnyIterator<CGImage>, outputURL: URL, fps: Int32 = 30) -> Bool {
        let avWriter = try! AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mp4)

        let firstImage = images.next()
        guard let width = firstImage?.width, let height = firstImage?.height else {
            return false
        }

        let smallerWidth = Int(width / 2)
        let smallerHeight = Int(height / 2)

        let videoSettings: [String: Any] = [        AVVideoCodecKey: AVVideoCodecType.h264,        AVVideoWidthKey: smallerWidth,        AVVideoHeightKey: smallerHeight    ]

        let avWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: avWriterInput,
                                                                          sourcePixelBufferAttributes: nil)
        avWriter.add(avWriterInput)
        avWriter.startWriting()
        avWriter.startSession(atSourceTime: CMTime.zero)

        var frameCount = 0

        while avWriterInput.isReadyForMoreMediaData, let image = images.next() {
            autoreleasepool {
                let ciImage = CIImage(cgImage: image)
                let presentationTime = CMTimeMake(value: Int64(frameCount), timescale: fps)
                let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))

                while !pixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.1)
                }

                guard let pixelBuffer = pixelBuffer(from: scaledImage, width: smallerWidth, height: smallerHeight) else {
                    return
                }

                CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                            width: smallerWidth,
                                            height: smallerHeight,
                                            bitsPerComponent: 8,
                                            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!

                let rect = CGRect(x: 0, y: 0, width: CGFloat(smallerWidth), height: CGFloat(smallerHeight))
                
                
                if videoEstimator.bodyPartsArray.count > frameCount {
                    drawBodyParts(on: context, with: rect, bodyParts: videoEstimator.bodyPartsArray[frameCount])
                }


                pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

                frameCount += 1
            }
        }

        avWriterInput.markAsFinished()
        avWriter.finishWriting {
            print("Finished writing video.")
        }

        let asset = AVURLAsset(url: outputURL)
        let video = AVPlayerItem(asset: asset)

        // Apply transform to rotate video 90 degrees clockwise
        let videoComposition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
            let output = source.transformed(by: transform)
            request.finish(with: output, context: nil)
        }

        videoComposition.renderSize = CGSize(width: height, height: width)

        video.videoComposition = videoComposition

        return true

    }
    func pixelBuffer(from image: CIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let options: NSDictionary = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32ARGB
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32ARGB,
                                         options,
                                         &pixelBuffer)
        guard let targetPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(targetPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(targetPixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(targetPixelBuffer),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1.0, y: -1.0)

        let ciContext = CIContext(cgContext: context!, options: nil)
        ciContext.render(image, to: targetPixelBuffer)

        CVPixelBufferUnlockBaseAddress(targetPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return targetPixelBuffer
    }

    private let bodyJointNames: [VNHumanBodyPoseObservation.JointName] = [
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
    
    func drawBodyParts(on context: CGContext, with rect: CGRect, bodyParts: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) -> Void {
            
        for jointName in bodyJointNames {
            autoreleasepool {
                if let x = bodyParts[jointName]?.location.x, let y = bodyParts[jointName]?.location.y {
                    let scaledX = (1 - y) * rect.width
                    let scaledY = x * rect.height
                    
                    let circleRect = CGRect(x: scaledX - 2, y: scaledY - 2, width: 5, height: 5)
                    context.setFillColor(UIColor.green.cgColor)
                    context.fillEllipse(in: circleRect)
                }
            }
        }
    }

    
    var initialPositionIndex : Int?
    var lowestPointIndex: Int?
    
    func analayseLift3() -> Void {
        let bodyParts = videoEstimator.bodyPartsArray
        var initialLeftWrist: VNRecognizedPoint?
        var currRightWrist: VNRecognizedPoint?
        var barMoving = false
        
        
        var lowestElbow: VNRecognizedPoint?
        
        
        for (index, bodyPart) in bodyParts.enumerated() {
            for jointName in bodyJointNames {
                if let joint = bodyPart[jointName] {
                    switch jointName {
                    case .leftWrist:
                        if initialLeftWrist == nil {
                            initialLeftWrist = joint
                        }
                        currRightWrist = joint
                        if barMoving == false {
                            if let currentJoint = currRightWrist, let initialJoint = initialLeftWrist {
                                let difference = currentJoint.location.y - initialJoint.location.y
                                if difference > 0.001 {
                                    barMoving = true
                                    
                                    print("Bar moving for bodyPart at index \(index)")
                                    initialPositionIndex = index
                                }
                            }
                        }
                    default:
                        break
                    }
                }
                
                if barMoving {
                    if let elbow = bodyPart[.leftElbow]{
                        if lowestElbow == nil{
                            lowestElbow = elbow
                        }
                        
                        if let lowest = lowestElbow {
                            if elbow.y < lowest.y {
                                lowestPointIndex = index
                                lowestElbow = elbow
                            }
                        }
                    }
                }
                
            }
        }
    }


    @objc func selectVideo() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
        imagePickerController.videoQuality = .typeHigh// Add this line
        present(imagePickerController, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            videoEstimator.processVideoFile(url: url)
            self.createVideoButton.isHidden = false
            
            picker.dismiss(animated: true, completion: nil)
        }
    }

    @objc func createVideoBut() {
        print("Create Video tapped!")
        let uuid = UUID().uuidString
        autoreleasepool {
            let fps = 30
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let outputDirectory = documentsDirectory.appendingPathComponent("MyVideoDirectory")

            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // Handle the error here.
            }

            let outputURL = outputDirectory.appendingPathComponent("outputTest_\(uuid).mp4")

            let framesIterator = AnyIterator(videoEstimator.frames.makeIterator())
            let _ = createVideo(from: framesIterator, outputURL: outputURL, fps: Int32(fps))

            
        }
        let _ = analayseLift3()

        let benchFeedBack = benchFeedBackView(videoEstimator: videoEstimator, filePath: "outputTest_\(uuid).mp4",startingPositions: videoEstimator.bodyPartsArray[initialPositionIndex!], startingIndex: initialPositionIndex!, lowestPoint: lowestPointIndex!)
        let hostingController = UIHostingController(rootView: benchFeedBack)
        present(hostingController, animated: true, completion: nil)
    }
}


struct benchFeedBackView: View {
    let player: AVPlayer
    let videoEstimator : VideoEstimator
    let startingPositions: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    let startingIndex: Int
    let lowestPoint: Int
    
    init(videoEstimator: VideoEstimator, filePath: String, startingPositions: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint], startingIndex: Int, lowestPoint: Int) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputDirectory = documentsDirectory.appendingPathComponent("MyVideoDirectory")
        player = AVPlayer(url: outputDirectory.appendingPathComponent(filePath))
        self.videoEstimator = videoEstimator
        self.startingPositions = startingPositions
        self.startingIndex = startingIndex
        self.lowestPoint = lowestPoint
    }
    
    var body: some View {
        VStack {
            VideoPlayerView(player: player)
                .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.5)
            
            ScrollView{
                VStack {
                    Text("Starting Position:")
                        .padding(.bottom, 70)
                    Spacer()
                    
                    ZStack {
                        if let uiImage = UIImage(cgImage: videoEstimator.frames[startingIndex]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: CGFloat(videoEstimator.frames[0].width / 4), height: CGFloat(videoEstimator.frames[0].height / 4))
                                .background(Color.gray)
                                .rotationEffect(.degrees(90))
                        } else {
                            Text("Failed to load image")
                        }
                        
                        DrawingView(joints: startingPositions)
                            .frame(width: CGFloat(videoEstimator.frames[0].width / 4), height: CGFloat(videoEstimator.frames[0].height / 4))
                            .background(Color.clear)
                            .rotationEffect(.degrees(90))
                            .scaleEffect(x: -1, y: 1, anchor: .center)
                    
                    }
                    .padding(.bottom,70)
                    
                    Text("Bottom Position:")
                    Text(armAngleBottom(position: videoEstimator.bodyPartsArray[lowestPoint]))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 70)
                    ZStack {
                        if let uiImage = UIImage(cgImage: videoEstimator.frames[lowestPoint]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: CGFloat(videoEstimator.frames[0].width / 4), height: CGFloat(videoEstimator.frames[0].height / 4))
                                .background(Color.gray)
                                .rotationEffect(.degrees(90))
                        } else {
                            Text("Failed to load image")
                        }
                        DrawingView(joints: videoEstimator.bodyPartsArray[lowestPoint])
                            .frame(width: CGFloat(videoEstimator.frames[0].width / 4), height: CGFloat(videoEstimator.frames[0].height / 4))
                            .background(Color.clear)
                            .rotationEffect(.degrees(90))
                            .scaleEffect(x: -1, y: 1, anchor: .center)
                        benchCorrectedView(joints: videoEstimator.bodyPartsArray[lowestPoint])
                            .rotationEffect(.degrees(90))
                            .scaleEffect(x: -1, y: 1, anchor: .center)
                            .frame(width: CGFloat(videoEstimator.frames[0].width / 4), height: CGFloat(videoEstimator.frames[0].height / 4))
                    
                    }
                    .padding(.bottom,70)
                    Text("The pink points are the optimal starting positions")
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("During Lift: Your arms are moving together. This is Good!")
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
        }
        .onAppear {
            let asset = player.currentItem?.asset
            guard let videoTrack = asset?.tracks(withMediaType:  .video).first else {
                return
            }
            
            let composition = AVMutableComposition()
            let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try? videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset!.duration), of: videoTrack, at: .zero)
            
            let videoComposition = AVMutableVideoComposition(propertiesOf: player.currentItem!.asset)
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)
            
            let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let t1 = CGAffineTransform(translationX: videoTrack.naturalSize.height, y: 0.0)
            let t2 = t1.rotated(by: .pi / 2)
            let finalTransform = t2
            transformer.setTransform(finalTransform, at: .zero)
            
            instruction.layerInstructions = [transformer]
            videoComposition.instructions = [instruction]
            
            let playerItem = AVPlayerItem(asset: composition)
            playerItem.videoComposition = videoComposition
            player.replaceCurrentItem(with: playerItem)
        }
        
    }
        
    func armAngleBottom(position: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint])-> String{
        
        let angle = angleBetweenThreePoints(pointA: (x: position[.leftWrist]!.x, y: position[.leftWrist]!.y), pointB: (x: position[.leftElbow]!.x, y: position[.leftElbow]!.y), pointC: (x: position[.leftShoulder]!.x, y: position[.leftShoulder]!.y))
        
        if angle > 90 || angle < 90 {
            return "The angle of your arm is \(Int(angle))\u{00B0}. For most people the strongest position would be when your arm is around 90\u{00B0}"
        }
        else{
            return "The angle of your arm is \(Int(angle))\u{00B0}. This is an optimal position"
        }
    }
    
    
    func armPositioning (position: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint])-> String{
        let upplim = lowestPoint + 20
        
        var prevLeftArm: VNRecognizedPoint?
        var prevRightArm: VNRecognizedPoint?
        
        for bodyPart in videoEstimator.bodyPartsArray[lowestPoint...upplim] {
            if prevLeftArm == nil {
                prevLeftArm = bodyPart[.leftWrist]
            }
            if  prevRightArm == nil {
                prevRightArm = bodyPart[.rightWrist]
            }
            
            if let right = prevRightArm, let left = prevLeftArm {
                    let rightDiff = abs(bodyPart[.rightWrist]!.y - right.y)
                    let leftDiff = abs(bodyPart[.leftWrist]!.y - left.y)
                
                if (abs(rightDiff - leftDiff) > 0.1){
                    return "Arms are not coming up together"
                }
            }
        }
        
        return " Your arms are moving together. This is Good!"
    }
    
    
    
    
    func legPosition(position: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint])-> String{
        let angle = angleBetweenThreePoints(pointA: (x: position[.leftAnkle]!.x, y: position[.leftAnkle]!.y), pointB: (x: position[.leftKnee]!.x, y: position[.leftKnee]!.y), pointC: (x: position[.leftHip]!.x, y: position[.leftHip]!.y))
        
        if angle < 90 {
            return "The angle of your arm is \(Int(angle))\u{00B0}. For most people the strongest position would be when your arm is around 90\u{00B0}"
        }
        else{
            return "The angle of your arm is \(Int(angle))\u{00B0}. This is an optimal position"
        }
        
        return ""
    }
    
    func angleBetweenThreePoints(pointA: (x: Double, y: Double), pointB: (x: Double, y: Double), pointC: (x: Double, y: Double)) -> Double {
        
        let AB = sqrt(pow(pointB.x - pointA.x, 2) + pow(pointB.y - pointA.y, 2))
        let BC = sqrt(pow(pointB.x - pointC.x, 2) + pow(pointB.y - pointC.y, 2))
        let AC = sqrt(pow(pointC.x - pointA.x, 2) + pow(pointC.y - pointA.y, 2))
        
        let angleRad = acos((pow(AB, 2) + pow(BC, 2) - pow(AC, 2)) / (2 * AB * BC))
        let angleDeg = angleRad * (180.0 / Double.pi)

        return angleDeg
    }
    
    
}





struct benchCorrectedView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
        
    var body: some View {
        GeometryReader { geometry in
            if let root = joints[.root]?.location,
               let neck = joints[.neck]?.location,
               let rightShoulder = joints[.rightShoulder]?.location,
               let rightElbow = joints[.rightElbow]?.location,
               let rightWrist = joints[.rightWrist]?.location,
               let leftShoulder = joints[.leftShoulder]?.location,
               let leftElbow = joints[.leftElbow]?.location,
               let leftWrist = joints[.leftWrist]?.location,
               let rightHip = joints[.rightHip]?.location,
               let rightKnee = joints[.rightKnee]?.location,
               let rightAnkle = joints[.rightAnkle]?.location,
               let leftHip = joints[.leftHip]?.location,
               let leftKnee = joints[.leftKnee]?.location,
               let leftAnkle = joints[.leftAnkle]?.location {
                
                //Right Arm
                Circle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 4)
                    .position(CGPoint(x: (1 - rightShoulder.y) * geometry.size.width, y: rightShoulder.x * geometry.size.height))
                
                Circle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 4)
                    .position(CGPoint(x: (1 - rightElbow.y) * geometry.size.width, y: rightElbow.x * geometry.size.height))
                
                Circle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 4)
                    .position(CGPoint(x: (1 - rightWrist.y) * geometry.size.width, y: rightElbow.x * geometry.size.height))
                
                //Left Arm
                
                Circle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 4)
                    .position(CGPoint(x: (1 - leftShoulder.y) * geometry.size.width, y: leftShoulder.x * geometry.size.height))
                
                Circle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 4)
                    .position(CGPoint(x: (1 - leftElbow.y) * geometry.size.width, y: leftElbow.x * geometry.size.height))
                
                Circle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 4)
                    .position(CGPoint(x: (1 - leftWrist.y) * geometry.size.width, y: leftElbow.x * geometry.size.height))
                
            }
            
        }
    }
    
}
