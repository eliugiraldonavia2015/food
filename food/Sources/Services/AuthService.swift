import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Combine

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

public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public private(set) var user: AppUser?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    
    // ✅ CORRECCIÓN: Especificar la misma base de datos
    private let firestore = Firestore.firestore(database: "logincloud")
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        // ✅ CORRECCIÓN: Configuración correcta del host
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
    
    // MARK: - Google Sign-In
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
    
    // MARK: - Email/Password Sign-In
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
    
    // MARK: - Email/Password Sign-Up
    public func signUpWithEmail(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        username: String
    ) {
        isLoading = true
        errorMessage = nil
        
        guard isPasswordValid(password) else {
            handleAuthError("La contraseña debe tener al menos 8 caracteres, una mayúscula y una minúscula")
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
    
    private func isPasswordValid(_ password: String) -> Bool {
        return password.count >= 8 &&
               password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
               password.rangeOfCharacter(from: .lowercaseLetters) != nil
    }
    
    // MARK: - Error Handling
    private func handleSignInError(_ error: Error) {
        let nsError = error as NSError
        let errorMessage: String
        
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            errorMessage = "Contraseña incorrecta"
        case AuthErrorCode.userNotFound.rawValue:
            errorMessage = "No existe una cuenta con este email"
        case AuthErrorCode.invalidEmail.rawValue:
            errorMessage = "El email no es válido"
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
            errorMessage = "La contraseña debe tener al menos 8 caracteres, una mayúscula y una minúscula"
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
