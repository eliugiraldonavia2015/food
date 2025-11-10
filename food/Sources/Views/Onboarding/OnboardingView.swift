//
//  OnboardingView.swift
//  food
//
//  Created by Gabriel Barzola arana on 10/11/25.
//

// Sources/Views/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    var onCompletion: () -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    welcomeView
                case .photo:
                    ProfilePictureSetupView(viewModel: viewModel)
                case .interests:
                    InterestSelectionView(viewModel: viewModel)
                case .done:
                    doneView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.currentStep != .done {
                        Button("Saltar") {
                            viewModel.skipOnboarding()
                        }
                        .tint(.orange)
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .overlay(loadingOverlay)
            .task {
                // 🔹 Inicia el flujo de onboarding solo una vez
                await viewModel.startFlow()
            }
            .onChange(of: viewModel.currentStep) { _, step in
                if step == .done {
                    // 🔹 Le damos tiempo al ViewModel para completar guardado y refresh
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        onCompletion()
                    }
                }
            }
            .animation(.easeInOut, value: viewModel.currentStep)
        }
    }
    
    // MARK: - Step: Welcome
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 100))
                .foregroundColor(.orange)
                .symbolEffect(.bounce, options: .repeat(3), value: true)
            
            Text("¡Bienvenido a Food!")
                .font(.largeTitle.bold())
            
            Text("Completa estos pasos rápidos para personalizar tu experiencia.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: {
                viewModel.nextStep()
            }) {
                Text("Comenzar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal)
        }
        .padding()
        .navigationBarHidden(true)
    }
    
    // MARK: - Step: Done
    private var doneView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
                .symbolEffect(.bounce, options: .repeat(2), value: true)
            
            Text("¡Listo!")
                .font(.largeTitle.bold())
            
            Text("Tu cuenta está lista. Ahora puedes explorar la app.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding()
        .navigationBarHidden(true)
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView("Guardando...")
                            .progressViewStyle(.circular)
                            .tint(.orange)
                            .scaleEffect(1.3)
                        Text("Por favor espera...")
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.isLoading)
    }
}
