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

// MARK: - Greenhouse Detail View

struct GreenhouseDetailView: View {
    let greenhouseId: String
    @State private var greenhouse: GreenhouseOut?
    @State private var sensorData: SensorDataOut?
    @State private var isLoading = true
    @State private var showConnectSensor = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Загрузка...")
            } else if let greenhouse = greenhouse {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Заголовок: Название и описание с картинкой
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let description = greenhouse.description {
                                    Text(description)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Картинка справа
                            if let imageUrl = greenhouse.image_url, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "building.2.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 40))
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Блок "Текущие данные"
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Текущие данные")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if let sensorId = greenhouse.sensor_id, let sensor = sensorData {
                                // Датчик подключен
                                VStack(spacing: 16) {
                                    // Название датчика и батарея
                                    HStack {
                                        Text(sensor.ble_identifier ?? "Датчик")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        if let battery = sensor.battery_percent {
                                            HStack(spacing: 4) {
                                                Image(systemName: "battery.100")
                                                    .foregroundColor(batteryColor(battery))
                                                Text("\(battery)%")
                                                    .font(.subheadline)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    // Две карточки: температура и влажность
                                    HStack(spacing: 12) {
                                        // Карточка температуры
                                        if let temp = sensor.last_temperature {
                                            SensorDataCard(
                                                icon: "thermometer",
                                                title: "Температура",
                                                value: String(format: "%.1f", temp),
                                                unit: "°C"
                                            )
                                        }
                                        
                                        // Карточка влажности
                                        if let hum = sensor.last_humidity {
                                            SensorDataCard(
                                                icon: "drop.fill",
                                                title: "Влажность",
                                                value: String(format: "%.0f", hum),
                                                unit: "%"
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                // Датчик не подключен
                                VStack(spacing: 16) {
                                    Text("Нет подключенных датчиков")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        showConnectSensor = true
                                    }) {
                                        Text("Подключить")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            } else {
                Text("Теплица не найдена")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(greenhouse?.name ?? "Теплица")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showConnectSensor) {
            ConnectSensorView(greenhouseId: greenhouseId)
        }
        .task {
            await loadGreenhouse()
        }
    }
    
    private func batteryColor(_ percent: Int) -> Color {
        if percent > 50 {
            return .green
        } else if percent > 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func loadGreenhouse() async {
        do {
            let fetched = try await APIService.shared.getGreenhouse(id: greenhouseId)
            await MainActor.run {
                greenhouse = fetched
            }
            
            // Загружаем данные датчика, если он подключен
            if let sensorId = fetched.sensor_id {
                if let sensor = try? await APIService.shared.getSensorData(sensorId: sensorId) {
                    await MainActor.run {
                        sensorData = sensor
                    }
                }
            }
            
            await MainActor.run {
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

// MARK: - Sensor Data Card

struct SensorDataCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Connect Sensor View (Placeholder)

struct ConnectSensorView: View {
    let greenhouseId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Подключение датчика")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Здесь будет форма подключения датчика")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Подключить датчик")
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

