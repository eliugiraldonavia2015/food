import SwiftUI
import FirebaseCore

@main
struct FoodApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
