import SwiftUI

struct ContentView: View {
    
    @StateObject var poseEstimator = PoseEstimator()
    
    let colors: [Color] = [.mint]
    @State private var selection: Color? // Nothing selected by default.

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Squat", value: "Squat")
                NavigationLink("Bench", value: "Bench")
                NavigationLink("Deadlift", value: "Deadlift")
                NavigationLink("Live", value: "live")
            }
            .navigationDestination(for: String.self){ string in
                switch string {
                case "Bench":
                    benchView()
                case "Squat":
                    squatView()
                case "Deadlift":
                    deadliftView()
                case "live":
                    liveView()
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Exercise")
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
