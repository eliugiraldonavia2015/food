// food/food/Sources/Views/LoginView.swift
import SwiftUI
import GoogleSignIn
import UIKit

// MARK: - AuthFlow Enum
enum AuthFlow {
    case main
    case phone
}

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
    case firstName, lastName, email, emailOrUsername, username, password, confirmPassword, phone, phoneVerificationCode
}

// MARK: - Main Login View
struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @State private var emailOrUsername = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var isUsernameAvailable = true
    @State private var checkingUsername = false
    @State private var phoneNumber = "" // Para el flujo de teléfono
    @State private var verificationCode = ""
    @State private var isShowingSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var canResendCode = false
    @State private var resendTimer = 60
    @State private var resendTimerTask: Task<Void, Never>?
    
    @State private var passwordStrength: PasswordStrength?
    @State private var loginType: AuthService.LoginType = .unknown
    
    @State private var currentAuthFlow: AuthFlow = .main
    
    @FocusState private var focusedField: FocusField?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                if currentAuthFlow == .phone {
                    phoneAuthFlowView
                } else {
                    mainAuthView
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
            .onChange(of: auth.phoneAuthState) { oldState, newState in
                handlePhoneAuthStateChange(newState)
            }
            .onDisappear {
                resendTimerTask?.cancel()
            }
        }
    }
    
    // MARK: - Main Auth View
    private var mainAuthView: some View {
        VStack(spacing: 30) {
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
            
            // Botones de autenticación social
            VStack(spacing: 12) {
                GoogleSignInButton {
                    handleGoogleSignIn()
                }
                .frame(height: 50)
                
                PhoneSignInButton {
                    withAnimation {
                        currentAuthFlow = .phone
                    }
                }
                .frame(height: 50)
            }
            .padding(.horizontal)
            
            Button(action: {
                isShowingSignUp.toggle()
                resetSignUpFields()
            }) {
                Text(isShowingSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate")
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Phone Auth Flow
    private var phoneAuthFlowView: some View {
        VStack(spacing: 20) {
            phoneAuthHeader
            
            if auth.phoneAuthState.isAwaitingCode {
                phoneVerificationView
            } else {
                phoneNumberInputView
            }
            
            Spacer()
            
            if !auth.phoneAuthState.isAwaitingCode {
                backToMainLoginButton
            }
        }
        .padding()
    }
    
    private var phoneAuthHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Iniciar con Teléfono")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Ingresa tu número para recibir un código de verificación")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var phoneNumberInputView: some View {
        VStack(spacing: 20) {
            // Campo de teléfono con formato internacional
            VStack(alignment: .leading, spacing: 8) {
                Text("Número de teléfono")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("+593")
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    
                    TextField("99 123 4567", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: phoneNumber) { _, newValue in
                            // Formatear automáticamente
                            formatPhoneNumber(newValue)
                        }
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                if !phoneNumber.isEmpty && !isValidPhoneNumber {
                    Text("Por favor ingresa un número válido")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Button(action: sendPhoneVerificationCode) {
                HStack {
                    if auth.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "message.fill")
                    }
                    
                    Text("Enviar código SMS")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidPhoneNumber ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!isValidPhoneNumber || auth.isLoading)
            
            // Información sobre costos
            Text("Pueden aplicarse cargos por mensajes de texto")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var phoneVerificationView: some View {
        VStack(spacing: 20) {
            verificationHeader
            
            verificationCodeField
            
            resendTimerView
            
            resendCodeButton
        }
        .padding()
    }
    
    private var verificationHeader: some View {
        VStack(spacing: 8) {
            Text("Verificación por SMS")
                .font(.headline)
                .fontWeight(.bold)
            
            if case .awaitingVerification(let phoneNumber) = auth.phoneAuthState {
                Text("Hemos enviado un código de 6 dígitos a:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(phoneNumber)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                Text("Hemos enviado un código de 6 dígitos a tu teléfono")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }
    
    private var verificationCodeField: some View {
        TextField("Código de verificación", text: $verificationCode)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedField, equals: .phoneVerificationCode)
            .onChange(of: verificationCode) { _, newValue in
                // Limitar a 6 dígitos y auto-verificar
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count > 6 {
                    verificationCode = String(filtered.prefix(6))
                } else {
                    verificationCode = filtered
                }
                
                if verificationCode.count == 6 {
                    auth.verifyCode(verificationCode)
                }
            }
    }
    
    private var resendTimerView: some View {
        Group {
            if !canResendCode {
                Text("Puedes reenviar el código en \(resendTimer) segundos")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var resendCodeButton: some View {
        Button(action: handleResendCode) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Reenviar código")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canResendCode ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!canResendCode || auth.isLoading)
    }
    
    private var backToMainLoginButton: some View {
        Button(action: {
            withAnimation {
                currentAuthFlow = .main
            }
        }) {
            Text("← Volver a otras opciones")
                .foregroundColor(.blue)
                .font(.subheadline)
        }
    }
    
    // MARK: - Sign In View (para el flujo principal)
    private var signInView: some View {
        VStack(spacing: 15) {
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
            .disabled(!isSignInFormValid || auth.isLoading)
        }
    }
    
    // MARK: - Sign Up View (para el flujo principal)
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
                    
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField("Contraseña", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .id(FocusField.password)
                            .onChange(of: password) { _, newPass in
                                passwordStrength = auth.evaluatePasswordStrength(newPass, email: email, username: username)
                            }
                        
                        if let strength = passwordStrength {
                            PasswordStrengthView(strength: strength)
                        }
                    }
                    
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
                    
                    // Register Button
                    Button(action: registerUser) {
                        Text("Registrarse")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSignUpFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isSignUpFormValid || auth.isLoading)
                    .padding(.top)
                    
                    if !password.isEmpty {
                        minimumRequirementsView
                    }
                }
                .padding()
            }
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
    
    // MARK: - Authentication Buttons
    private struct PhoneSignInButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 20))
                    
                    Text("Iniciar con teléfono")
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
    
    private struct GoogleSignInButton: View {
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
    
    // MARK: - Computed Properties
    private var loginTypeColor: Color {
        switch loginType {
        case .email: return .green
        case .username: return .blue
        case .phone: return .purple
        case .unknown: return .gray
        }
    }
    
    private var loginTypeMessage: String {
        switch loginType {
        case .email: return "Identificador de tipo: email"
        case .username: return "Identificador de tipo: nombre de usuario"
        case .phone: return "Identificador de tipo: teléfono"
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
    
    private var isSignUpFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        auth.isValidEmail(email) &&
        !password.isEmpty &&
        password == confirmPassword &&
        meetsMinimumRequirements &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isUsernameAvailable
    }
    
    private var isValidPhoneNumber: Bool {
        let fullNumber = "+593\(phoneNumber.filter { $0.isNumber })"
        return auth.isValidPhoneNumber(fullNumber) && phoneNumber.count >= 8
    }
    
    // MARK: - Helper Methods
    private func resetSignUpFields() {
        email = ""
        password = ""
        confirmPassword = ""
        firstName = ""
        lastName = ""
        username = ""
        isUsernameAvailable = true
        checkingUsername = false
        passwordStrength = nil
        focusedField = nil
        loginType = .unknown
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
    
    private func formatPhoneNumber(_ input: String) {
        let numbers = input.filter { $0.isNumber }
        
        if numbers.count <= 9 {
            var formatted = ""
            let count = numbers.count
            
            if count > 0 {
                formatted = String(numbers.prefix(2))
            }
            if count > 2 {
                formatted += " " + String(numbers.dropFirst(2).prefix(3))
            }
            if count > 5 {
                formatted += " " + String(numbers.dropFirst(5).prefix(4))
            }
            
            phoneNumber = formatted
        } else {
            phoneNumber = String(numbers.prefix(9))
        }
    }
    
    private func sendPhoneVerificationCode() {
        guard isValidPhoneNumber else { return }
        
        let fullNumber = "+593\(phoneNumber.filter { $0.isNumber })"
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            auth.handleAuthError("No se pudo obtener el contexto de la ventana")
            return
        }
        
        auth.sendVerificationCode(phoneNumber: fullNumber, presentingVC: rootViewController)
        setupResendTimer()
    }
    
    private func handleResendCode() {
        guard canResendCode else { return }
        sendPhoneVerificationCode()
    }
    
    private func setupResendTimer() {
        resendTimerTask?.cancel()
        canResendCode = false
        resendTimer = 60
        
        resendTimerTask = Task {
            while resendTimer > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if Task.isCancelled { return }
                
                await MainActor.run {
                    resendTimer -= 1
                    if resendTimer <= 0 {
                        canResendCode = true
                    }
                }
            }
        }
    }
    
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            alertMessage = "No se pudo obtener el contexto de la ventana"
            showAlert = true
            return
        }
        
        auth.signInWithGoogle(presentingVC: rootViewController)
    }
    
    private func handlePhoneAuthStateChange(_ newState: AuthService.PhoneAuthState) {
        switch newState {
        case .awaitingVerification:
            verificationCode = ""
            focusedField = .phoneVerificationCode
        case .idle, .error:
            verificationCode = ""
        case .verified:
            // Limpiar campos después de verificación exitosa
            phoneNumber = ""
            verificationCode = ""
            // Regresar al flujo principal después de verificación exitosa
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation {
                    currentAuthFlow = .main
                }
            }
        default:
            break
        }
    }
}

// MARK: - Previews
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
