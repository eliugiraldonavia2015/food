//
//  ProfilePictureSetupView.swift
//  food
//
//  Created by Gabriel Barzola arana on 10/11/25.
//

// Sources/Views/Onboarding/ProfilePictureSetupView.swift
import SwiftUI
import PhotosUI
import UIKit

struct ProfilePictureSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Agrega una foto de perfil")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Ayuda a que otros te reconozcan más fácilmente")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 📸 Imagen de perfil seleccionada o placeholder
            Button {
                showImagePicker = true
            } label: {
                Group {
                    if let image = viewModel.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 120))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 140, height: 140)
                .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                .shadow(radius: 3)
            }
            .padding(.top, 10)
            .photosPicker(isPresented: $showImagePicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                if let newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                viewModel.profileImage = uiImage
                            }
                        }
                    }
                }
            }
            
            // Botón continuar
            Button {
                viewModel.nextStep()
            } label: {
                Text("Continuar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal)
            
            // Botón para saltar
            Button("Saltar este paso") {
                viewModel.nextStep()
            }
            .font(.footnote)
            .foregroundColor(.blue)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Foto de perfil")
        .navigationBarTitleDisplayMode(.inline)
    }
}
