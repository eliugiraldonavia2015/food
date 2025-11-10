// food/food/Sources/Services/AuthService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Combine

// MARK: - Domain Models
public struct PasswordStrength {
    public let score: Int
    public let strength: StrengthLevel
    public let feedback: [String]
    
    public enum StrengthLevel: String, CaseIterable {
        case veryWeak = "Muy débil"
        case weak = "Débil"
        case medium = "Media"
        case strong = "Fuerte"
        case veryStrong = "Muy fuerte"
        
        public var colorIdentifier: String {
            switch self {
            case .veryWeak, .weak: return "red"
            case .medium: return "orange"
            case .strong, .veryStrong: return "green"
            }
        }
        
        public var progressValue: Double {
            switch self {
            case .veryWeak: return 0.2
            case .weak: return 0.4
            case .medium: return 0.6
            case .strong: return 0.8
            case .veryStrong: return 1.0
            }
        }
    }
}

public struct AppUser: Identifiable {
    public let id = UUID()
    public let uid: String
    public let email: String?
    public let name: String?
    public let username: String?
    public let phoneNumber: String?
    public let photoURL: URL?
    
    public init(
        uid: String,
        email: String?,
        name: String?,
        username: String? = nil,
        phoneNumber: String? = nil,
        photoURL: URL?
    ) {
        self.uid = uid
        self.email = email
        self.name = name
        self.username = username
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
    }
}

// MARK: - Authentication Service
public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    // MARK: - Published Properties
    @Published public private(set) var user: AppUser?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var phoneAuthState: PhoneAuthState = .idle
    
    // MARK: - Private Properties
    private let firestore = Firestore.firestore(database: "logincloud")
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var verificationID: String?
    
    private init() {
        configureFirestore()
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Configuration
    private func configureFirestore() {
        let settings = firestore.settings
        settings.host = "firestore.googleapis.com"
        firestore.settings = settings
        print("[AuthService] Firestore configured for database: logincloud")
    }
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            DispatchQueue.main.async {
                self?.updateAuthState(with: firebaseUser)
            }
        }
    }
}

// MARK: - Phone Authentication
extension AuthService {
    public enum PhoneAuthState: Equatable {
        case idle
        case sendingCode
        case awaitingVerification(phoneNumber: String)
        case verified
        case error(String)
        
        public var isAwaitingCode: Bool {
            switch self {
            case .awaitingVerification, .sendingCode:
                return true
            default:
                return false
            }
        }
        
        public var canSendCode: Bool {
            switch self {
            case .idle, .error:
                return true
            default:
                return false
            }
        }
    }
    
    // ✅ MÉTODO ACTUALIZADO (simple y directo)
    public func sendVerificationCode(phoneNumber: String, presentingVC: UIViewController) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        phoneAuthState = .sendingCode
        
        print("[AuthService] 🔄 Enviando código a: \(phoneNumber)")
        
        // ✅ ENFOQUE PROFESIONAL: Simple y directo
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    // Log detallado para diagnóstico
                    let nsError = error as NSError
                    print("[AuthService] ❌ Error Firebase: \(error.localizedDescription)")
                    print("[AuthService] 🔍 Código: \(nsError.code), Dominio: \(nsError.domain)")
                    
                    self.handlePhoneAuthError(error)
                    return
                }
                
                guard let verificationID = verificationID else {
                    print("[AuthService] ❌ Error: verificationID es nil")
                    self.phoneAuthState = .error("Error del servidor. Intenta nuevamente.")
                    return
                }
                
                self.verificationID = verificationID
                self.phoneAuthState = .awaitingVerification(phoneNumber: phoneNumber)
                print("[AuthService] ✅ Código enviado. Estado: awaitingVerification")
            }
        }
    }
    
    public func verifyCode(_ code: String) {
        guard !isLoading else { return }
        guard let verificationID = verificationID else {
            handleAuthError("No hay verificación activa. Solicita un nuevo código.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.handlePhoneAuthError(error)
                    return
                }
                
                guard let user = authResult?.user else {
                    self.handleAuthError("Error desconocido al verificar el código")
                    return
                }
                
                self.handlePhoneAuthenticationSuccess(user: user)
            }
        }
    }
    
    private func handlePhoneAuthenticationSuccess(user: User) {
        // Determinar si es usuario nuevo
        let isNewUser = user.metadata.creationDate == user.metadata.lastSignInDate
        
        if isNewUser {
            createUserProfileForPhoneAuth(user: user)
        } else {
            updateAuthState(with: user)
        }
        
        phoneAuthState = .verified
        self.verificationID = nil
    }
    
    private func createUserProfileForPhoneAuth(user: User) {
        let phoneNumber = user.phoneNumber ?? "unknown"
        let tempUsername = "user_\(user.uid.prefix(8))"
        let tempName = "Usuario \(user.uid.prefix(6))"
        
        // ✅ Compatible con tu DatabaseService actual
        DatabaseService.shared.createUserDocument(
            uid: user.uid,
            name: tempName,
            email: nil,
            username: tempUsername
        )
        
        // Actualizar estado inmediatamente
        self.user = AppUser(
            uid: user.uid,
            email: nil,
            name: tempName,
            username: tempUsername,
            phoneNumber: phoneNumber,
            photoURL: nil
        )
        self.isAuthenticated = true
    }
    
    public func resetPhoneAuth() {
        phoneAuthState = .idle
        verificationID = nil
        errorMessage = nil
    }
}

