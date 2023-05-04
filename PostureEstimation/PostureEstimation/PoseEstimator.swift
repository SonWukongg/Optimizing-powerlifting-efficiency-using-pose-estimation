import Foundation
import AVFoundation
import Vision
import Combine

class PoseEstimator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    let sequenceHandler = VNSequenceRequestHandler()

    @Published var bodyParts = [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]()
    var wasInBottomPosition = false
    @Published var squatCount = 0
    @Published var isGoodPosture = true
    var postureTimeline = [(timeStamp: Date, posture: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint])]()
    var subscriptions = Set<AnyCancellable>()

    override init() {
        super.init()
        $bodyParts
            .dropFirst()
            .sink(receiveValue: { bodyParts in self.countSquats(bodyParts: bodyParts)})
            .store(in: &subscriptions)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let humanBodyRequest = VNDetectHumanBodyPoseRequest(completionHandler: detectedBodyPose)
        do {
            try sequenceHandler.perform(
              [humanBodyRequest],
              on: sampleBuffer,
                orientation: .right)
        } catch {
          print(error.localizedDescription)
        }
    }

    func detectedBodyPose(request: VNRequest, error: Error?) {
        guard let bodyPoseResults = request.results as? [VNHumanBodyPoseObservation]
          else { return }
        guard let bodyParts = try? bodyPoseResults.first?.recognizedPoints(.all) else { return }
        DispatchQueue.main.async {
            self.bodyParts = bodyParts
            let posture = bodyParts
            let timeStamp = Date()
            self.postureTimeline.append((timeStamp: timeStamp, posture: posture))
        }
    }

    func countSquats(bodyParts: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) {

        let rightKnee = bodyParts[.rightKnee]!.location
        let leftKnee = bodyParts[.rightKnee]!.location
        let rightHip = bodyParts[.rightHip]!.location
        let rightAnkle = bodyParts[.rightAnkle]!.location
        let leftAnkle = bodyParts[.leftAnkle]!.location

        let firstAngle = atan2(rightHip.y - rightKnee.y, rightHip.x - rightKnee.x)
        let secondAngle = atan2(rightAnkle.y - rightKnee.y, rightAnkle.x - rightKnee.x)
        var angleDiffRadians = firstAngle - secondAngle
        while angleDiffRadians < 0 {
            angleDiffRadians += 2 * .pi
        }

        if angleDiffRadians > .pi / 2 {
            wasInBottomPosition = true
        } else if wasInBottomPosition {
            wasInBottomPosition = false
            squatCount += 1
        }

        let leftHip = bodyParts[.leftHip]!.location
        let hipWidth = abs(leftHip.x - rightHip.x)
        let shoulderWidth = bodyParts[.rightShoulder]!.location.distance(to: bodyParts[.leftShoulder]!.location)
        let isGoodPosture = hipWidth > shoulderWidth * 0.8 && hipWidth < shoulderWidth * 1.2
        self.isGoodPosture = isGoodPosture
    }
}
