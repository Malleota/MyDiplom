//
//  GreenhouseViews.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI
import Combine

// MARK: - Greenhouse List View

struct GreenhouseListView: View {
    @StateObject private var viewModel = GreenhouseListViewModel()
    @State private var showCreateGreenhouse = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Загрузка...")
                } else if viewModel.greenhouses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Нет теплиц")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Нажмите + чтобы создать первую теплицу")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.greenhouses) { greenhouse in
                                NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouse.id)) {
                                    GreenhouseCardView(greenhouse: greenhouse, sensorData: viewModel.sensorData[greenhouse.sensor_id ?? ""])
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Теплицы")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCreateGreenhouse = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateGreenhouse) {
                CreateGreenhouseView()
            }
            .task {
                await viewModel.loadGreenhouses()
            }
            .refreshable {
                await viewModel.loadGreenhouses()
            }
        }
    }
}

// MARK: - Greenhouse Card View

struct GreenhouseCardView: View {
    let greenhouse: GreenhouseOut
    let sensorData: SensorDataOut?
    
    var body: some View {
        HStack(spacing: 16) {
            // Изображение теплицы
            if let imageUrl = greenhouse.image_url, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // Информация о теплице
            VStack(alignment: .leading, spacing: 8) {
                Text(greenhouse.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Краткая сводка
                VStack(alignment: .leading, spacing: 4) {
                    if let sensor = sensorData,
                       let temp = sensor.last_temperature,
                       let hum = sensor.last_humidity {
                        // Есть данные с датчика
                        HStack(spacing: 12) {
                            Label(String(format: "%.1f°C", temp), systemImage: "thermometer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Label(String(format: "%.0f%%", hum), systemImage: "humidity")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Время до следующего полива (заглушка)
                    Label("Полив через 2 дня", systemImage: "drop.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Greenhouse List ViewModel

@MainActor
class GreenhouseListViewModel: ObservableObject {
    @Published var greenhouses: [GreenhouseOut] = []
    @Published var sensorData: [String: SensorDataOut] = [:]
    @Published var isLoading = false
    
    func loadGreenhouses() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedGreenhouses = try await APIService.shared.getGreenhouses()
            greenhouses = fetchedGreenhouses
            
            // Загружаем данные датчиков для теплиц, у которых есть sensor_id
            for greenhouse in fetchedGreenhouses {
                if let sensorId = greenhouse.sensor_id {
                    if let data = try? await APIService.shared.getSensorData(sensorId: sensorId) {
                        sensorData[sensorId] = data
                    }
                }
            }
        } catch {
            print("Ошибка загрузки теплиц: \(error)")
        }
    }
}

// MARK: - Create Greenhouse View (Placeholder)

struct CreateGreenhouseView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Создание теплицы")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Здесь будет форма создания теплицы")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Новая теплица")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Greenhouse Detail View (Placeholder)

struct GreenhouseDetailView: View {
    let greenhouseId: String
    @State private var greenhouse: GreenhouseOut?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Загрузка...")
            } else if let greenhouse = greenhouse {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Изображение
                        if let imageUrl = greenhouse.image_url, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Название
                        Text(greenhouse.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        // Описание
                        if let description = greenhouse.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Здесь будет детальная информация о теплице")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                    .padding()
                }
            } else {
                Text("Теплица не найдена")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(greenhouse?.name ?? "Теплица")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadGreenhouse()
        }
    }
    
    private func loadGreenhouse() async {
        do {
            let fetched = try await APIService.shared.getGreenhouse(id: greenhouseId)
            await MainActor.run {
                greenhouse = fetched
                isLoading = false
            }
        } catch {
            print("Ошибка загрузки теплицы: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

