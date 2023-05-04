import UIKit
import AVFoundation
import AVKit
import Vision
import CoreMedia
import SwiftUI

struct DrawingView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
//                if let root = joints[.root]?.location,
//                   let neck = joints[.neck]?.location,
//                   let rightShoulder = joints[.rightShoulder]?.location,
//                   let rightElbow = joints[.rightElbow]?.location,
//                   let rightWrist = joints[.rightWrist]?.location,
//                   let leftShoulder = joints[.leftShoulder]?.location,
//                   let leftElbow = joints[.leftElbow]?.location,
//                   let leftWrist = joints[.leftWrist]?.location,
//                   let rightHip = joints[.rightHip]?.location,
//                   let rightKnee = joints[.rightKnee]?.location,
//                   let rightAnkle = joints[.rightAnkle]?.location,
//                   let leftHip = joints[.leftHip]?.location,
//                   let leftKnee = joints[.leftKnee]?.location,
//                   let leftAnkle = joints[.leftAnkle]?.location {
//
//                    // Draw stick figure
//                    path.move(to: CGPoint(x: (1 - root.y) * geometry.size.width, y: root.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - neck.y) * geometry.size.width, y: neck.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - leftShoulder.y) * geometry.size.width, y: leftShoulder.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - leftElbow.y) * geometry.size.width, y: leftElbow.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - leftWrist.y) * geometry.size.width, y: leftWrist.x * geometry.size.height))
//                    path.move(to: CGPoint(x: (1 - neck.y) * geometry.size.width, y: neck.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - rightShoulder.y) * geometry.size.width, y: rightShoulder.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - rightElbow.y) * geometry.size.width, y: rightElbow.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - rightWrist.y) * geometry.size.width, y: rightWrist.x * geometry.size.height))
//                    path.move(to: CGPoint(x: (1 - root.y) * geometry.size.width, y: root.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - leftHip.y) * geometry.size.width, y: leftHip.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - leftKnee.y) * geometry.size.width, y: leftKnee.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - leftAnkle.y) * geometry.size.width, y: leftAnkle.x * geometry.size.height))
//                    path.move(to: CGPoint(x: (1 - root.y) * geometry.size.width, y: root.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - rightHip.y) * geometry.size.width, y: rightHip.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - rightKnee.y) * geometry.size.width, y: rightKnee.x * geometry.size.height))
//                    path.addLine(to: CGPoint(x: (1 - rightAnkle.y) * geometry.size.width, y: rightAnkle.x * geometry.size.height))
//
//                }
                // Draw stick figure
                
                // Draw stick figure
                if let root = joints[.root]?.location {
                    path.move(to: CGPoint(x: (1 - root.y) * geometry.size.width, y: root.x * geometry.size.height))
                }

                if let neck = joints[.neck]?.location {
                    path.addLine(to: CGPoint(x: (1 - neck.y) * geometry.size.width, y: neck.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - neck.y) * geometry.size.width, y: neck.x * geometry.size.height))
                }

                if let leftShoulder = joints[.leftShoulder]?.location {
                    path.addLine(to: CGPoint(x: (1 - leftShoulder.y) * geometry.size.width, y: leftShoulder.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - leftShoulder.y) * geometry.size.width, y: leftShoulder.x * geometry.size.height))
                }

                if let leftElbow = joints[.leftElbow]?.location {
                    path.addLine(to: CGPoint(x: (1 - leftElbow.y) * geometry.size.width, y: leftElbow.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - leftElbow.y) * geometry.size.width, y: leftElbow.x * geometry.size.height))
                }

                if let leftWrist = joints[.leftWrist]?.location {
                    path.addLine(to: CGPoint(x: (1 - leftWrist.y) * geometry.size.width, y: leftWrist.x * geometry.size.height))
                }

                if let rightShoulder = joints[.rightShoulder]?.location, let neck = joints[.neck]?.location {
                    path.move(to: CGPoint(x: (1 - neck.y) * geometry.size.width, y: neck.x * geometry.size.height))
                    path.addLine(to: CGPoint(x: (1 - rightShoulder.y) * geometry.size.width, y: rightShoulder.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - rightShoulder.y) * geometry.size.width, y: rightShoulder.x * geometry.size.height))
                }

                if let rightElbow = joints[.rightElbow]?.location {
                    path.addLine(to: CGPoint(x: (1 - rightElbow.y) * geometry.size.width, y: rightElbow.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - rightElbow.y) * geometry.size.width, y: rightElbow.x * geometry.size.height))
                }

                if let rightWrist = joints[.rightWrist]?.location {
                    path.addLine(to: CGPoint(x: (1 - rightWrist.y) * geometry.size.width, y: rightWrist.x * geometry.size.height))
                }

                if let leftHip = joints[.leftHip]?.location, let root = joints[.root]?.location {
                    path.move(to: CGPoint(x: (1 - root.y) * geometry.size.width, y: root.x * geometry.size.height))
                    path.addLine(to: CGPoint(x: (1 - leftHip.y) * geometry.size.width, y: leftHip.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - leftHip.y) * geometry.size.width, y: leftHip.x * geometry.size.height))
                }

                if let leftKnee = joints[.leftKnee]?.location {
                    path.addLine(to: CGPoint(x: (1 - leftKnee.y) * geometry.size.width, y: leftKnee.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - leftKnee.y) * geometry.size.width, y: leftKnee.x * geometry.size.height))
                }

                if let leftAnkle = joints[.leftAnkle]?.location {
                    path.addLine(to: CGPoint(x: (1 - leftAnkle.y) * geometry.size.width, y: leftAnkle.x * geometry.size.height))
                }

                if let rightHip = joints[.rightHip]?.location, let root = joints[.root]?.location {
                    path.move(to: CGPoint(x: (1 - root.y) * geometry.size.width, y: root.x * geometry.size.height))
                    path.addLine(to: CGPoint(x: (1 - rightHip.y) * geometry.size.width, y: rightHip.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - rightHip.y) * geometry.size.width, y: rightHip.x * geometry.size.height))
                }

                if let rightKnee = joints[.rightKnee]?.location {
                    path.addLine(to: CGPoint(x: (1 - rightKnee.y) * geometry.size.width, y: rightKnee.x * geometry.size.height))
                    path.move(to: CGPoint(x: (1 - rightKnee.y) * geometry.size.width, y: rightKnee.x * geometry.size.height))
                }

                if let rightAnkle = joints[.rightAnkle]?.location {
                    path.addLine(to: CGPoint(x: (1 - rightAnkle.y) * geometry.size.width, y: rightAnkle.x * geometry.size.height))
                }

            

            }
            .stroke(lineWidth: 2)
            .foregroundColor(Color.purple)
        }
    }
    
}