// MARK: - Authentication Methods
extension AuthService {
    public enum LoginType {
        case email
        case username
        case phone
        case unknown
    }
    
    // MARK: - Google Sign-In
    public func signInWithGoogle(presentingVC: UIViewController) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        resetPhoneAuth()
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] signInResult, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleAuthError("Error de Google: \(error.localizedDescription)")
                return
            }
            
            guard let signInResult = signInResult,
                  let idToken = signInResult.user.idToken?.tokenString else {
                self.handleAuthError("Token de Google inválido")
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: signInResult.user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.handleAuthError("Error de Firebase: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Email/Username Sign-In
    public func signInWithEmailOrUsername(identifier: String, password: String) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        resetPhoneAuth()
        
        if isValidEmail(identifier) {
            signInWithEmail(email: identifier, password: password)
        } else {
            // Buscar email por username
            DatabaseService.shared.getEmailForUsername(username: identifier) { [weak self] email in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard let email = email else {
                        self.handleAuthError("Usuario no encontrado")
                        return
                    }
                    self.signInWithEmail(email: email, password: password)
                }
            }
        }
    }
    
    private func signInWithEmail(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleSignInError(error)
                }
            }
        }
    }
    
    // MARK: - Email Sign-Up
    public func signUpWithEmail(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        username: String,
        phoneNumber: String? = nil
    ) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        resetPhoneAuth()
        
        // Validación de requisitos mínimos
        guard meetsMinimumPasswordRequirements(password) else {
            handleAuthError("La contraseña debe tener al menos 8 caracteres, incluyendo una mayúscula y una minúscula.")
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleSignUpError(error)
                    return
                }
                
                guard let user = result?.user else {
                    self?.handleAuthError("Error desconocido al crear usuario")
                    return
                }
                
                self?.createUserProfileAfterEmailSignUp(
                    user: user,
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    username: username,
                    phoneNumber: phoneNumber
                )
            }
        }
    }
    
    private func createUserProfileAfterEmailSignUp(
        user: User,
        email: String,
        firstName: String,
        lastName: String,
        username: String,
        phoneNumber: String?
    ) {
        let fullName = "\(firstName) \(lastName)"
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = fullName
        changeRequest.commitChanges { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[AuthService] Profile update error: \(error)")
                }
                
                // ✅ Compatible con tu DatabaseService actual
                DatabaseService.shared.createUserDocument(
                    uid: user.uid,
                    name: fullName,
                    email: email,
                    username: username
                )
                
                self?.updateAuthState(with: user)
                self?.isLoading = false
            }
        }
    }
}

// MARK: - Validation Methods
extension AuthService {
    public func identifyLoginType(_ input: String) -> LoginType {
        if isValidEmail(input) {
            return .email
        } else if isValidUsername(input) {
            return .username
        } else if isValidPhoneNumber(input) {
            return .phone
        } else {
            return .unknown
        }
    }
    
    public func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    public func isValidUsername(_ username: String) -> Bool {
        let usernameRegEx = "^[a-zA-Z0-9.-]{3,30}$"
        let usernamePred = NSPredicate(format:"SELF MATCHES %@", usernameRegEx)
        return usernamePred.evaluate(with: username)
    }
    
    public func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Validación mejorada para números internacionales (E.164)
        let phoneRegEx = "^\\+?[1-9]\\d{1,14}$"
        let phonePred = NSPredicate(format:"SELF MATCHES %@", phoneRegEx)
        let cleanedNumber = phoneNumber.replacingOccurrences(
            of: "[^0-9+]",
            with: "",
            options: .regularExpression
        )
        return phonePred.evaluate(with: cleanedNumber) && cleanedNumber.count >= 8
    }
    
    public func meetsMinimumPasswordRequirements(_ password: String) -> Bool {
        let hasUpperCase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowerCase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasMinimumLength = password.count >= 8
        return hasUpperCase && hasLowerCase && hasMinimumLength
    }
}

