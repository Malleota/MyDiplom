//
//  MainTabView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI
import CoreBluetooth
import Combine

struct MainTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var bleManager = BLEManager()
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @State private var selectedTab = 0
    
    var isAdmin: Bool {
        authManager.currentUser?.role == "admin"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Главная
            HomeView()
                .environmentObject(bleManager)
                .environmentObject(sensorDataManager)
                .environmentObject(wateringDataManager)
                .environmentObject(fertilizingDataManager)
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }
                .tag(0)
            
            // Справочник
            PlantsView()
                .environmentObject(bleManager)
                .environmentObject(sensorDataManager)
                .environmentObject(wateringDataManager)
                .environmentObject(fertilizingDataManager)
                .tabItem {
                    Label("Справочник", systemImage: "leaf")
                }
                .tag(1)
            
            // Теплицы
            GreenhousesView()
                .environmentObject(bleManager)
                .environmentObject(sensorDataManager)
                .environmentObject(wateringDataManager)
                .environmentObject(fertilizingDataManager)
                .tabItem {
                    Label("Теплицы", systemImage: "building.2.fill")
                }
                .tag(2)
            
            // Работники - только для админа
            if isAdmin {
                WorkersView()
                    .environmentObject(bleManager)
                    .environmentObject(sensorDataManager)
                    .environmentObject(wateringDataManager)
                    .environmentObject(fertilizingDataManager)
                    .tabItem {
                        Label("Работники", systemImage: "person.2.fill")
                    }
                    .tag(3)
            }
        }
        .onChange(of: isAdmin) { newValue in
            // Если пользователь больше не админ и выбран таб "Работники", переключаемся на главную
            if !newValue && selectedTab == 3 {
                selectedTab = 0
            }
        }
        .task {
            if authManager.currentUser == nil {
                await authManager.loadUserData()
            }
        }
    }
}

// MARK: - Home View (Главная)
struct HomeView: View {
    @EnvironmentObject var manager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = HomeViewModel()
    @State private var showDeviceList = false
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                                    ProgressView()
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 56, height: 56)
                            }
                        }
                        
                        Text("Привет, \(authManager.currentUser?.name ?? "")!")
                            .font(.title2.bold())
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Блок "Требуют внимания"
                    VStack(alignment: .leading, spacing: 0) {
                        // Заголовок блока с иконкой и счетчиком
                        HStack(alignment: .center, spacing: 12) {
                            HStack(spacing: 10) {
                               // ZStack {
                                   // Circle()
                                    //    .fill(DesignColor.myYellow.opacity(0.15))
                                   //     .frame(width: 40, height: 40)
                                    
                                   // Image(systemName: "exclamationmark.triangle.fill")
                                   //     .font(.system(size: 18, weight: .semibold))
                                  //      .foregroundColor(DesignColor.myYellow)
                                //}
                                
                                Text("Требуют внимания")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Индикатор загрузки
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // Контент блока
                        if viewModel.isLoading {
                            // Состояние загрузки
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 32)
                                Spacer()
                            }
                            .padding(.bottom, 16)
                        } else if viewModel.greenhousesRequiringAttention.isEmpty {
                            // Пустое состояние
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(DesignColor.mainAccent.opacity(0.1))
                                        .frame(width: 64, height: 64)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 36, weight: .medium))
                                        .foregroundColor(DesignColor.mainAccent)
                                }
                                
                                VStack(spacing: 4) {
                                    Text("Все теплицы в порядке")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Нет теплиц, требующих полива или удобрения")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } else {
                            // Список теплиц вертикально
                            VStack(spacing: 12) {
                                ForEach(viewModel.greenhousesRequiringAttention, id: \.id) { greenhouse in
                                    NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouse.id)
                                        .environmentObject(manager)
                                        .environmentObject(sensorDataManager)
                                        .environmentObject(wateringDataManager)
                                        .environmentObject(fertilizingDataManager)) {
                                        FlatGreenhouseCardView(
                                            greenhouse: greenhouse,
                                            sensorData: viewModel.getSensorDataForGreenhouse(greenhouse, bleManager: manager, sensorDataManager: sensorDataManager),
                                            nextWatering: wateringDataManager.getNextWatering(greenhouseId: greenhouse.id),
                                            nextFertilizing: fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id),
                                            plantImageUrl: viewModel.getPlantImageUrl(
                                                greenhouse: greenhouse,
                                                nextWatering: wateringDataManager.getNextWatering(greenhouseId: greenhouse.id),
                                                nextFertilizing: fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id)
                                            )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(DesignColor.Fills.tertiar, lineWidth: 1.0)
                            )
                    )
                    .padding(.horizontal)

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
                        VStack(alignment: .leading, spacing: 12) {
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
                                .padding(.horizontal)
                            } else {
                                Text("Нет данных от датчика. Подожди пару секунд после подключения.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Кнопка отключения
                            Button("Отключить") {
                                manager.disconnect()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                        }
                    } else {
                        Text("Устройство не выбрано")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Кнопка ручного выбора устройства (если нужно сменить)
                    Button("Найти устройства") {
                        manager.startScan(disableAutoConnect: true)
                        showDeviceList = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .padding(.vertical)
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
                        }
                    }
            }
            .task {
                if authManager.currentUser == nil {
                    await authManager.loadUserData()
                }
                await viewModel.loadData(
                    bleManager: manager,
                    sensorDataManager: sensorDataManager,
                    wateringDataManager: wateringDataManager,
                    fertilizingDataManager: fertilizingDataManager
                )
            }
            .refreshable {
                await viewModel.loadData(
                    bleManager: manager,
                    sensorDataManager: sensorDataManager,
                    wateringDataManager: wateringDataManager,
                    fertilizingDataManager: fertilizingDataManager
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextWateringUpdated"))) { _ in
                Task {
                    await viewModel.updateRequiringAttention(
                        wateringDataManager: wateringDataManager,
                        fertilizingDataManager: fertilizingDataManager
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextFertilizingUpdated"))) { _ in
                Task {
                    await viewModel.updateRequiringAttention(
                        wateringDataManager: wateringDataManager,
                        fertilizingDataManager: fertilizingDataManager
                    )
                }
            }
        }
    }
}

