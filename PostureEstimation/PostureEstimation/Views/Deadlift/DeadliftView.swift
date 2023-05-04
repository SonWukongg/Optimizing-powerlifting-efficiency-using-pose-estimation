import UIKit
import SwiftUI

struct deadliftView: UIViewControllerRepresentable {
   func makeUIViewController(context: Context) -> deadliftViewController {
      return deadliftViewController()
   }

   func updateUIViewController(_ uiViewController: deadliftViewController, context: Context) {
      // Update the view controller
   }
}

