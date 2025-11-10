//
//  InterestSelectionView.swift
//  food
//
//  Created by Gabriel Barzola arana on 10/11/25.
//

import SwiftUI

// Sources/Views/Onboarding/InterestSelectionView.swift
struct InterestSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Título
            Text("¿Qué tipo de comida te interesa?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            Text("Esto nos ayudará a personalizar tu experiencia en Food 🍽️")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Lista de intereses
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach($viewModel.interests) { $option in
                        Button {
                            option.isSelected.toggle()
                        } label: {
                            HStack {
                                if option.isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                }
                                Text(option.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(option.isSelected ? .white : .primary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(option.isSelected ? Color.orange : Color.gray.opacity(0.1))
                            )
                            .animation(.easeInOut(duration: 0.15), value: option.isSelected)
                        }
                        .buttonStyle(.plain)
                        .shadow(color: option.isSelected ? .orange.opacity(0.3) : .clear, radius: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            Spacer()
            
            // Controles inferiores
            HStack {
                Button(action: { viewModel.goBack() }) {
                    Label("Atrás", systemImage: "chevron.left")
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { viewModel.nextStep() }) {
                    Text("Finalizar")
                        .fontWeight(.bold)
                        .padding(.horizontal)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.interests.allSatisfy { !$0.isSelected })
            }
            .padding(.horizontal)
        }
        .padding(.top)
        .navigationTitle("Intereses")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: viewModel.interests)
    }
}
