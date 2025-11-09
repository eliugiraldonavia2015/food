// food/food/Sources/Services/AuthService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Combine

// MARK: - Password Strength Domain Model
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
        
        // ✅ CORRECCIÓN: Sin dependencias de UI - solo datos
        public var colorIdentifier: String {
            switch self {
            case .veryWeak, .weak: return "red"
            case .medium: return "orange"
            case .strong, .veryStrong: return "green"
            }
        }
        
        // ✅ CORRECCIÓN: Usar Double nativo en lugar de CGFloat
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

// MARK: - User Domain Model
public struct AppUser: Identifiable {
    public let id = UUID()
    public let uid: String
    public let email: String?
    public let name: String?
    public let username: String?
    public let photoURL: URL?
    
    public init(
        uid: String,
        email: String?,
        name: String?,
        username: String? = nil,
        photoURL: URL?
    ) {
        self.uid = uid
        self.email = email
        self.name = name
        self.username = username
        self.photoURL = photoURL
    }
}

// MARK: - Authentication Service
public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public private(set) var user: AppUser?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    
    private let firestore = Firestore.firestore(database: "logincloud")
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        let settings = firestore.settings
        settings.host = "firestore.googleapis.com"
        firestore.settings = settings
        
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            DispatchQueue.main.async {
                self?.updateAuthState(with: firebaseUser)
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Password Validation
    public func meetsMinimumPasswordRequirements(_ password: String) -> Bool {
        let hasUpperCase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowerCase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasMinimumLength = password.count >= 8
        
        return hasUpperCase && hasLowerCase && hasMinimumLength
    }
    
    // MARK: - Authentication Methods
    public func signInWithGoogle(presentingVC: UIViewController) {
        isLoading = true
        errorMessage = nil
        
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingVC
        ) { [weak self] signInResult, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleAuthError("Google Error: \(error.localizedDescription)")
                return
            }
            
            guard let signInResult = signInResult else {
                self.handleAuthError("Google response is empty")
                return
            }
            
            guard let idToken = signInResult.user.idToken?.tokenString else {
                self.handleAuthError("Invalid Google ID token")
                return
            }
            
            let accessToken = signInResult.user.accessToken.tokenString
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            
            Auth.auth().signIn(with: credential) { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.handleAuthError("Firebase Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Email/Username Sign-In (ETAPA 5)
    public func signInWithEmailOrUsername(identifier: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Determinar si es email o username
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
    
    public func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleSignInError(error)
                }
            }
        }
    }
    
    // MARK: - Email/Username Detection (ETAPA 5)
    public func identifyLoginType(_ input: String) -> LoginType {
        if isValidEmail(input) {
            return .email
        } else if isValidUsername(input) {
            return .username
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
        // Permite letras, números, guiones y puntos (3-30 caracteres)
        let usernameRegEx = "^[a-zA-Z0-9.-]{3,30}$"
        let usernamePred = NSPredicate(format:"SELF MATCHES %@", usernameRegEx)
        return usernamePred.evaluate(with: username)
    }
    
    // MARK: - User Management
    public enum LoginType {
        case email
        case username
        case unknown
    }
    
    public func signUpWithEmail(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        username: String
    ) {
        isLoading = true
        errorMessage = nil
        
        // ✅ SOLO validamos requisitos mínimos, no fortaleza
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
                
                guard let user = result?.user else { return }
                
                let fullName = "\(firstName) \(lastName)"
                
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = fullName
                changeRequest.commitChanges { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Profile update error: \(error)")
                        }
                        
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
    }
    
    // MARK: - Password Strength Evaluation
    public func evaluatePasswordStrength(_ password: String, email: String? = nil, username: String? = nil) -> PasswordStrength {
        var score = 0
        var feedback = [String]()
        
        // Longitud (Peso principal)
        let length = password.count
        if length >= 16 {
            score += 25
            feedback.append("Longitud excelente (16+ caracteres)")
        } else if length >= 12 {
            score += 20
            feedback.append("Longitud muy buena (12-15 caracteres)")
        } else if length >= 10 {
            score += 15
            feedback.append("Longitud buena (10-11 caracteres)")
        } else if length >= 8 {
            score += 10
            feedback.append("Longitud mínima alcanzada (8-9 caracteres)")
        } else {
            score += 0
            feedback.append("Longitud insuficiente (mínimo 8 caracteres)")
        }
        
        // Complejidad
        let hasUpperCase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowerCase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>/?")) != nil
        
        var complexityPoints = 0
        if hasUpperCase {
            complexityPoints += 2
            feedback.append("✓ Incluye mayúsculas")
        } else {
            feedback.append("Agregar mayúsculas mejora la seguridad")
        }
        
        if hasLowerCase {
            complexityPoints += 2
            feedback.append("✓ Incluye minúsculas")
        } else {
            feedback.append("Agregar minúsculas mejora la seguridad")
        }
        
        if hasNumbers {
            complexityPoints += 3
            feedback.append("✓ Incluye números")
        } else {
            feedback.append("Agregar números mejora significativamente la seguridad")
        }
        
        if hasSpecialChars {
            complexityPoints += 4
            feedback.append("✓ Incluye caracteres especiales")
        } else {
            feedback.append("Caracteres especiales (!@# etc.) maximizan la seguridad")
        }
        
        score += complexityPoints
        
        // Patrones comunes (solo feedback)
        let commonPatterns = ["123", "abc", "password", "qwerty", "iloveyou", "111", "000"]
        for pattern in commonPatterns {
            if password.lowercased().contains(pattern) {
                feedback.append("⚠️ Contiene patrones comunes - considera cambiarlos")
                break
            }
        }
        
        // Información personal (solo feedback)
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
        
        // Secuencias (solo feedback)
        if containsSequentialCharacters(password) {
            feedback.append("💡 Evita secuencias simples (abc, 123) para mayor seguridad")
        }
        
        // Clasificación
        let strength: PasswordStrength.StrengthLevel
        if score >= 35 {
            strength = .veryStrong
            feedback.insert("🎉 ¡Contraseña excelente! Cumple con estándares empresariales", at: 0)
        } else if score >= 28 {
            strength = .strong
            feedback.insert("✅ Contraseña segura - adecuada para la mayoría de usos", at: 0)
        } else if score >= 20 {
            strength = .medium
            feedback.insert("📊 Contraseña aceptable - considera mejoras para mayor seguridad", at: 0)
        } else if score >= 12 {
            strength = .weak
            feedback.insert("🔒 Contraseña básica - cumple requisitos mínimos", at: 0)
        } else {
            strength = .veryWeak
            feedback.insert("⚠️ Contraseña muy débil - recomendamos mejoras", at: 0)
        }
        
        return PasswordStrength(
            score: score,
            strength: strength,
            feedback: feedback
        )
    }
    
    // MARK: - Helper Methods
    private func containsSequentialCharacters(_ password: String) -> Bool {
        let sequentialPatterns = [
            "123", "234", "345", "456", "567", "678", "789",
            "abc", "bcd", "cde", "def", "efg", "fgh", "ghi", "hij", "ijk", "jkl", "klm", "lmn", "mno", "nop", "opq", "pqr", "qrs", "rst", "stu", "tuv", "uvw", "vwx", "wxy", "xyz"
        ]
        
        let lowercasedPassword = password.lowercased()
        return sequentialPatterns.contains { lowercasedPassword.contains($0) }
    }
    
    // MARK: - Error Handling
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
    
    // MARK: - Common Methods
    public func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            handleAuthError("Sign out failed: \(error.localizedDescription)")
        }
    }
    
    private func updateAuthState(with firebaseUser: User?) {
        DispatchQueue.main.async {
            if let firebaseUser = firebaseUser {
                DatabaseService.shared.userDocumentExists(uid: firebaseUser.uid) { exists in
                    if !exists {
                        DatabaseService.shared.createUserDocument(
                            uid: firebaseUser.uid,
                            name: firebaseUser.displayName,
                            email: firebaseUser.email,
                            photoURL: firebaseUser.photoURL,
                            username: self.extractUsernameFromName(firebaseUser.displayName)
                        )
                    } else {
                        DatabaseService.shared.updateLastLogin(uid: firebaseUser.uid)
                    }
                }
                
                self.user = AppUser(
                    uid: firebaseUser.uid,
                    email: firebaseUser.email,
                    name: firebaseUser.displayName,
                    username: self.extractUsernameFromName(firebaseUser.displayName),
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
    
    public func handleAuthError(_ message: String) {
        print("[Auth Error] \(message)")
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isLoading = false
        }
    }
    
    // MARK: - User Management
    public func updateUserProfile(name: String? = nil, photoURL: URL? = nil) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        DatabaseService.shared.updateUserDocument(
            uid: currentUser.uid,
            name: name,
            photoURL: photoURL
        )
        
        if let name = name {
            self.user = AppUser(
                uid: currentUser.uid,
                email: self.user?.email,
                name: name,
                username: self.extractUsernameFromName(name),
                photoURL: photoURL ?? self.user?.photoURL
            )
        }
    }
}
