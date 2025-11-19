//
//  GreenhouseViews.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI
import Combine
import CoreBluetooth

// MARK: - Greenhouse List View

struct GreenhouseListView: View {
    @EnvironmentObject var bleManager: BLEManager
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
                                NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouse.id).environmentObject(bleManager)) {
                                    GreenhouseCardView(
                                        greenhouse: greenhouse,
                                        sensorData: viewModel.getSensorDataForGreenhouse(greenhouse, bleManager: bleManager)
                                    )
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
                await viewModel.loadGreenhouses(bleManager: bleManager)
            }
            .refreshable {
                await viewModel.loadGreenhouses(bleManager: bleManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GreenhouseUpdated"))) { _ in
                Task {
                    await viewModel.loadGreenhouses(bleManager: bleManager)
                }
            }
        }
    }
}

// MARK: - Greenhouse Card View

struct GreenhouseCardView: View {
    let greenhouse: GreenhouseOut
    let sensorData: SensorReadingOut?
    
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
                    if let sensor = sensorData {
                        // Есть данные с датчика
                        HStack(spacing: 12) {
                            Label(String(format: "%.1f°C", sensor.temperature), systemImage: "thermometer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Label(String(format: "%.0f%%", sensor.humidity), systemImage: "humidity")
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
    @Published var sensorData: [String: SensorReadingOut] = [:]  // Изменили на SensorReadingOut
    @Published var isLoading = false
    
    func loadGreenhouses(bleManager: BLEManager? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedGreenhouses = try await APIService.shared.getGreenhouses()
            print("📥 loadGreenhouses: Загружено \(fetchedGreenhouses.count) теплиц")
            greenhouses = fetchedGreenhouses
            
            // Очищаем старые данные датчиков
            sensorData.removeAll()
            
            // Данные датчиков будут браться из BLE через getSensorDataForGreenhouse
            // Не загружаем данные с сервера
        } catch {
            print("❌ Ошибка загрузки теплиц: \(error)")
        }
    }
    
    func getSensorDataForGreenhouse(_ greenhouse: GreenhouseOut, bleManager: BLEManager) -> SensorReadingOut? {
        // Сначала проверяем, подключен ли датчик через BLE
        if let connectedDevice = bleManager.lastConnectedDevice,
           let bleSensorData = bleManager.sensors[connectedDevice.id] {
            // Проверяем, совпадает ли UUID подключенного устройства с ble_identifier датчика
            // При привязке мы использовали device.id.uuidString как ble_identifier
            let connectedDeviceUUID = connectedDevice.id.uuidString
            
            // Если устройство подключено, используем данные из BLE
            print("📡 Используем данные из BLE для теплицы \(greenhouse.name)")
            return SensorReadingOut(
                id: "",
                sensor_id: greenhouse.sensor_id ?? "",
                greenhouse_id: greenhouse.id,
                temperature: bleSensorData.temperature,
                humidity: bleSensorData.humidity,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
        }
        
        // Если не подключен через BLE, используем данные с сервера
        return sensorData[greenhouse.id]
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
    @EnvironmentObject var bleManager: BLEManager
    @State private var greenhouse: GreenhouseOut?
    @State private var sensorData: SensorReadingOut?
    @State private var isLoading = true
    @State private var showDeviceList = false
    @State private var isBinding = false
    @State private var errorMessage: String?
    
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
                                    // Название датчика
                                    HStack {
                                        Text("Датчик")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        // Батарея из BLE данных, если доступна
                                        if let connectedDevice = bleManager.lastConnectedDevice,
                                           let bleSensorData = bleManager.sensors[connectedDevice.id] {
                                            HStack(spacing: 4) {
                                                Image(systemName: "battery.100")
                                                    .foregroundColor(batteryColor(bleSensorData.batteryPercent))
                                                Text("\(bleSensorData.batteryPercent)%")
                                                    .font(.subheadline)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    // Две карточки: температура и влажность
                                    HStack(spacing: 12) {
                                        // Карточка температуры
                                        SensorDataCard(
                                            icon: "thermometer",
                                            title: "Температура",
                                            value: String(format: "%.1f", sensor.temperature),
                                            unit: "°C"
                                        )
                                        
                                        // Карточка влажности
                                        SensorDataCard(
                                            icon: "drop.fill",
                                            title: "Влажность",
                                            value: String(format: "%.0f", sensor.humidity),
                                            unit: "%"
                                        )
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
                                        bleManager.startScan(disableAutoConnect: true)
                                        showDeviceList = true
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
                                    
                                    if let error = errorMessage {
                                        Text(error)
                                            .font(.footnote)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                            .padding(.top, 8)
                                    }
                                    
                                    if isBinding {
                                        ProgressView("Привязка датчика...")
                                            .padding(.top, 8)
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
        .sheet(isPresented: $showDeviceList) {
            DeviceListView(manager: bleManager) { device in
                bleManager.stopScan()
                Task {
                    await bindDeviceToGreenhouse(device)
                }
            }
        }
        .task {
            await loadGreenhouse()
        }
        .onChange(of: bleManager.lastConnectedDevice?.id) { _ in
            // Обновляем данные при изменении подключенного устройства
            updateSensorDataFromBLE()
        }
        .onReceive(bleManager.$sensors) { _ in
            // Обновляем данные при изменении BLE данных
            updateSensorDataFromBLE()
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
            print("📥 loadGreenhouse: Загружена теплица \(fetched.name), sensor_id=\(fetched.sensor_id ?? "nil")")
            await MainActor.run {
                greenhouse = fetched
            }
            
            // Обновляем данные датчика из BLE, если он подключен
            await MainActor.run {
                updateSensorDataFromBLE()
            }
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("❌ Ошибка загрузки теплицы: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func updateSensorDataFromBLE() {
        guard let greenhouse = greenhouse,
              greenhouse.sensor_id != nil,
              let connectedDevice = bleManager.lastConnectedDevice,
              let bleSensorData = bleManager.sensors[connectedDevice.id] else {
            // Если датчик не подключен, очищаем данные
            sensorData = nil
            return
        }
        
        // Используем данные из BLE
        print("📡 updateSensorDataFromBLE: Обновляем данные из BLE для теплицы \(greenhouse.name)")
        sensorData = SensorReadingOut(
            id: "",
            sensor_id: greenhouse.sensor_id ?? "",
            greenhouse_id: greenhouse.id,
            temperature: bleSensorData.temperature,
            humidity: bleSensorData.humidity,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    private func bindDeviceToGreenhouse(_ device: DiscoveredDevice) async {
        await MainActor.run {
            isBinding = true
            errorMessage = nil
            showDeviceList = false
        }
        
        // Привязываем устройство к теплице
        // Используем UUID устройства как ble_identifier
        let bleIdentifier = device.id.uuidString
        print("Привязка датчика к теплице: greenhouseId=\(greenhouseId), bleIdentifier=\(bleIdentifier), deviceName=\(device.name)")
        
        do {
            try await APIService.shared.bindSensorToGreenhouse(
                greenhouseId: greenhouseId,
                bleIdentifier: bleIdentifier
            )
            
            print("Датчик успешно привязан к теплице")
            
            // Подключаемся к устройству через BLE
            print("Подключение к устройству через BLE...")
            await MainActor.run {
                bleManager.connect(to: device)
            }
            
            // Ждем немного, чтобы подключение установилось
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            
            // Успешно привязано и подключено, обновляем данные теплицы
            await loadGreenhouse()
            
            // Отправляем уведомление для обновления списка теплиц
            NotificationCenter.default.post(name: NSNotification.Name("GreenhouseUpdated"), object: nil)
            
            await MainActor.run {
                isBinding = false
            }
            
            // НЕ закрываем экран - остаемся на странице теплицы
        } catch {
            print("Ошибка привязки датчика: \(error)")
            await MainActor.run {
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                    print("API Error detail: \(apiError.detail)")
                } else {
                    errorMessage = "Ошибка привязки датчика: \(error.localizedDescription)"
                    print("General error: \(error.localizedDescription)")
                }
                isBinding = false
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