// MARK: - Home ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var greenhousesRequiringAttention: [GreenhouseOut] = []
    @Published var allGreenhouses: [GreenhouseOut] = []
    @Published var isLoading = false
    
    func loadData(
        bleManager: BLEManager,
        sensorDataManager: SensorDataManager,
        wateringDataManager: WateringDataManager,
        fertilizingDataManager: FertilizingDataManager
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Загружаем все теплицы
            allGreenhouses = try await APIService.shared.getGreenhouses()
            print("🏠 HomeViewModel: Загружено \(allGreenhouses.count) теплиц")
            
            // Загружаем данные о поливах и удобрениях для всех теплиц
            for greenhouse in allGreenhouses {
                print("🏠 HomeViewModel: Загрузка данных для теплицы '\(greenhouse.name)'")
                await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
                
                // Регистрируем теплицу для отслеживания данных датчика
                if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                    sensorDataManager.registerGreenhouse(greenhouseId: greenhouse.id)
                    await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                }
            }
            
            // Небольшая задержка, чтобы данные успели сохраниться
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            
            // Обновляем список требующих внимания
            await updateRequiringAttention(
                wateringDataManager: wateringDataManager,
                fertilizingDataManager: fertilizingDataManager
            )
        } catch {
            print("❌ HomeViewModel: Ошибка загрузки данных: \(error)")
        }
    }
    
    func updateRequiringAttention(
        wateringDataManager: WateringDataManager,
        fertilizingDataManager: FertilizingDataManager
    ) async {
        print("🔍 HomeViewModel: Обновление списка требующих внимания. Всего теплиц: \(allGreenhouses.count)")
        
        var requiringAttention: [GreenhouseOut] = []
        
        for greenhouse in allGreenhouses {
            let nextWatering = wateringDataManager.getNextWatering(greenhouseId: greenhouse.id)
            let nextFertilizing = fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id)
            
            let needsAttention = requiresAttention(
                greenhouse: greenhouse,
                nextWatering: nextWatering,
                nextFertilizing: nextFertilizing
            )
            
            if needsAttention {
                print("⚠️ HomeViewModel: Теплица '\(greenhouse.name)' требует внимания")
                if let watering = nextWatering {
                    print("   - Полив: is_overdue=\(watering.is_overdue), days_until=\(watering.days_until?.description ?? "nil")")
                }
                if let fertilizing = nextFertilizing {
                    print("   - Удобрение: is_overdue=\(fertilizing.is_overdue), days_until=\(fertilizing.days_until?.description ?? "nil")")
                }
                requiringAttention.append(greenhouse)
            } else {
                print("✅ HomeViewModel: Теплица '\(greenhouse.name)' не требует внимания")
                if let watering = nextWatering {
                    print("   - Полив: is_overdue=\(watering.is_overdue), days_until=\(watering.days_until?.description ?? "nil")")
                } else {
                    print("   - Полив: нет данных")
                }
                if let fertilizing = nextFertilizing {
                    print("   - Удобрение: is_overdue=\(fertilizing.is_overdue), days_until=\(fertilizing.days_until?.description ?? "nil")")
                } else {
                    print("   - Удобрение: нет данных")
                }
            }
        }
        
        greenhousesRequiringAttention = requiringAttention
        print("🔍 HomeViewModel: Найдено теплиц, требующих внимания: \(greenhousesRequiringAttention.count)")
    }
    
    private func requiresAttention(
        greenhouse: GreenhouseOut,
        nextWatering: NextWateringOut?,
        nextFertilizing: NextWateringOut?
    ) -> Bool {
        // Проверяем полив
        if let watering = nextWatering {
            // Просроченный полив - всегда требует внимания
            if watering.is_overdue {
                print("   ✅ Требует внимания: полив просрочен")
                return true
            }
            // Полив требуется сегодня или завтра (days_until <= 1)
            if let daysUntil = watering.days_until {
                if daysUntil <= 1 {
                    print("   ✅ Требует внимания: полив через \(daysUntil) день(дней)")
                    return true
                }
            }
        }
        
        // Проверяем удобрение
        if let fertilizing = nextFertilizing {
            // Просроченное удобрение - всегда требует внимания
            if fertilizing.is_overdue {
                print("   ✅ Требует внимания: удобрение просрочено")
                return true
            }
            // Удобрение требуется сегодня или завтра (days_until <= 1)
            if let daysUntil = fertilizing.days_until {
                if daysUntil <= 1 {
                    print("   ✅ Требует внимания: удобрение через \(daysUntil) день(дней)")
                    return true
                }
            }
        }
        
        return false
    }
    
    func getPlantImageUrl(
        greenhouse: GreenhouseOut,
        nextWatering: NextWateringOut?,
        nextFertilizing: NextWateringOut?
    ) -> String? {
        // Пока используем изображение теплицы
        // В будущем можно загрузить plant_type по plant_instance_id
        return greenhouse.image_url
    }
    
    func getSensorDataForGreenhouse(
        _ greenhouse: GreenhouseOut,
        bleManager: BLEManager,
        sensorDataManager: SensorDataManager
    ) -> SensorReadingOut? {
        // Проверяем, есть ли sensor_id
        guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
            return nil
        }
        
        // Сначала проверяем данные из SensorDataManager (данные с сервера через WebSocket)
        if let sensorData = sensorDataManager.getSensorData(greenhouseId: greenhouse.id) {
            return sensorData
        }
        
        // Если нет данных в SensorDataManager, проверяем BLEManager
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
            // Предполагаем, что это тот же датчик (для обратной совместимости)
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
        
        return nil
    }
}