// MARK: - Password Strength Evaluation
extension AuthService {
    public func evaluatePasswordStrength(_ password: String, email: String? = nil, username: String? = nil) -> PasswordStrength {
        var score = 0
        var feedback = [String]()
        
        // Longitud
        let length = password.count
        switch length {
        case 16...: score += 25; feedback.append("Longitud excelente (16+ caracteres)")
        case 12...15: score += 20; feedback.append("Longitud muy buena (12-15 caracteres)")
        case 10...11: score += 15; feedback.append("Longitud buena (10-11 caracteres)")
        case 8...9: score += 10; feedback.append("Longitud mínima alcanzada (8-9 caracteres)")
        default: score += 0; feedback.append("Longitud insuficiente (mínimo 8 caracteres)")
        }
        
        // Complejidad
        let hasUpperCase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowerCase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>/?")) != nil
        
        var complexityPoints = 0
        if hasUpperCase { complexityPoints += 2; feedback.append("✓ Incluye mayúsculas") }
        else { feedback.append("Agregar mayúsculas mejora la seguridad") }
        
        if hasLowerCase { complexityPoints += 2; feedback.append("✓ Incluye minúsculas") }
        else { feedback.append("Agregar minúsculas mejora la seguridad") }
        
        if hasNumbers { complexityPoints += 3; feedback.append("✓ Incluye números") }
        else { feedback.append("Agregar números mejora significativamente la seguridad") }
        
        if hasSpecialChars { complexityPoints += 4; feedback.append("✓ Incluye caracteres especiales") }
        else { feedback.append("Caracteres especiales (!@# etc.) maximizan la seguridad") }
        
        score += complexityPoints
        
        // Patrones comunes
        let commonPatterns = ["123", "abc", "password", "qwerty", "iloveyou", "111", "000"]
        for pattern in commonPatterns {
            if password.lowercased().contains(pattern) {
                feedback.append("⚠️ Contiene patrones comunes - considera cambiarlos")
                break
            }
        }
        
        // Información personal
        if let email = email, !email.isEmpty {
            let emailLocalPart = email.lowercased().components(separatedBy: "@").first ?? ""
            if !emailLocalPart.isEmpty && password.lowercased().contains(emailLocalPart) {
                feedback.append("💡 Evita usar partes de tu email para mayor seguridad")
            }
        }
        
        if let username = username, !username.isEmpty {
            if password.lowercased().contains(username.lowercased()) {
                feedback.append("💡 Evita usar tu nombre de usuario para mayor seguridad")
            }
        }
        
        // Secuencias
        if containsSequentialCharacters(password) {
            feedback.append("💡 Evita secuencias simples (abc, 123) para mayor seguridad")
        }
        
        // Clasificación final
        let strength: PasswordStrength.StrengthLevel
        switch score {
        case 35...:
            strength = .veryStrong
            feedback.insert("🎉 ¡Contraseña excelente! Cumple con estándares empresariales", at: 0)
        case 28..<35:
            strength = .strong
            feedback.insert("✅ Contraseña segura - adecuada para la mayoría de usos", at: 0)
        case 20..<28:
            strength = .medium
            feedback.insert("📊 Contraseña aceptable - considera mejoras para mayor seguridad", at: 0)
        case 12..<20:
            strength = .weak
            feedback.insert("🔒 Contraseña básica - cumple requisitos mínimos", at: 0)
        default:
            strength = .veryWeak
            feedback.insert("⚠️ Contraseña muy débil - recomendamos mejoras", at: 0)
        }
        
        return PasswordStrength(score: score, strength: strength, feedback: feedback)
    }
    
    private func containsSequentialCharacters(_ password: String) -> Bool {
        let sequentialPatterns = [
            "123", "234", "345", "456", "567", "678", "789",
            "abc", "bcd", "cde", "def", "efg", "fgh", "ghi", "hij", "ijk", "jkl", "klm", "lmn", "mno", "nop", "opq", "pqr", "qrs", "rst", "stu", "tuv", "uvw", "vwx", "wxy", "xyz"
        ]
        let lowercasedPassword = password.lowercased()
        return sequentialPatterns.contains { lowercasedPassword.contains($0) }
    }
}

// MARK: - Error Handling
extension AuthService {
    private func handleSignInError(_ error: Error) {
        let nsError = error as NSError
        let errorMessage: String
        
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            errorMessage = "Contraseña incorrecta"
        case AuthErrorCode.userNotFound.rawValue:
            errorMessage = "No existe una cuenta con este identificador"
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "El identificador no es válido"
        case AuthErrorCode.networkError.rawValue:
            errorMessage = "Error de conexión. Verifica tu conexión a internet"
        case AuthErrorCode.tooManyRequests.rawValue:
            errorMessage = "Demasiados intentos. Por favor, intenta más tarde"
        default:
            errorMessage = "Error al iniciar sesión: \(error.localizedDescription)"
        }
        
