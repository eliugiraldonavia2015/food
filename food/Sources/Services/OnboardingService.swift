//
//  OnboardingService.swift
//  food
//
//  Created by Gabriel Barzola arana on 10/11/25.
//

// Sources/Services/OnboardingService.swift
import FirebaseFirestore

public final class OnboardingService {
    public static let shared = OnboardingService()
    
    // ✅ Usa la misma instancia Firestore centralizada
    private let db = DatabaseService.shared.db
    private let usersCollection = "users"
    
    private init() {}
    
    /// Verifica si el usuario completó el onboarding
    public func hasCompletedOnboarding(
        uid: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection(usersCollection).document(uid).getDocument { snapshot, error in
            guard error == nil, let data = snapshot?.data() else {
                completion(false)
                return
            }
            completion(data["onboardingCompleted"] as? Bool ?? false)
        }
    }
    
    /// Marca el onboarding como completado
    public func markOnboardingAsCompleted(
        uid: String,
        completion: @escaping (Error?) -> Void
    ) {
        let updateData: [String: Any] = [
            "onboardingCompleted": true,
            "onboardingCompletedAt": Timestamp(date: Date())
        ]
        
        db.collection(usersCollection).document(uid).updateData(updateData, completion: completion)
    }
}
