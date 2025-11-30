//
//  PlantsView.swift
//  MyDiplom
//
//  Created on 20.11.2025.
//

import SwiftUI

// MARK: - Plants View (Справочник)
struct PlantsView: View {
    @State private var plantTypes: [PlantTypeOut] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Список растений
                if isLoading {
                    ProgressView("Загрузка растений...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Ошибка загрузки")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Повторить") {
                            loadPlantTypes()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if plantTypes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Нет растений")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(plantTypes) { plantType in
                                PlantRow(plantType: plantType)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Справочник")
            .task {
                loadPlantTypes()
            }
            .refreshable {
                await loadPlantTypesAsync()
            }
        }
    }
    
    private func loadPlantTypes() {
        Task {
            await loadPlantTypesAsync()
        }
    }
    
    private func loadPlantTypesAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let plants = try await APIService.shared.getPlantTypes()
            await MainActor.run {
                plantTypes = plants
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            print("❌ Ошибка загрузки растений: \(error)")
        }
    }
}

// MARK: - Plant Row
struct PlantRow: View {
    let plantType: PlantTypeOut
    
    var body: some View {
        HStack(spacing: 12) {
            // Изображение растения
            if let imageUrl = plantType.image_url,
               let url = APIService.shared.getFullImageURL(imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // Информация о растении
            VStack(alignment: .leading, spacing: 4) {
                Text(plantType.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = plantType.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Описание отсутствует")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

