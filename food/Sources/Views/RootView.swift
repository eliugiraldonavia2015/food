// food/food/Sources/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @StateObject private var auth = AuthService.shared
    
    var body: some View {
        ZStack {
            // Contenido principal basado en el estado de autenticación
            Group {
                if auth.isAuthenticated {
                    HomeView() // ← Usa el HomeView del archivo separado
                } else {
                    LoginView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
            
            // Overlay de carga
            if auth.isLoading {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.5)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
    }
}

// MARK: - Previews
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
