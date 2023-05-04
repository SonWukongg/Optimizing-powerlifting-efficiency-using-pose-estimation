import UIKit
import SwiftUI

struct benchView: UIViewControllerRepresentable {
   func makeUIViewController(context: Context) -> benchViewController {
      return benchViewController()
   }

   func updateUIViewController(_ uiViewController: benchViewController, context: Context) {
      // Update the view controller
   }
}

