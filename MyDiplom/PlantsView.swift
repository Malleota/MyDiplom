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
                        Image(systemName: "leaf")
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
                                NavigationLink(destination: PlantDetailView(plantType: plantType)) {
                                    PlantRow(plantType: plantType)
                                }
                                .buttonStyle(PlainButtonStyle())
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
                                Image(systemName: "leaf")
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
                        Image(systemName: "leaf")
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

// MARK: - Plant Detail View
struct PlantDetailView: View {
    let plantType: PlantTypeOut
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок: Название и описание с картинкой
                HStack(alignment: .top, spacing: 12) {
                    // Вертикальный контейнер с названием и описанием
                    VStack(alignment: .leading, spacing: 0) {
                        Text(plantType.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let description = plantType.description, !description.isEmpty {
                            Text(description)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Картинка справа
                    if let imageUrl = plantType.image_url,
                       let url = APIService.shared.getFullImageURL(imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "leaf")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            )
                    }
                }
                .padding(8)
                .padding(.horizontal)
                
                // Условия содержания
                VStack(alignment: .leading, spacing: 16) {
                    Text("Условия содержания")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Две карточки: температура и влажность
                    HStack(spacing: 12) {
                        // Карточка температуры
                        if let tempMin = plantType.temp_min, let tempMax = plantType.temp_max {
                            InfoRow(
                                icon: "thermometer",
                                title: "Температура",
                                value: "\(String(format: "%.1f", tempMin))°C - \(String(format: "%.1f", tempMax))°C"
                            )
                        }
                        
                        // Карточка влажности
                        if let humMin = plantType.humidity_min, let humMax = plantType.humidity_max {
                            InfoRow(
                                icon: "drop",
                                title: "Влажность",
                                value: "\(String(format: "%.0f", humMin))% - \(String(format: "%.0f", humMax))%"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Интервалы полива и удобрения
                    if plantType.watering_interval_days != nil || plantType.fertilizing_interval_days != nil {
                        HStack(spacing: 12) {
                            // Интервал полива
                            if let wateringInterval = plantType.watering_interval_days {
                                InfoRow(
                                    icon: "drop",
                                    title: "Интервал полива",
                                    value: "\(wateringInterval) \(dayText(wateringInterval))"
                                )
                            }
                            
                            // Интервал удобрения
                            if let fertilizingInterval = plantType.fertilizing_interval_days {
                                InfoRow(
                                    icon: "leaf",
                                    title: "Интервал удобрения",
                                    value: "\(fertilizingInterval) \(dayText(fertilizingInterval))"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(plantType.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func dayText(_ days: Int) -> String {
        let lastDigit = days % 10
        let lastTwoDigits = days % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
            return "дней"
        } else if lastDigit == 1 {
            return "день"
        } else if lastDigit >= 2 && lastDigit <= 4 {
            return "дня"
        } else {
            return "дней"
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
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
    }
}