// MARK: - Greenhouses View (Теплицы)
struct GreenhousesView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    var body: some View {
        GreenhouseListView()
            .environmentObject(bleManager)
            .environmentObject(sensorDataManager)
            .environmentObject(wateringDataManager)
            .environmentObject(fertilizingDataManager)
    }
}

// MARK: - Flat Greenhouse Card View (без тени для использования внутри блока)
struct FlatGreenhouseCardView: View {
    let greenhouse: GreenhouseOut
    let sensorData: SensorReadingOut?
    let nextWatering: NextWateringOut?
    let nextFertilizing: NextWateringOut?
    let plantImageUrl: String?
    
    // Проверяем, нужно ли показывать кнопку "Полить" (как в PlantCardView)
    private var shouldShowWaterButton: Bool {
        guard let nextWatering = nextWatering else { return false }
        if let daysUntil = nextWatering.days_until {
            return nextWatering.is_overdue || daysUntil == 0
        }
        return false
    }
    
    // Проверяем, нужно ли показывать кнопку "Удобрить" (как в PlantCardView)
    private var shouldShowFertilizeButton: Bool {
        guard let nextFertilizing = nextFertilizing else { return false }
        if let daysUntil = nextFertilizing.days_until {
            return nextFertilizing.is_overdue || daysUntil == 0
        }
        return false
    }
    
