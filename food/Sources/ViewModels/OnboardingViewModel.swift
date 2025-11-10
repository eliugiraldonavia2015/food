//
//  OnboardingViewModel.swift
//  food
//
//  Created by Gabriel Barzola arana on 10/11/25.
//

// Sources/ViewModels/OnboardingViewModel.swift
import Combine
import UIKit
import FirebaseAuth

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public private(set) var currentStep: Step = .welcome
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    
    public var interests: [InterestOption] = [
        .init(name: "Comida rápida", isSelected: false),
        .init(name: "Saludable", isSelected: false),
        .init(name: "Postres", isSelected: false),
        .init(name: "Bebidas", isSelected: false),
        .init(name: "Internacional", isSelected: false),
        .init(name: "Local", isSelected: false)
    ]
    
    @Published public var profileImage: UIImage?
    
    private let service = OnboardingService.shared
    private let auth = AuthService.shared
    private let storage = StorageService.shared
    
    public enum Step {
        case welcome
        case photo
        case interests
        case done
    }
    
    public struct InterestOption: Identifiable, Equatable {
        public let id = UUID()
        public let name: String
        public var isSelected: Bool
    }
    
    // MARK: - Public API
    public func startFlow() async {
        guard let user = auth.user else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let completed: Bool = try await withCheckedThrowingContinuation { continuation in
                service.hasCompletedOnboarding(uid: user.uid) { result in
                    continuation.resume(returning: result)
                }
            }
            
            if !completed {
                currentStep = .welcome
            }
        } catch {
            print("[OnboardingVM] Error checking status: \(error)")
        }
    }
    
    public func nextStep() {
        switch currentStep {
        case .welcome: currentStep = .photo
        case .photo: currentStep = .interests
        case .interests: Task { await finishOnboarding() }
        case .done: break
        }
    }
    
    public func skipOnboarding() {
        Task { await finishOnboarding() }
    }
    
    // MARK: - Public Navigation Control
    public func goBack() {
        switch currentStep {
        case .photo:
            currentStep = .welcome
        case .interests:
            currentStep = .photo
        default:
            break
        }
    }

    
    // MARK: - Private Implementation
    private func finishOnboarding() async {
        guard let user = auth.user else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var uploadedPhotoURL: URL?
            
            // 1️⃣ Subir foto si existe
            if let image = profileImage {
                uploadedPhotoURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    storage.uploadProfileImage(uid: user.uid, image: image) { result in
                        switch result {
                        case .success(let url):
                            continuation.resume(returning: url)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                // Actualizar el perfil en Firebase Auth
                if let url = uploadedPhotoURL {
                    let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                    changeRequest?.photoURL = url
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        changeRequest?.commitChanges { error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                    }
                }
            }
            
            // 2️⃣ Guardar intereses
            if !selectedInterests.isEmpty {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DatabaseService.shared.updateUserInterests(
                        uid: user.uid,
                        interests: selectedInterests
                    ) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            }
            
            // 3️⃣ Marcar onboarding como completado
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                service.markOnboardingAsCompleted(uid: user.uid) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            // 4️⃣ Actualizar estado local
            await MainActor.run {
                currentStep = .done
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // ✅ Cambiado de private a internal/public en AuthService
                    self.auth.refreshAuthState()
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Error guardando datos. Continúa usando la app normalmente."
                print("[OnboardingVM] \(error)")
            }
        }
    }
    
    private var selectedInterests: [String] {
        interests.compactMap { $0.isSelected ? $0.name : nil }
    }
}
