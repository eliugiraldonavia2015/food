import UIKit
import FirebaseAuth
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        // 1) Firebase Auth (reCAPTCHA / email link / phone)
        if Auth.auth().canHandle(url) {
            print("[SceneDelegate] ✅ URL manejada por Firebase Auth")
            return
        }

        // 2) Google Sign-In (si lo usas)
        #if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.handle(url) {
            print("[SceneDelegate] ✅ URL manejada por Google Sign-In")
            return
        }
        #endif

        print("[SceneDelegate] ℹ️ URL no manejada por Firebase/Google: \(url.absoluteString)")
    }
}
