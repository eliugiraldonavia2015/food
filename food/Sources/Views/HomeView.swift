// food/food/Sources/Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @StateObject private var auth = AuthService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "house.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.orange)
                
                Text("¡Bienvenido!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Información del usuario
                if let user = auth.user {
                    VStack(spacing: 8) {
                        if let name = user.name {
                            Text(name)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        if let email = user.email {
                            Text(email)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                Text("Has iniciado sesión correctamente")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    auth.signOut()
                }) {
                    Text("Cerrar sesión")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    showAlert = false
                }
            } message: {
                Text(alertMessage)
            }
            .onReceive(auth.$errorMessage) { errorMessage in
                if let error = errorMessage {
                    alertMessage = error
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Previews
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
