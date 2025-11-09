// food/food/Sources/Views/LoginView.swift
import SwiftUI
import GoogleSignIn
import UIKit

struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var isUsernameAvailable = true
    @State private var checkingUsername = false
    @State private var phoneNumber = ""
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
                    resetSignUpFields()
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
                resetSignUpFields()
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
                    .background(isSignInFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isSignInFormValid)
        }
    }
    
    var signUpView: some View {
        VStack(spacing: 15) {
            // Nombre y Apellido
            HStack(spacing: 10) {
                TextField("Nombre", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                TextField("Apellido", text: $lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            // Email
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
            
            // Username
            HStack {
                TextField("Nombre de usuario", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                if !username.isEmpty {
                    if checkingUsername {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .frame(width: 20, height: 20)
                    } else if isUsernameAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Validación de username
            usernameValidation
            
            // Contraseña
            VStack(alignment: .leading, spacing: 5) {
                SecureField("Contraseña", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                if !password.isEmpty {
                    Text("Mínimo 8 caracteres con mayúscula y minúscula")
                        .font(.caption)
                        .foregroundColor(isPasswordValid ? .green : .red)
                }
            }
            
            // ✅ CORREGIDO: Confirmar contraseña con validación en tiempo real
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    SecureField("Confirmar contraseña", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(borderColor, lineWidth: 1)
                                .padding(.horizontal, -4)
                                .padding(.vertical, -8)
                        )
                        .textContentType(.newPassword)
                    
                    // Icono de validación en tiempo real
                    if !confirmPassword.isEmpty {
                        if passwordsMatch {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Mensaje de error en tiempo real
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Las contraseñas no coinciden")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Teléfono (opcional)
            TextField("Teléfono (opcional)", text: $phoneNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.phonePad)
            
            // Botón de registro
            Button(action: {
                registerUser()
            }) {
                Text("Registrarse")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSignUpFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isSignUpFormValid)
        }
    }
    
    // Computed property para verificar coincidencia de contraseñas
    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
    
    // Computed property para el color del borde
    private var borderColor: Color {
        if confirmPassword.isEmpty {
            return Color.gray
        } else if passwordsMatch {
            return Color.green
        } else {
            return Color.red
        }
    }
    
    private func resetSignUpFields() {
        email = ""
        password = ""
        confirmPassword = ""
        firstName = ""
        lastName = ""
        username = ""
        isUsernameAvailable = true
        checkingUsername = false
        phoneNumber = ""
    }
    
    private func registerUser() {
        guard isSignUpFormValid else { return }
        
        auth.signUpWithEmail(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            username: username
        )
    }
    
    private var isSignInFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
    
    private var isSignUpFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(email) &&
        !password.isEmpty &&
        password == confirmPassword &&
        isPasswordValid &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isUsernameAvailable
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8 &&
        password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
        password.rangeOfCharacter(from: .lowercaseLetters) != nil
    }
    
    private var usernameValidation: some View {
        VStack(alignment: .leading) {
            if !username.isEmpty {
                if checkingUsername {
                    Text("Verificando disponibilidad...")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if isUsernameAvailable {
                    Text("Nombre de usuario disponible")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Nombre de usuario no disponible")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: username) { _, newUsername in
            guard !newUsername.isEmpty else {
                isUsernameAvailable = true
                checkingUsername = false
                return
            }
            checkUsernameAvailability(newUsername)
        }
    }
    
    private func checkUsernameAvailability(_ username: String) {
        checkingUsername = true
        isUsernameAvailable = false
        
        DatabaseService.shared.isUsernameAvailable(username) { isAvailable in
            DispatchQueue.main.async {
                self.isUsernameAvailable = isAvailable
                self.checkingUsername = false
            }
        }
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
