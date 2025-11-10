// Sources/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @StateObject private var auth = AuthService.shared
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            Group {
                if auth.isAuthenticated {
                    if showOnboarding {
                        // 🧩 Pantalla de onboarding
                        OnboardingView {
                            withAnimation(.easeInOut) {
                                self.showOnboarding = false
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading))
                        )
                    } else {
                        // 🏠 Pantalla principal
                        HomeView()
                            .transition(.opacity)
                    }
                } else {
                    // 🔐 Pantalla de login
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
            
            // ⏳ Overlay de carga global
            if auth.isLoading {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.5)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated, let uid = auth.user?.uid else { return }
            // 🔍 Verificar si el usuario ya completó el onboarding
            OnboardingService.shared.hasCompletedOnboarding(uid: uid) { completed in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.showOnboarding = !completed
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
