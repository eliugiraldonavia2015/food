import FirebaseFirestore
import FirebaseAuth
import Foundation

public final class DatabaseService {
    public static let shared = DatabaseService()
    
    // ✅ ACTUALIZADO: Configurar para usar 'logincloud'
    private let db: Firestore
    
    private let usersCollection = "users"
    
    private init() {
        // Inicializar Firestore
        self.db = Firestore.firestore()
        
        // Configurar para usar la base de datos específica
        let settings = db.settings
        // Para Firebase v9+ usa esta configuración
        settings.host = "firestore.googleapis.com/v1/projects/toctoc-1e18c/databases/logincloud"
        db.settings = settings
        
        setupFirestore()
    }
    
    private func setupFirestore() {
        // Configuración adicional si es necesaria
        print("[Database] Configured for database: logincloud")
    }
    
    // MARK: - Crear documento de usuario
    public func createUserDocument(
        uid: String,
        name: String?,
        email: String?,
        photoURL: URL? = nil
    ) {
        let userData: [String: Any] = [
            "uid": uid,
            "email": email ?? "",
            "name": name ?? "",
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
        photoURL: URL? = nil
    ) {
        var updateData: [String: Any] = [:]
        
        if let name = name {
            updateData["name"] = name
        }
        
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL.absoluteString
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
    
    // MARK: - Observar cambios del usuario (para perfiles en tiempo real)
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
    
    // MARK: - Eliminar usuario (para funcionalidad de borrar cuenta)
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
