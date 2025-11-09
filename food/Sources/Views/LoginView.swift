// food/food/Sources/Views/LoginView.swift
import SwiftUI
import GoogleSignIn
import UIKit

// MARK: - UI Helper Extensions
fileprivate extension PasswordStrength.StrengthLevel {
    var uiColor: Color {
        switch self.colorIdentifier {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        default: return .gray
        }
    }
    
    var uiProgressValue: CGFloat {
        return CGFloat(self.progressValue)
    }
}

// MARK: - Focus Field Enum
private enum FocusField: Hashable {
    case firstName, lastName, email, emailOrUsername, username, password, confirmPassword, phone
}

// MARK: - Main Login View
struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @State private var emailOrUsername = ""  // Solo para login
    @State private var email = ""            // Específico para registro
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
    
    @State private var passwordStrength: PasswordStrength?
    @State private var loginType: AuthService.LoginType = .unknown
    
    @FocusState private var focusedField: FocusField?
    
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
    
    // MARK: - Subviews
    private var signInView: some View {
        VStack(spacing: 15) {
            // ✅ CORREGIDO: Campo unificado para email/username (solo login)
            TextField("Email o nombre de usuario", text: $emailOrUsername)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .textContentType(.username)
                .focused($focusedField, equals: .emailOrUsername)
                .onChange(of: emailOrUsername) { _, newValue in
                    loginType = auth.identifyLoginType(newValue)
                }
                .overlay(
                    Group {
                        if loginType != .unknown {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(loginTypeColor, lineWidth: 1)
                                .padding(.horizontal, -4)
                                .padding(.vertical, -8)
                        }
                    }
                )
            
            // ✅ MEJORADO: Mensaje contextual
            if loginType != .unknown {
                Text(loginTypeMessage)
                    .font(.caption)
                    .foregroundColor(loginTypeColor)
                    .padding(.leading, 10)
                    .transition(.opacity)
            }
            
            SecureField("Contraseña", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.password)
                .focused($focusedField, equals: .password)
            
            Button(action: {
                auth.signInWithEmailOrUsername(identifier: emailOrUsername, password: password)
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
    
    private var signUpView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 15) {
                    // Personal Information
                    HStack(spacing: 10) {
                        TextField("Nombre", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .focused($focusedField, equals: .firstName)
                            .id(FocusField.firstName)
                        
                        TextField("Apellido", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .focused($focusedField, equals: .lastName)
                            .id(FocusField.lastName)
                    }
                    
                    // ✅ CORREGIDO: Campo de email específico para registro
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        .id(FocusField.email)
                    
                    // Username with Availability Check
                    HStack {
                        TextField("Nombre de usuario", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .focused($focusedField, equals: .username)
                            .id(FocusField.username)
                        
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
                    
                    usernameValidationView
                    
                    // ✅ CORREGIDO: Password Section con campo email correcto
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField("Contraseña", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .id(FocusField.password)
                            .onChange(of: password) { _, newPass in
                                // ✅ CORREGIDO: Usar email específico del registro
                                passwordStrength = auth.evaluatePasswordStrength(newPass, email: email, username: username)
                                
                                // Scroll automático cuando aparece el feedback
                                if !newPass.isEmpty && passwordStrength != nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(FocusField.password, anchor: .center)
                                        }
                                    }
                                }
                            }
                        
                        if let strength = passwordStrength {
                            PasswordStrengthView(strength: strength)
                        }
                    }
                    
                    // ✅ CORREGIDO: Password Confirmation
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
                                .focused($focusedField, equals: .confirmPassword)
                                .id(FocusField.confirmPassword)
                                .onChange(of: confirmPassword) { _, newValue in
                                    // Scroll automático cuando se empieza a confirmar
                                    if !newValue.isEmpty {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(FocusField.confirmPassword, anchor: .center)
                                            }
                                        }
                                    }
                                }
                            
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
                        
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Las contraseñas no coinciden")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Optional Phone
                    TextField("Teléfono (opcional)", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                        .id(FocusField.phone)
                    
                    // Register Button
                    Button(action: registerUser) {
                        Text("Registrarse")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSignUpFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isSignUpFormValid)
                    .padding(.top)
                    
                    // Minimum Requirements Info
                    if !password.isEmpty {
                        minimumRequirementsView
                    }
                }
                .padding()
            }
            .onAppear {
                // scrollProxy = proxy // Removido por redundancia
            }
            // ✅ NUEVO: Manejar el teclado automáticamente
            .onChange(of: focusedField) { _, newField in
                if let field = newField {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Component Subviews
    private var usernameValidationView: some View {
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
    
    private var minimumRequirementsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Requisitos mínimos:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(alignment: .top) {
                Image(systemName: meetsMinimumRequirements ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(meetsMinimumRequirements ? .green : .gray)
                Text("8+ caracteres, 1 mayúscula, 1 minúscula")
                    .font(.caption)
                    .foregroundColor(meetsMinimumRequirements ? .green : .secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(meetsMinimumRequirements ? Color.green : Color.gray, lineWidth: 1)
                .background(Color.gray.opacity(0.05))
        )
    }
    
    // MARK: - Password Strength Component
    private struct PasswordStrengthView: View {
        let strength: PasswordStrength
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Header with Strength Info
                HStack {
                    VStack(alignment: .leading) {
                        Text("Nivel de seguridad")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(strength.strength.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(strength.strength.uiColor)
                    }
                    
                    Spacer()
                    
                    Text("\(strength.score)/40")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(strength.strength.uiColor.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .frame(height: 6)
                            .foregroundColor(.gray.opacity(0.3))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .frame(
                                width: geometry.size.width * strength.strength.uiProgressValue,
                                height: 6
                            )
                            .foregroundColor(strength.strength.uiColor)
                    }
                }
                .frame(height: 6)
                
                // Feedback Messages
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(strength.feedback.prefix(4).enumerated()), id: \.offset) { _, feedback in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: iconForFeedback(feedback))
                                .font(.caption2)
                                .foregroundColor(colorForFeedback(feedback))
                                .padding(.top, 2)
                            
                            Text(feedback)
                                .font(.caption)
                                .foregroundColor(colorForFeedback(feedback))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        
        private func iconForFeedback(_ feedback: String) -> String {
            if feedback.contains("🎉") || feedback.contains("✅") {
                return "star.fill"
            } else if feedback.contains("✓") {
                return "checkmark.circle.fill"
            } else if feedback.contains("⚠️") {
                return "exclamationmark.triangle.fill"
            } else if feedback.contains("💡") {
                return "lightbulb.fill"
            } else {
                return "info.circle.fill"
            }
        }
        
        private func colorForFeedback(_ feedback: String) -> Color {
            if feedback.contains("🎉") || feedback.contains("✅") || feedback.contains("✓") {
                return .green
            } else if feedback.contains("⚠️") {
                return .orange
            } else if feedback.contains("💡") {
                return .blue
            } else {
                return .secondary
            }
        }
    }
    
    // MARK: - Computed Properties
    private var loginTypeColor: Color {
        switch loginType {
        case .email: return .green
        case .username: return .blue
        case .unknown: return .gray
        }
    }
    
    private var loginTypeMessage: String {
        switch loginType {
        case .email: return "Identificador de tipo: email"
        case .username: return "Identificador de tipo: nombre de usuario"
        case .unknown: return ""
        }
    }
    
    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
    
    private var borderColor: Color {
        if confirmPassword.isEmpty {
            return Color.gray
        } else if passwordsMatch {
            return Color.green
        } else {
            return Color.red
        }
    }
    
    private var meetsMinimumRequirements: Bool {
        auth.meetsMinimumPasswordRequirements(password)
    }
    
    private var isSignInFormValid: Bool {
        !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
    
    // ✅ CORREGIDO: Validación correcta para registro
    private var isSignUpFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        auth.isValidEmail(email) &&  // ← Ahora valida el campo email correcto
        !password.isEmpty &&
        password == confirmPassword &&
        meetsMinimumRequirements &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isUsernameAvailable
    }
    
    // MARK: - Helper Methods
    private func resetSignUpFields() {
        email = ""            // Resetear email de registro
        password = ""
        confirmPassword = ""
        firstName = ""
        lastName = ""
        username = ""
        isUsernameAvailable = true
        checkingUsername = false
        phoneNumber = ""
        passwordStrength = nil
        focusedField = nil
        loginType = .unknown
        // NO resetear emailOrUsername para mantener el login
    }
    
    private func registerUser() {
        guard isSignUpFormValid else { return }
        
        // ✅ CORREGIDO: Usar el campo email específico
        auth.signUpWithEmail(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            username: username
        )
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

// MARK: - Google Sign In Button
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
