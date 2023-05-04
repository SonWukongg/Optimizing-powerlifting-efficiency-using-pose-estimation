import Foundation
import SwiftUI
import AVFoundation
import Vision

//Using UIViewControllerRepresentable we can create and manage a UI
struct CameraViewWrapper: UIViewControllerRepresentable {
    var poseEstimator: PoseEstimator
    
    //We want to give it a variable PoseEstimator so that it can receive sample frames
    func makeUIViewController(context: Context) -> some UIViewController {
        let cvc = CameraViewController()
        cvc.delegate = poseEstimator
        return cvc
    }
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}
