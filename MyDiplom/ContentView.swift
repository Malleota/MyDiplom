import SwiftUI
import CoreBluetooth

// MARK: - UI

struct ContentView: View {
    @StateObject private var manager = BLEManager()
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sensorDataManager = SensorDataManager.shared
    @StateObject private var wateringDataManager = WateringDataManager.shared
    @StateObject private var fertilizingDataManager = FertilizingDataManager.shared
    @State private var showDeviceList = false
    @State private var showProfile = false
    
    // Состояния для отчета рабочего
    @State private var wateringEvents: [WaterEventOut] = []
    @State private var fertilizingEvents: [WaterEventOut] = []
    @State private var isLoadingReports = false
    @State private var greenhouses: [GreenhouseOut] = []
    @State private var plantInstances: [PlantInstanceOut] = []
    @State private var plantTypes: [String: PlantTypeOut] = [:]
    @State private var userRole: String? = nil
    
    var isWorker: Bool {
        let role = authManager.currentUser?.role ?? userRole
        return role == "worker"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Шапка с аватаром и приветствием
                    HStack(spacing: 12) {
                        Button(action: {
                            showProfile = true
                        }) {
                            if let avatarUrl = authManager.currentUser?.avatar_url,
                               let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    SkeletonView(width: 56, height: 56, cornerRadius: 8)
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 56, height: 56)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Если пользователь рабочий, показываем отчет
                    if let user = authManager.currentUser, user.role == "worker" {
                        // Отчет по действиям рабочего
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Мой отчет")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            if isLoadingReports {
                                ProgressView("Загрузка отчета...")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                let allEvents = (wateringEvents + fertilizingEvents).sorted { event1, event2 in
                                    return event1.created_at > event2.created_at
                                }
                                
                                if allEvents.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("Нет данных")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                } else {
                                    VStack(spacing: 0) {
                                        // Заголовок таблицы
                                        HStack(spacing: 0) {
                                            Text("Действие")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Text("Когда")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Text("В какой теплице")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Text("Тип растения")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemBackground))
                                        
                                        // Строки таблицы
                                        ForEach(allEvents) { event in
                                            WorkerReportRowView(
                                                event: event,
                                                greenhouseName: getGreenhouseName(greenhouseId: event.greenhouse_id),
                                                plantTypeName: getPlantTypeName(plantInstanceId: event.plant_instance_id),
                                                greenhouseId: event.greenhouse_id
                                            )
                                            .environmentObject(manager)
                                            .environmentObject(sensorDataManager)
                                            .environmentObject(wateringDataManager)
                                            .environmentObject(fertilizingDataManager)
                                        }
                                    }
                                    .padding(.top, 16)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }

                    // Состояние Bluetooth
                    switch manager.bluetoothState {
                    case .unauthorized:
                        Text("Нет доступа к Bluetooth. Разреши доступ в Настройки → Конфиденциальность → Bluetooth.")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    case .poweredOff:
                        Text("Bluetooth выключен. Включи Bluetooth на устройстве.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                            .padding(.horizontal)
                    default:
                        EmptyView()
                    }

                    // Выбранное/автоматически подключённое устройство
                    if let device = manager.lastConnectedDevice {
                        Text("Подключено: \(device.name)")
                            .font(.headline)
                            .padding(.horizontal)

                        if let sensor = manager.sensors[device.id] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: "Температура: %.2f °C", sensor.temperature))
                                Text(String(format: "Влажность: %.0f %%", sensor.humidity))
                                Text("Батарея: \(sensor.batteryPercent)%")
                                Text(String(format: "Напряжение: %.3f V", sensor.batteryVoltage))
                                Text("RSSI: \(sensor.rssi) dBm")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                            .padding(.horizontal)
                        } else {
                            Text("Нет данных от датчика. Подожди пару секунд после подключения.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                                .padding(.horizontal)
                        }
                    } else {
                        Text("Устройство не выбрано")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Кнопка ручного выбора устройства (если нужно сменить)
                    Button("Найти устройства") {
                        manager.startScan()
                        showDeviceList = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 24)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Привет, \(authManager.currentUser?.name ?? "")!")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showProfile = true
                    }) {
                        if let avatarUrl = authManager.currentUser?.avatar_url,
                           let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                SkeletonView(width: 32, height: 32, cornerRadius: 16)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDeviceList) {
                DeviceListView(manager: manager) { device in
                    manager.stopScan()
                    manager.connect(to: device)
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .onDisappear {
                        // Обновляем данные пользователя при закрытии профиля
                        Task {
                            await authManager.loadUserData()
                            if let user = authManager.currentUser, user.role == "worker" {
                                await loadReports()
                            }
                        }
                    }
            }
            .task {
                if authManager.currentUser == nil {
                    await authManager.loadUserData()
                }
                // Обновляем локальную копию роли
                userRole = authManager.currentUser?.role
                
                // Небольшая задержка, чтобы убедиться, что currentUser обновился
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунда
                
                // Проверяем еще раз после задержки
                userRole = authManager.currentUser?.role
                
                if let user = authManager.currentUser, user.role == "worker" {
                    await loadGreenhouses()
                    await loadPlantTypes()
                    await loadReports()
                }
            }
            .onChange(of: authManager.currentUser?.role) { newRole in
                userRole = newRole
                Task {
                    if newRole == "worker" {
                        await loadGreenhouses()
                        await loadPlantTypes()
                        await loadReports()
                    }
                }
            }
            .onAppear {
                // Обновляем роль при появлении view
                userRole = authManager.currentUser?.role
                if let user = authManager.currentUser, user.role == "worker" {
                    Task {
                        await loadGreenhouses()
                        await loadPlantTypes()
                        await loadReports()
                    }
                }
            }
            .refreshable {
                if let user = authManager.currentUser, user.role == "worker" {
                    await loadGreenhouses()
                    await loadPlantTypes()
                    await loadReports()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadGreenhouses() async {
        // Для воркеров getGreenhouses() автоматически возвращает только их теплицы
        // Для админов getGreenhouses() возвращает все теплицы
        do {
            let loadedGreenhouses = try await APIService.shared.getGreenhouses()
            await MainActor.run {
                greenhouses = loadedGreenhouses
            }
        } catch {
            print("❌ Ошибка загрузки теплиц: \(error)")
        }
    }
    
    private func loadPlantTypes() async {
        do {
            let allPlantTypes = try await APIService.shared.getPlantTypes()
            var typesDict: [String: PlantTypeOut] = [:]
            for plantType in allPlantTypes {
                typesDict[plantType.id] = plantType
            }
            await MainActor.run {
                plantTypes = typesDict
            }
        } catch {
            print("❌ Ошибка загрузки типов растений: \(error)")
        }
    }
    
    private func loadReports() async {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        await MainActor.run {
            isLoadingReports = true
        }
        
        do {
            let watering = try await APIService.shared.getWateringEvents(userId: userId)
            let fertilizing = try await APIService.shared.getFertilizingEvents(userId: userId)
            
            await MainActor.run {
                wateringEvents = watering
                fertilizingEvents = fertilizing
            }
            
            // Загружаем растения из всех теплиц для получения типов растений
            var allPlantInstances: [PlantInstanceOut] = []
            let currentGreenhouses = await MainActor.run { greenhouses }
            for greenhouse in currentGreenhouses {
                do {
                    let instances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouse.id)
                    allPlantInstances.append(contentsOf: instances)
                } catch {
                    print("❌ Ошибка загрузки растений для теплицы \(greenhouse.id): \(error)")
                }
            }
            
            await MainActor.run {
                plantInstances = allPlantInstances
                isLoadingReports = false
            }
        } catch {
            print("❌ Ошибка загрузки отчетов: \(error)")
            await MainActor.run {
                isLoadingReports = false
            }
        }
    }
    
    private func getGreenhouseName(greenhouseId: String) -> String {
        if let greenhouse = greenhouses.first(where: { $0.id == greenhouseId }) {
            return greenhouse.name
        }
        return "—"
    }
    
    private func getPlantTypeName(plantInstanceId: String?) -> String {
        guard let plantInstanceId = plantInstanceId else {
            return "—"
        }
        
        if let plantInstance = plantInstances.first(where: { $0.id == plantInstanceId }) {
            if let plantType = plantTypes[plantInstance.plant_type_id] {
                return plantType.name
            }
        }
        
        return "—"
    }
}