    private var plantName: String {
        if let watering = nextWatering, let name = watering.plant_name {
            return name
        }
        if let fertilizing = nextFertilizing, let name = fertilizing.plant_name {
            return name
        }
        return "Растение"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Изображение растения (квадратная с закругленными углами)
            if let imageUrl = plantImageUrl,
               let url = APIService.shared.getFullImageURL(imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 44, height: 44)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(DesignColor.mainAccent.opacity(0.7))
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 44, height: 44)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignColor.mainAccent.opacity(0.7))
                    )
            }
            
            // Информация о теплице и растении
            VStack(alignment: .leading, spacing: 8) {
                Text(greenhouse.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(plantName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Информация о поливе и удобрении
                VStack(alignment: .leading, spacing: 4) {
                    // Время до следующего полива
                    if let nextWatering = nextWatering {
                        if let daysUntil = nextWatering.days_until {
                            if nextWatering.is_overdue {
                                Label("\(abs(daysUntil)) \(daysWordForm(abs(daysUntil)))", systemImage: "drop")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.mainRed)
                            } else if daysUntil == 0 {
                                Label("Сегодня", systemImage: "drop")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.myYellow)
                            } else {
                                Label("\(daysUntil) \(daysWordForm(daysUntil))", systemImage: "drop")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if let lastWateringDate = nextWatering.next_watering_date {
                            Label("Последний: \(formatDate(lastWateringDate))", systemImage: "drop")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Label("Не запланирован", systemImage: "drop")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("Загрузка...", systemImage: "drop")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Время до следующего удобрения
                    if let nextFertilizing = nextFertilizing {
                        if let daysUntil = nextFertilizing.days_until {
                            if nextFertilizing.is_overdue {
                                Label("\(abs(daysUntil)) \(daysWordForm(abs(daysUntil)))", systemImage: "pills")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.mainRed)
                            } else if daysUntil == 0 {
                                Label("Сегодня", systemImage: "pills")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.myYellow)
                            } else {
                                Label("\(daysUntil) \(daysWordForm(daysUntil))", systemImage: "pills")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if let lastFertilizingDate = nextFertilizing.next_watering_date {
                            Label("Последнее: \(formatDate(lastFertilizingDate))", systemImage: "pills")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Label("Не запланировано", systemImage: "testtube.2")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("Загрузка...", systemImage: "testtube.2")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Кнопки действий (как в PlantCardView - только если просрочено или требуется сегодня)
            VStack(spacing: 8) {
                // Кнопка "Полить" - показываем только если просрочено или требуется сегодня
                if shouldShowWaterButton {
                    Text("Полить")
                        .font(.caption)
                        .fontWeight(.medium)
                        .tracking(-0.5)
                        .lineSpacing(15)
                        .foregroundColor(DesignColor.myBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DesignColor.myBlue.opacity(0.1))
                        .cornerRadius(40)
                }
                
                // Кнопка "Удобрить" - показываем только если просрочено или требуется сегодня
                if shouldShowFertilizeButton {
                    Text("Удобрить")
                        .font(.caption)
                        .fontWeight(.medium)
                        .tracking(-0.5)
                        .lineSpacing(15)
                        .foregroundColor(DesignColor.myBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DesignColor.myBrown.opacity(0.1))
                        .cornerRadius(40)
                }
            }
        }
      
    }
    
    // Вспомогательные функции
    private func daysWordForm(_ count: Int) -> String {
        let absCount = abs(count)
        if absCount < 5 {
            return "дня"
        } else {
            return "дней"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: dateString) else {
            return "выполнен"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }
}

// MARK: - Device List View
struct DeviceListView: View {
    @ObservedObject var manager: BLEManager
    let onSelect: (DiscoveredDevice) -> Void
    @Environment(\.dismiss) private var dismiss
    var showNavigationView: Bool = true

    var body: some View {
        let content = List(manager.devices) { device in
            Button {
                onSelect(device)
                if showNavigationView {
                    dismiss()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                        Text("RSSI: \(device.rssi) dBm")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Выбор устройства")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") { dismiss() }
            }
        }
        
        if showNavigationView {
            NavigationView {
                content
            }
        } else {
            content
        }
    }
}


