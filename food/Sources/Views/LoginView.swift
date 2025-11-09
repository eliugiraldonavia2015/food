import SwiftUI
import GoogleSignIn
import UIKit

struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.orange)
                
                Text("Bienvenido a Food")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Inicia sesión para continuar")
                    .foregroundColor(.secondary)
                
                if isShowingSignUp {
                    signUpView
                } else {
                    signInView
                }
                
                GoogleSignInButton {
                    handleGoogleSignIn()
                }
                .frame(height: 50)
                .padding(.horizontal)
                
                Button(action: {
                    isShowingSignUp.toggle()
                }) {
                    Text(isShowingSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate")
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    showAlert = false
                }
            } message: {
                Text(alertMessage)
            }
            .overlay(
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(1.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
                .edgesIgnoringSafeArea(.all)
                .opacity(auth.isLoading ? 1 : 0)
            )
            .onReceive(auth.$errorMessage) { errorMessage in
                if let error = errorMessage {
                    alertMessage = error
                    showAlert = true
                }
            }
            .onChange(of: isShowingSignUp) { _, _ in
                // Reset fields when switching between login/signup
                email = ""
                password = ""
            }
        }
    }
    
    var signInView: some View {
        VStack(spacing: 15) {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
            
            SecureField("Contraseña", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.password)
            
            Button(action: {
                auth.signInWithEmail(email: email, password: password)
            }) {
                Text("Iniciar Sesión")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isFormValid)
        }
    }
    
    var signUpView: some View {
        VStack(spacing: 15) {
            Text("Próximamente podrás registrarte con correo")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
    
    private var isFormValid: Bool {
        // Basic validation - Firebase will do more robust validation
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
    
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            alertMessage = "No se pudo obtener el contexto de la ventana"
            showAlert = true
            return
        }
        
        auth.signInWithGoogle(presentingVC: rootViewController)
    }
}

struct GoogleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text("Iniciar con Google")
                    .fontWeight(.medium)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