        handleAuthError(errorMessage)
    }
    
    private func handleSignUpError(_ error: Error) {
        let nsError = error as NSError
        let errorMessage: String
        
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            errorMessage = "Este email ya está en uso"
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "El email no es válido"
        case AuthErrorCode.weakPassword.rawValue:
            errorMessage = "La contraseña no cumple los requisitos mínimos de seguridad."
        case AuthErrorCode.networkError.rawValue:
            errorMessage = "Error de conexión. Verifica tu conexión a internet"
        default:
            errorMessage = "Error al registrar: \(error.localizedDescription)"
        }
        
        handleAuthError(errorMessage)
    }
    
    private func handlePhoneAuthError(_ error: Error) {
        let nsError = error as NSError
        let errorMessage: String
        
        switch nsError.code {
        case AuthErrorCode.sessionExpired.rawValue:
            errorMessage = "El código de verificación expiró. Por favor, solicita uno nuevo."
        case AuthErrorCode.invalidVerificationCode.rawValue:
            errorMessage = "Código de verificación inválido. Verifica que sea correcto."
        case AuthErrorCode.quotaExceeded.rawValue:
            errorMessage = "Demasiados intentos recientes. Por favor, espera unos minutos e intenta nuevamente."
        case AuthErrorCode.networkError.rawValue:
            errorMessage = "Error de conexión. Verifica tu conexión a internet."
        case AuthErrorCode.missingPhoneNumber.rawValue:
            errorMessage = "Por favor, ingresa un número de teléfono válido."
        default:
            errorMessage = "Error en autenticación por teléfono: \(error.localizedDescription)"
        }
        
        phoneAuthState = .error(errorMessage)
        handleAuthError(errorMessage)
    }
    
    public func handleAuthError(_ message: String) {
        print("[AuthService Error] \(message)")
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isLoading = false
        }
    }
}

// MARK: - User Management
extension AuthService {
    public func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            resetPhoneAuth()
            user = nil
            isAuthenticated = false
        } catch {
            handleAuthError("Error al cerrar sesión: \(error.localizedDescription)")
        }
    }
    
    private func updateAuthState(with firebaseUser: User?) {
        DispatchQueue.main.async {
            if let firebaseUser = firebaseUser {
                // Verificar si existe documento de usuario
                DatabaseService.shared.userDocumentExists(uid: firebaseUser.uid) { exists in
                    if !exists {
                        // Crear documento si no existe
                        DatabaseService.shared.createUserDocument(
                            uid: firebaseUser.uid,
                            name: firebaseUser.displayName,
                            email: firebaseUser.email,
                            photoURL: firebaseUser.photoURL,
                            username: self.extractUsernameFromName(firebaseUser.displayName)
                        )
                    } else {
                        // Actualizar último login
                        DatabaseService.shared.updateLastLogin(uid: firebaseUser.uid)
                    }
                }
                
                // Actualizar estado local
                self.user = AppUser(
                    uid: firebaseUser.uid,
                    email: firebaseUser.email,
                    name: firebaseUser.displayName,
                    username: self.extractUsernameFromName(firebaseUser.displayName),
                    phoneNumber: firebaseUser.phoneNumber,
                    photoURL: firebaseUser.photoURL
                )
                self.isAuthenticated = true
            } else {
                self.user = nil
                self.isAuthenticated = false
            }
            self.isLoading = false
        }
    }
    
    private func extractUsernameFromName(_ name: String?) -> String? {
        guard let name = name else { return nil }
        
        let username = name
            .lowercased()
            .replacingOccurrences(of: " ", with: ".")
            .components(separatedBy: .whitespaces)
            .joined()
        
        return username.count >= 3 ? username : nil
    }
    
    public func updateUserProfile(name: String? = nil, photoURL: URL? = nil, phoneNumber: String? = nil) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        DatabaseService.shared.updateUserDocument(
            uid: currentUser.uid,
            name: name,
            photoURL: photoURL
            // phoneNumber no se pasa para mantener compatibilidad
        )
        
        if let name = name {
            self.user = AppUser(
                uid: currentUser.uid,
                email: self.user?.email,
                name: name,
                username: self.extractUsernameFromName(name),
                phoneNumber: phoneNumber ?? self.user?.phoneNumber,
                photoURL: photoURL ?? self.user?.photoURL
            )
        }
    }
}
