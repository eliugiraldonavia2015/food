// food/food/Sources/Services/DatabaseService.swift
import FirebaseFirestore
import FirebaseAuth
import Foundation

public final class DatabaseService {
    public static let shared = DatabaseService()
    
    private let db: Firestore
    private let usersCollection = "users"
    
    private init() {
        // ✅ CORRECCIÓN: Especificar la misma base de datos
        self.db = Firestore.firestore(database: "logincloud")
        
        // ✅ CORRECCIÓN: Configuración correcta del host
        let settings = db.settings
        settings.host = "firestore.googleapis.com"
        db.settings = settings
        
        setupFirestore()
    }
    
    private func setupFirestore() {
        print("[Database] Configured for database: logincloud")
    }
    
    // MARK: - Crear documento de usuario
    public func createUserDocument(
        uid: String,
        name: String?,
        email: String?,
        photoURL: URL? = nil,
        username: String? = nil
    ) {
        let userData: [String: Any] = [
            "uid": uid,
            "email": email ?? "",
            "name": name ?? "",
            "username": username ?? "",
            "createdAt": Timestamp(date: Date()),
            "lastLogin": Timestamp(date: Date()),
            "photoURL": photoURL?.absoluteString ?? "",
            "isPremium": false,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        db.collection(usersCollection).document(uid).setData(userData) { error in
            if let error = error {
                print("[Database] Error creating user document: \(error.localizedDescription)")
            } else {
                print("[Database] User document created successfully for \(uid)")
            }
        }
    }
    
    // MARK: - Obtener email por username
    public func getEmailForUsername(username: String, completion: @escaping (String?) -> Void) {
        let query = db.collection(usersCollection).whereField("username", isEqualTo: username)
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("[Database] Error checking username: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = snapshot?.documents.first else {
                completion(nil)
                return
            }
            
            completion(document.get("email") as? String)
        }
    }
    
    // MARK: - Verificar disponibilidad de username
    public func isUsernameAvailable(_ username: String, completion: @escaping (Bool) -> Void) {
        let query = db.collection(usersCollection).whereField("username", isEqualTo: username)
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("[Database] Error checking username: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(snapshot?.isEmpty ?? true)
        }
    }
    
    // MARK: - Actualizar último login
    public func updateLastLogin(uid: String) {
        let updateData: [String: Any] = [
            "lastLogin": Timestamp(date: Date())
        ]
        
        db.collection(usersCollection).document(uid).updateData(updateData) { error in
            if let error = error {
                print("[Database] Error updating last login: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actualizar información del usuario
    public func updateUserDocument(
        uid: String,
        name: String? = nil,
        photoURL: URL? = nil,
        username: String? = nil
    ) {
        var updateData: [String: Any] = [:]
        
        if let name = name {
            updateData["name"] = name
        }
        
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL.absoluteString
        }
        
        if let username = username {
            updateData["username"] = username
        }
        
        updateData["lastUpdated"] = Timestamp(date: Date())
        
        guard !updateData.isEmpty else { return }
        
        db.collection(usersCollection).document(uid).updateData(updateData) { error in
            if let error = error {
                print("[Database] Error updating user: \(error.localizedDescription)")
            } else {
                print("[Database] User updated successfully")
            }
        }
    }
    
    // MARK: - Obtener información del usuario
    public func fetchUser(
        uid: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        db.collection(usersCollection).document(uid).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.failure(NSError(domain: "Database", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
                return
            }
            
            completion(.success(document.data() ?? [:]))
        }
    }
    
    // MARK: - Observar cambios del usuario
    public func observeUser(
        uid: String,
        handler: @escaping (Result<[String: Any], Error>) -> Void
    ) -> ListenerRegistration {
        return db.collection(usersCollection).document(uid).addSnapshotListener { snapshot, error in
            if let error = error {
                handler(.failure(error))
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                handler(.failure(NSError(domain: "Database", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
                return
            }
            
            handler(.success(snapshot.data() ?? [:]))
        }
    }
    
    // MARK: - Verificar si existe documento de usuario
    public func userDocumentExists(uid: String, completion: @escaping (Bool) -> Void) {
        db.collection(usersCollection).document(uid).getDocument { document, error in
            if let error = error {
                print("[Database] Error checking user document: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(document?.exists ?? false)
        }
    }
    
    // MARK: - Eliminar usuario
    public func deleteUserDocument(uid: String, completion: @escaping (Error?) -> Void) {
        db.collection(usersCollection).document(uid).delete { error in
            if let error = error {
                print("[Database] Error deleting user document: \(error.localizedDescription)")
            } else {
                print("[Database] User document deleted successfully")
            }
            completion(error)
        }
    }
}
