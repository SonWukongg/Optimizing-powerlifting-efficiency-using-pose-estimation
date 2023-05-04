import UIKit
import AVFoundation
import AVKit
import Vision
import CoreMedia
import SwiftUI


class squatViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
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
    
    func angleBetweenThreePoints(pointA: (x: Double, y: Double), pointB: (x: Double, y: Double), pointC: (x: Double, y: Double)) -> Double {
        
        let AB = sqrt(pow(pointB.x - pointA.x, 2) + pow(pointB.y - pointA.y, 2))
        let BC = sqrt(pow(pointB.x - pointC.x, 2) + pow(pointB.y - pointC.y, 2))
        let AC = sqrt(pow(pointC.x - pointA.x, 2) + pow(pointC.y - pointA.y, 2))
        
        let angleRad = acos((pow(AB, 2) + pow(BC, 2) - pow(AC, 2)) / (2 * AB * BC))
        let angleDeg = angleRad * (180.0 / Double.pi)

//        print(angleRad)
        return angleDeg
    }
    
    var initialPositionIndex : Int?
    var lowestPointIndex: Int?
    
    func analayseLift3() -> Void {
        let bodyParts = videoEstimator.bodyPartsArray
        var initialLeftWrist: VNRecognizedPoint?
        var currLeftWrist: VNRecognizedPoint?
        
        var initialRightWrist: VNRecognizedPoint?
        var currRightWrist: VNRecognizedPoint?
        
        var lowestHip: VNRecognizedPoint?
        var barMoving = false
        
        
        let torsoGradient = calculateGradient(from: CGPoint(x: bodyParts[0][.neck]!.x, y: bodyParts[0][.neck]!.y), to: CGPoint(x: bodyParts[0][.root]!.x, y: bodyParts[0][.root]!.y))

        if (torsoGradient > 0){
            print("facing right")
            
            for (index, bodyPart) in bodyParts.enumerated() {
                for jointName in bodyJointNames {
                    if let joint = bodyPart[jointName] {
                        switch jointName {
                        case .rightWrist:
                            if initialRightWrist == nil {
                                initialRightWrist = joint
                            }
                            currRightWrist = joint
                            if barMoving == false {
                                if let currentJoint = currRightWrist, let initialJoint = initialRightWrist {
                                    
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
                    
                    if(barMoving){
                        if let hip = bodyPart[.rightHip]{
                            if lowestHip == nil {
                                lowestHip = hip
                            }
//                            print(hip)
                            if let lowest = lowestHip {
                                if  hip.y < lowest.y {
                                    lowestPointIndex = index
                                    lowestHip = hip
                                }
                            }
                        }
                    }

                }
                
            }
            
            let upplim = lowestPointIndex! + 20
            
            var prevHip: VNRecognizedPoint?
            var prevShoulder: VNRecognizedPoint?
            
//            for bodyPart in bodyParts[lowestPointIndex!...upplim] {
//                if prevHip == nil {
//                    prevHip = bodyPart[.rightHip]
//                }
//                if prevShoulder == nil {
//                    prevShoulder = bodyPart[.rightShoulder]
//                }
//                
//                if let hip = prevHip, let shoulder = prevShoulder {
//                    let hipDiff = abs(hip.y - bodyPart[.rightHip]!.y)
//                    let shoulderDiff = abs (shoulder.y - bodyPart[.rightShoulder]!.y)
//
//                    print("hip diff \(hipDiff)")
//                    print("shoulder diff \(shoulderDiff)")
//
//                }
//            }
            
            //END OF LOOP
            
        }else{
            print("facing left")
            for (index, bodyPart) in bodyParts.enumerated() {
                for jointName in bodyJointNames {
                    if let joint = bodyPart[jointName] {
                        switch jointName {
                        case .leftWrist:
    //                        print(joint)
                            if initialLeftWrist == nil {
                                initialLeftWrist = joint
                            }
                            currLeftWrist = joint
                            if barMoving == false {
                                if let currentJoint = currLeftWrist, let initialJoint = initialLeftWrist {
                                    
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
                    
                    if(barMoving){
                        if let hip = bodyPart[.leftHip]{
                            if lowestHip == nil {
                                lowestHip = hip
                            }
//                            print(hip)
                            if let lowest = lowestHip {
                                if  hip.y < lowest.y {
                                    lowestPointIndex = index
                                    lowestHip = hip
                                }
                            }
                        }
                    }

                }
                
            }
            //END LOOPP
            
            let upplim = lowestPointIndex! + 20
            
            var prevHip: VNRecognizedPoint?
            var prevShoulder: VNRecognizedPoint?
            
            var shoulderCount = 0
            var hipCount = 0
            
            for bodyPart in bodyParts[lowestPointIndex!...upplim] {
                if prevHip == nil {
                    prevHip = bodyPart[.leftHip]
                }
                if prevShoulder == nil {
                    prevShoulder = bodyPart[.leftShoulder]
                }
                
                if let hip = prevHip, let shoulder = prevShoulder {
                    let hipDiff = abs(hip.y - bodyPart[.leftHip]!.y)
                    let shoulderDiff = abs (shoulder.y - bodyPart[.leftShoulder]!.y)
                    
                    if hipDiff > shoulderDiff{
                        hipCount+=1
                    }
                    else{
                        shoulderCount+=1
                    }
                    print("hip diff \(hipDiff)")
                    print("shoulder diff \(shoulderDiff)")
                    
                }
            }
            
            print("shoulder count \(shoulderCount)")
            print("hip count \(hipCount)")
            
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
    
    func calculateGradient(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        return dy / dx
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

//            let _ = createVideo(from: videoEstimator.frames, outputURL: outputURL, fps: Int32(fps))
            let framesIterator = AnyIterator(videoEstimator.frames.makeIterator())
            let _ = createVideo(from: framesIterator, outputURL: outputURL, fps: Int32(fps))

        }
        let _ = analayseLift3()

        
        let squatFeedback = SquatFeedBackView(videoEstimator: videoEstimator, filePath: "outputTest_\(uuid).mp4",startingPositions: videoEstimator.bodyPartsArray[initialPositionIndex!], startingIndex: initialPositionIndex!, lowestPoint: lowestPointIndex!)
//        let squatFeedback = tempView(videoEstimator: videoEstimator, filePath: "outputTest_\(uuid).mp4",startingPositions: videoEstimator.bodyPartsArray[initialPositionIndex!], startingIndex: initialPositionIndex!, lowestPoint: lowestPointIndex!)
        let hostingController = UIHostingController(rootView: squatFeedback)
        present(hostingController, animated: true, completion: nil)
    }
}



struct tempView: View {
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
        ZStack {
            if let uiImage = UIImage(cgImage: videoEstimator.frames[startingIndex]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(videoEstimator.frames[0].width / 2), height: CGFloat(videoEstimator.frames[0].height / 2))
                    .background(Color.gray)
                    .rotationEffect(.degrees(90))
            } else {
                Text("Failed to load image")
            }
            
            DrawingView(joints: startingPositions)
                .frame(width: CGFloat(videoEstimator.frames[0].width / 2), height: CGFloat(videoEstimator.frames[0].height / 2))
                .background(Color.clear)
                .rotationEffect(.degrees(90))
                .scaleEffect(x: -1, y: 1, anchor: .center)
        
        }
    }
}



struct SquatFeedBackView: View {
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
                    Text("Depth: \(depth(position: videoEstimator.bodyPartsArray[lowestPoint]))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                    Text("Comp Depth: \(compDepth(position: videoEstimator.bodyPartsArray[lowestPoint]))")
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

                    }
                    .padding(.bottom,70)
                    Text("During Lift: \(movingFeedback())")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom,10)
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
    
    func calculateGradient(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        return dy / dx
    }
        
    func depth(position: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> String{
        
        let torsoGradient = calculateGradient(from: CGPoint(x: videoEstimator.bodyPartsArray[startingIndex][.neck]!.x, y: videoEstimator.bodyPartsArray[startingIndex][.neck]!.y), to: CGPoint(x: videoEstimator.bodyPartsArray[startingIndex][.root]!.x, y: videoEstimator.bodyPartsArray[startingIndex][.root]!.y))
        
        if (torsoGradient > 0){
            
            let angle = angleBetweenThreePoints(pointA: (x: position[.rightHip]!.x, y: position[.rightHip]!.y), pointB: (x: position[.rightKnee]!.x, y: position[.rightKnee]!.y), pointC: (x: position[.rightAnkle]!.x, y: position[.rightAnkle]!.y))
            
            if angle > 90{
                return "The angle between your hip knee and ankle is \(Int(angle))\u{00B0} You should try to go lower!"
            }
            else{
                return "The angle between your hip knee and ankle is \(Int(angle))\u{00B0} this is good depth"
            }
        }
        else{
            print("facing left")
            
            let angle = angleBetweenThreePoints(pointA: (x: position[.leftHip]!.x, y: position[.leftHip]!.y), pointB: (x: position[.leftKnee]!.x, y: position[.leftKnee]!.y), pointC: (x: position[.leftAnkle]!.x, y: position[.leftAnkle]!.y))
            
            let gradient = calculateGradient(from: CGPoint(x: videoEstimator.bodyPartsArray[startingIndex][.leftKnee]!.x, y: videoEstimator.bodyPartsArray[startingIndex][.leftKnee]!.y), to: CGPoint(x: videoEstimator.bodyPartsArray[startingIndex][.leftHip]!.x, y: videoEstimator.bodyPartsArray[startingIndex][.leftHip]!.y))
        
            if gradient > 90{
                return "The angle between your hip knee and ankle is \(Int(angle))\u{00B0} You should try to go lower!"
            }
            else{
                return "The angle between your hip knee and ankle is \(Int(angle))\u{00B0} this is good depth"
            }

        }

    }
    
    func compDepth(position: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> String{
        let torsoGradient = calculateGradient(from: CGPoint(x: videoEstimator.bodyPartsArray[startingIndex][.neck]!.x, y: videoEstimator.bodyPartsArray[startingIndex][.neck]!.y), to: CGPoint(x: videoEstimator.bodyPartsArray[startingIndex][.root]!.x, y: videoEstimator.bodyPartsArray[startingIndex][.root]!.y))
        
        if (torsoGradient > 0){
            
            let gradient = calculateGradient(from: CGPoint(x: videoEstimator.bodyPartsArray[lowestPoint][.rightHip]!.x, y: videoEstimator.bodyPartsArray[lowestPoint][.rightHip]!.y), to: CGPoint(x: videoEstimator.bodyPartsArray[lowestPoint][.rightKnee]!.x, y: videoEstimator.bodyPartsArray[lowestPoint][.rightKnee]!.y))
            
            if gradient < 0{
                return "This is not comp depth you need to go lower"
            }
            else{
                return "This is comp depth"
            }
        }
        else{
            print("facing left")
            let gradient = calculateGradient(from: CGPoint(x: videoEstimator.bodyPartsArray[lowestPoint][.leftKnee]!.x, y: videoEstimator.bodyPartsArray[lowestPoint][.leftKnee]!.y), to: CGPoint(x: videoEstimator.bodyPartsArray[lowestPoint][.leftHip]!.x, y: videoEstimator.bodyPartsArray[lowestPoint][.leftHip]!.y))
            
            if gradient > 0{
                return "This is not comp depth you need to go lower"
            }
            else{
                return "This is comp depth"
            }

        }
        
    }
    
    func movingFeedback() -> String{
        
        let upplim = startingIndex + 20
                
        var prevHip: VNRecognizedPoint?
        var prevShoulder: VNRecognizedPoint?

        var hipDiffs: [CGFloat] = []
        var shoulderDiffs: [CGFloat] = []

        for bodyPart in videoEstimator.bodyPartsArray[startingIndex...upplim] {
            if prevHip == nil {
                prevHip = bodyPart[.leftHip]
            }
            if prevShoulder == nil {
                prevShoulder = bodyPart[.leftShoulder]
            }
                    
            if let hip = prevHip, let shoulder = prevShoulder {
                let hipDiff = abs(hip.y - bodyPart[.leftHip]!.y)
                let shoulderDiff = abs (shoulder.y - bodyPart[.leftShoulder]!.y)
                        
                hipDiffs.append(hipDiff)
                shoulderDiffs.append(shoulderDiff)
                        
            }
        }
        
        return compareAverages(array1: calculateRateOfChange(hipDiffs), array2: calculateRateOfChange(shoulderDiffs))
    }
    
    func calculateRateOfChange(_ array: [CGFloat]) -> [CGFloat] {
        var result = [CGFloat]()
        
        for i in 1..<array.count {
            let change = array[i] - array[i-1]
            let rateOfChange = change / array[i-1]
            result.append(rateOfChange)
        }
        
        return result
    }
    
    func compareAverages(array1: [CGFloat], array2: [CGFloat]) -> String {
        // Calculate the average of each array
        let average1 = array1.reduce(0, +) / CGFloat(array1.count)
        let average2 = array2.reduce(0, +) / CGFloat(array2.count)
        
        // Compare the averages
        if average1 > average2 {
            return "Your hips come up before your shoulders. Ideally they would come together"
        } else if average2 > average1 {
            return "Your shoulders come up before your hips. If your shoulders are rising first its likely your using your back more than your legs"
        } else {
            return "Your hips and shoulders are rising together. This is good"
        }
    }
    
    
    func angleBetweenThreePoints(pointA: (x: Double, y: Double), pointB: (x: Double, y: Double), pointC: (x: Double, y: Double)) -> Double {
        
        let AB = sqrt(pow(pointB.x - pointA.x, 2) + pow(pointB.y - pointA.y, 2))
        let BC = sqrt(pow(pointB.x - pointC.x, 2) + pow(pointB.y - pointC.y, 2))
        let AC = sqrt(pow(pointC.x - pointA.x, 2) + pow(pointC.y - pointA.y, 2))
        
        let angleRad = acos((pow(AB, 2) + pow(BC, 2) - pow(AC, 2)) / (2 * AB * BC))
        let angleDeg = angleRad * (180.0 / Double.pi)

//        print(angleRad)
        return angleDeg
    }
    
}
