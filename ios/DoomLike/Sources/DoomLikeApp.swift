import SwiftUI

@main
struct DoomLikeApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
