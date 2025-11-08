// food/food/Sources/Services/AuthService.swift
import Foundation
import FirebaseAuth
import GoogleSignIn
import UIKit
import Combine

public struct AppUser: Identifiable {
    public let id = UUID()
    public let uid: String
    public let email: String?
    public let name: String?
    public let photoURL: URL?
    
    public init(
        uid: String,
        email: String?,
        name: String?,
        photoURL: URL?
    ) {
        self.uid = uid
        self.email = email
        self.name = name
        self.photoURL = photoURL
    }
}

public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public private(set) var user: AppUser?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
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
            
            // ✅ CORRECCIÓN: Extraer tokens correctamente
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
                    self?.isLoading = false
                    if let error = error {
                        self?.handleAuthError("Firebase Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    public func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            handleAuthError("Sign out failed: \(error.localizedDescription)")
        }
    }
    
    // ✅ CORRECCIÓN MEJORADA: Integración inteligente con DatabaseService
    private func updateAuthState(with firebaseUser: User?) {
        DispatchQueue.main.async {
            if let firebaseUser = firebaseUser {
                // ✅ INTEGRACIÓN INTELIGENTE: Verificar si existe antes de crear
                DatabaseService.shared.userDocumentExists(uid: firebaseUser.uid) { exists in
                    if !exists {
                        // Crear documento solo si no existe
                        DatabaseService.shared.createUserDocument(
                            uid: firebaseUser.uid,
                            name: firebaseUser.displayName,
                            email: firebaseUser.email,
                            photoURL: firebaseUser.photoURL
                        )
                    } else {
                        // Solo actualizar último login si ya existe
                        DatabaseService.shared.updateLastLogin(uid: firebaseUser.uid)
                    }
                }
                
                self.user = AppUser(
                    uid: firebaseUser.uid,
                    email: firebaseUser.email,
                    name: firebaseUser.displayName,
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
    
    // ✅ CORRECCIÓN: Cambiar a internal/public para que las vistas puedan usarlo
    public func handleAuthError(_ message: String) {
        print("[Auth Error] \(message)")
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isLoading = false
        }
    }
    
    // MARK: - Métodos adicionales para gestión de usuario
    public func updateUserProfile(name: String? = nil, photoURL: URL? = nil) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Actualizar en DatabaseService
        DatabaseService.shared.updateUserDocument(
            uid: currentUser.uid,
            name: name,
            photoURL: photoURL
        )
        
        // Actualizar localmente si es necesario
        if let name = name {
            self.user = AppUser(
                uid: currentUser.uid,
                email: self.user?.email,
                name: name,
                photoURL: photoURL ?? self.user?.photoURL
            )
        }
    }
}
