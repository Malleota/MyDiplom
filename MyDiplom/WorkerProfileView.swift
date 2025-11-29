//
//  WorkerProfileView.swift
//  MyDiplom
//
//  Created on 20.11.2025.
//

import SwiftUI

struct WorkerProfileView: View {
    let user: UserOut
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @State private var greenhouses: [GreenhouseOut] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isAdmin: Bool {
        user.role == "admin"
    }
    
    var roleText: String {
        user.role == "admin" ? "Администратор" : "Рабочий"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок: Аватарка, имя и должность
                HStack(alignment: .top, spacing: 12) {
                    // Вертикальный контейнер с именем и должностью
                    VStack(alignment: .leading, spacing: 0) {
                        Text(user.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(roleText)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        // Email
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Аватарка справа
                    if let avatarUrl = user.avatar_url, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 32))
                            )
                    }
                }
                .padding(8)
                .padding(.horizontal)
                
                // Список теплиц (только для рабочих)
                if !isAdmin {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Теплицы")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView("Загрузка теплиц...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let error = errorMessage {
                            VStack(spacing: 8) {
                                Text("Ошибка загрузки")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Button("Повторить") {
                                    loadGreenhouses()
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else if greenhouses.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Нет привязанных теплиц")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(greenhouses) { greenhouse in
                                    NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouse.id)
                                        .environmentObject(bleManager)
                                        .environmentObject(sensorDataManager)
                                        .environmentObject(wateringDataManager)
                                        .environmentObject(fertilizingDataManager)) {
                                        GreenhouseCardView(
                                            greenhouse: greenhouse,
                                            sensorData: getSensorDataForGreenhouse(greenhouse),
                                            nextWatering: wateringDataManager.getNextWatering(greenhouseId: greenhouse.id),
                                            nextFertilizing: fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !isAdmin {
                loadGreenhouses()
            }
        }
        .refreshable {
            if !isAdmin {
                await loadGreenhousesAsync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextWateringUpdated"))) { _ in
            // Обновляем UI при обновлении данных о поливах
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextFertilizingUpdated"))) { _ in
            // Обновляем UI при обновлении данных об удобрениях
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SensorDataUpdated"))) { _ in
            // Обновляем UI при обновлении данных датчика
        }
    }
    
    private func loadGreenhouses() {
        Task {
            await loadGreenhousesAsync()
        }
    }
    
    private func loadGreenhousesAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let workerGreenhouses = try await APIService.shared.getWorkerGreenhouses(workerId: user.id)
            await MainActor.run {
                greenhouses = workerGreenhouses
                isLoading = false
            }
            
            // Загружаем данные о поливах и удобрениях для всех теплиц
            for greenhouse in workerGreenhouses {
                await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
                
                // Загружаем данные датчика, если есть
                if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                    await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                }
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
        }
    }
    
    // Получает данные датчика для теплицы
    private func getSensorDataForGreenhouse(_ greenhouse: GreenhouseOut) -> SensorReadingOut? {
        // Проверяем, есть ли sensor_id
        guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
            return nil
        }
        
        // Сначала проверяем, подключен ли датчик через BLE
        if let connectedDevice = bleManager.lastConnectedDevice,
           let bleSensorData = bleManager.sensors[connectedDevice.id] {
            // Проверяем, совпадает ли UUID подключенного устройства с ble_identifier датчика этой теплицы
            let connectedDeviceUUID = connectedDevice.id.uuidString
            
            // Получаем сохраненный ble_identifier для этой теплицы
            let savedBLEIdentifier = UserDefaults.standard.string(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
            
            // Если есть сохраненный ble_identifier и он совпадает с подключенным устройством
            if let savedBLE = savedBLEIdentifier, savedBLE == connectedDeviceUUID {
                return SensorReadingOut(
                    id: "",
                    sensor_id: greenhouse.sensor_id ?? "",
                    greenhouse_id: greenhouse.id,
                    temperature: bleSensorData.temperature,
                    humidity: bleSensorData.humidity,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
            }
            
            // Если нет сохраненного ble_identifier, но устройство подключено и у теплицы есть sensor_id
            if savedBLEIdentifier == nil {
                return SensorReadingOut(
                    id: "",
                    sensor_id: greenhouse.sensor_id ?? "",
                    greenhouse_id: greenhouse.id,
                    temperature: bleSensorData.temperature,
                    humidity: bleSensorData.humidity,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
            }
        }
        
        // Если не подключен через BLE, используем данные из глобального менеджера
        if let serverData = sensorDataManager.getSensorData(greenhouseId: greenhouse.id) {
            return serverData
        }
        
        return nil
    }
}

