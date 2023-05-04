import AVFoundation
import UIKit

final class CameraView: UIView {
    //This is the root layer with type AVCaptureVideoPreviewLayer
    //Provide a preivew of the content that the camera captures
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
      }
}
