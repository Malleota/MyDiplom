//
//  MainTabView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI
import CoreBluetooth
import Combine

// Глобальная блокировка для предотвращения одновременных операций полива/удобрения
private let globalOperationLock = NSLock()
private var activeOperations: Set<String> = [] // plantInstanceId -> активные операции

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
                    VStack(alignment: .leading, spacing: 12) {
                        // Заголовок блока
                        HStack(alignment: .center, spacing: 12) {
                            Text("Требуют внимания")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Индикатор загрузки
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Контент блока
                        if viewModel.isLoading {
                            // Состояние загрузки
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 32)
                                Spacer()
                            }
                        } else if viewModel.greenhousesRequiringAttention.isEmpty {
                            // Пустое состояние - все теплицы в порядке
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
                            .padding(.horizontal)
                        } else if viewModel.greenhousesRequiringAttention.count == 1 {
                            // Если одна теплица - показываем на всю ширину без скролла
                            ForEach(viewModel.greenhousesRequiringAttention, id: \.id) { greenhouse in
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
                            .padding(.horizontal)
                        } else {
                            // Горизонтальный скролл карточек для нескольких теплиц
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.greenhousesRequiringAttention, id: \.id) { greenhouse in
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
                                        .frame(width: 320)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Блок "Подключенные датчики" - только для админа
                    if authManager.currentUser?.role == "admin" {
                        VStack(alignment: .leading, spacing: 12) {
                        // Заголовок блока
                        HStack(alignment: .center, spacing: 12) {
                            Text("Подключенные датчики")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Контент блока
                        if viewModel.isLoading {
                            // Состояние загрузки
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 32)
                                Spacer()
                            }
                        } else if viewModel.greenhousesWithSensors.isEmpty {
                            // Пустое состояние
                            HStack(spacing: 8) {
                                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Text("Нет подключенных датчиков")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal)
                        } else if viewModel.greenhousesWithSensors.count == 1 {
                            // Если один датчик - показываем на всю ширину
                            ForEach(viewModel.greenhousesWithSensors, id: \.id) { greenhouse in
                                SensorCardView(
                                    greenhouse: greenhouse,
                                    onDisconnect: {
                                        // Обновляем данные после отключения
                                        Task {
                                            await viewModel.loadData(
                                                bleManager: manager,
                                                sensorDataManager: sensorDataManager,
                                                wateringDataManager: wateringDataManager,
                                                fertilizingDataManager: fertilizingDataManager
                                            )
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal)
                        } else {
                            // Горизонтальный скролл карточек для нескольких датчиков
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.greenhousesWithSensors, id: \.id) { greenhouse in
                                        SensorCardView(
                                            greenhouse: greenhouse,
                                            onDisconnect: {
                                                // Обновляем данные после отключения
                                                Task {
                                                    await viewModel.loadData(
                                                        bleManager: manager,
                                                        sensorDataManager: sensorDataManager,
                                                        wateringDataManager: wateringDataManager,
                                                        fertilizingDataManager: fertilizingDataManager
                                                    )
                                                }
                                            }
                                        )
                                        .frame(width: 320)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        }
                    }
                }
                
                // Блок "Сводка" - только для админа
                if authManager.currentUser?.role == "admin" {
                    SummaryBlockView()
                        .environmentObject(manager)
                        .environmentObject(sensorDataManager)
                        .environmentObject(wateringDataManager)
                        .environmentObject(fertilizingDataManager)
                }
            }
            .padding(.vertical)
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GreenhouseUpdated"))) { _ in
                Task {
                    await viewModel.loadData(
                        bleManager: manager,
                        sensorDataManager: sensorDataManager,
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
    
    // Получаем теплицы с привязанными датчиками
    var greenhousesWithSensors: [GreenhouseOut] {
        allGreenhouses.filter { greenhouse in
            if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                return true
            }
            return false
        }
    }
    
    func loadData(
        bleManager: BLEManager,
        sensorDataManager: SensorDataManager,
        wateringDataManager: WateringDataManager,
        fertilizingDataManager: FertilizingDataManager
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Загружаем теплицы (API автоматически фильтрует: админ видит все, рабочий - только привязанные)
            allGreenhouses = try await APIService.shared.getGreenhouses()
            let userRole = AuthManager.shared.currentUser?.role ?? "unknown"
            print("🏠 HomeViewModel: Загружено \(allGreenhouses.count) теплиц для пользователя с ролью \(userRole)")
            
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
            // Полив требуется сегодня (days_until == 0)
            if let daysUntil = watering.days_until {
                if daysUntil == 0 {
                    print("   ✅ Требует внимания: полив сегодня")
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
            // Удобрение требуется сегодня (days_until == 0)
            if let daysUntil = fertilizing.days_until {
                if daysUntil == 0 {
                    print("   ✅ Требует внимания: удобрение сегодня")
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

// MARK: - Flat Greenhouse Card View (новый дизайн в формате карточки)
struct FlatGreenhouseCardView: View {
    let greenhouse: GreenhouseOut
    let sensorData: SensorReadingOut?
    let nextWatering: NextWateringOut?
    let nextFertilizing: NextWateringOut?
    let plantImageUrl: String?
    
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    
    @State private var isWatering = false
    @State private var isFertilizing = false
    @State private var errorMessage: String?
    
    // Получаем plant_instance_id из nextWatering или nextFertilizing
    private var plantInstanceId: String? {
        nextWatering?.plant_instance_id ?? nextFertilizing?.plant_instance_id
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
    
    // Проверяем, нужно ли показывать кнопку "Полить"
    private var shouldShowWaterButton: Bool {
        guard let nextWatering = nextWatering else { return false }
        if let daysUntil = nextWatering.days_until {
            return nextWatering.is_overdue || daysUntil == 0
        }
        return false
    }
    
    // Проверяем, нужно ли показывать кнопку "Удобрить"
    private var shouldShowFertilizeButton: Bool {
        guard let nextFertilizing = nextFertilizing else { return false }
        if let daysUntil = nextFertilizing.days_until {
            return nextFertilizing.is_overdue || daysUntil == 0
        }
        return false
    }
    
    // Форматирование текста для полива
    private var wateringText: String {
        if let nextWatering = nextWatering {
            if let daysUntil = nextWatering.days_until {
                if nextWatering.is_overdue {
                    return "Просрочено на \(abs(daysUntil)) \(daysWordForm(abs(daysUntil)))"
                } else if daysUntil == 0 {
                    return "Сегодня"
                } else {
                    return "через \(daysUntil) \(daysWordForm(daysUntil))"
                }
            } else if let lastWateringDate = nextWatering.next_watering_date {
                return "Последний: \(formatDate(lastWateringDate))"
            } else {
                return "Не запланирован"
            }
        }
        return "Загрузка..."
    }
    
    // Форматирование текста для удобрения
    private var fertilizingText: String {
        if let nextFertilizing = nextFertilizing {
            if let daysUntil = nextFertilizing.days_until {
                if nextFertilizing.is_overdue {
                    return "Просрочено на \(abs(daysUntil)) \(daysWordForm(abs(daysUntil)))"
                } else if daysUntil == 0 {
                    return "Сегодня"
                } else {
                    return "через \(daysUntil) \(daysWordForm(daysUntil))"
                }
            } else if let lastFertilizingDate = nextFertilizing.next_watering_date {
                return "Последнее: \(formatDate(lastFertilizingDate))"
            } else {
                return "Не запланировано"
            }
        }
        return "Загрузка..."
    }
    
    // Цвет текста для полива (красный если просрочено или сегодня)
    private var wateringTextColor: Color {
        if let nextWatering = nextWatering {
            if let daysUntil = nextWatering.days_until {
                if nextWatering.is_overdue || daysUntil == 0 {
                    return DesignColor.mainRed
                }
            }
        }
        return .secondary
    }
    
    // Цвет текста для удобрения (красный если просрочено или сегодня)
    private var fertilizingTextColor: Color {
        if let nextFertilizing = nextFertilizing {
            if let daysUntil = nextFertilizing.days_until {
                if nextFertilizing.is_overdue || daysUntil == 0 {
                    return DesignColor.mainRed
                }
            }
        }
        return .secondary
    }
    
    @EnvironmentObject var manager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    
    var body: some View {
        NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouse.id)
            .environmentObject(manager)
            .environmentObject(sensorDataManager)
            .environmentObject(wateringDataManager)
            .environmentObject(fertilizingDataManager)) {
            VStack(spacing: 0) {
            // Верхняя часть: иконка, название теплицы и растения
            HStack(spacing: 12) {
                // Изображение растения
                if let imageUrl = plantImageUrl,
                   let url = APIService.shared.getFullImageURL(imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 60, height: 60)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(DesignColor.mainAccent.opacity(0.7))
                                )
                        @unknown default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 60, height: 60)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignColor.mainAccent.opacity(0.7))
                        )
                }
                
                // Название теплицы и растения
                VStack(alignment: .leading, spacing: 4) {
                    Text(greenhouse.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(plantName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Разделитель
            Divider()
                .background(Color.gray.opacity(0.2))
                .padding(.horizontal, 16)
            
            // Информация о поливе и удобрении
            VStack(spacing: 10) {
                // Полив
                HStack(spacing: 8) {
                    Image(systemName: "drop")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColor.myBlue.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Text("Полив:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(wateringText)
                            .font(.subheadline)
                            .foregroundColor(wateringTextColor)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Удобрение
                HStack(spacing: 8) {
                    Image(systemName: "pills")
                        .font(.system(size: 14))
                        .foregroundColor(DesignColor.myBrown.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Text("Удобрение:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(fertilizingText)
                            .font(.subheadline)
                            .foregroundColor(fertilizingTextColor)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
            
            // Кнопки действий (показываем только нужные)
            if shouldShowWaterButton || shouldShowFertilizeButton {
                HStack(spacing: 12) {
                    // Кнопка "Полить"
                    if shouldShowWaterButton {
                        Button(action: {
                            guard let plantInstanceId = plantInstanceId else { return }
                            
                            // АТОМАРНАЯ БЛОКИРОВКА: Используем глобальный NSLock для синхронной проверки
                            globalOperationLock.lock()
                            let isAlreadyActive = activeOperations.contains(plantInstanceId)
                            if !isAlreadyActive {
                                activeOperations.insert(plantInstanceId)
                                print("🔒 waterPlant: Блокировка установлена для растения \(plantInstanceId)")
                            }
                            globalOperationLock.unlock()
                            
                            if isAlreadyActive {
                                print("⚠️ Кнопка 'Полить' заблокирована, операция уже выполняется для растения \(plantInstanceId)")
                                return
                            }
                            
                            Task { @MainActor in
                                // Дополнительная проверка на MainActor
                                if isWatering || isFertilizing {
                                    print("⚠️ waterPlant: Операция уже выполняется, пропускаем (внутри Task)")
                                    globalOperationLock.lock()
                                    activeOperations.remove(plantInstanceId)
                                    globalOperationLock.unlock()
                                    return
                                }
                                isWatering = true
                                print("🔒 waterPlant: Флаг установлен в Task перед вызовом функции")
                                
                                await waterPlant()
                                
                                // Снимаем блокировку после завершения
                                globalOperationLock.lock()
                                activeOperations.remove(plantInstanceId)
                                globalOperationLock.unlock()
                                print("🔓 waterPlant: Блокировка снята для растения \(plantInstanceId)")
                            }
                        }) {
                            if isWatering {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Полить")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColor.myBlue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignColor.myBlue.opacity(0.15))
                        .cornerRadius(10)
                        .disabled(isWatering || isFertilizing)
                        .simultaneousGesture(TapGesture().onEnded { })
                    }
                    
                    // Кнопка "Удобрить"
                    if shouldShowFertilizeButton {
                        Button(action: {
                            guard let plantInstanceId = plantInstanceId else { return }
                            
                            // АТОМАРНАЯ БЛОКИРОВКА: Используем глобальный NSLock для синхронной проверки
                            globalOperationLock.lock()
                            let isAlreadyActive = activeOperations.contains(plantInstanceId)
                            if !isAlreadyActive {
                                activeOperations.insert(plantInstanceId)
                                print("🔒 fertilizePlant: Блокировка установлена для растения \(plantInstanceId)")
                            }
                            globalOperationLock.unlock()
                            
                            if isAlreadyActive {
                                print("⚠️ Кнопка 'Удобрить' заблокирована, операция уже выполняется для растения \(plantInstanceId)")
                                return
                            }
                            
                            Task { @MainActor in
                                // Дополнительная проверка на MainActor
                                if isWatering || isFertilizing {
                                    print("⚠️ fertilizePlant: Операция уже выполняется, пропускаем (внутри Task)")
                                    globalOperationLock.lock()
                                    activeOperations.remove(plantInstanceId)
                                    globalOperationLock.unlock()
                                    return
                                }
                                isFertilizing = true
                                print("🔒 fertilizePlant: Флаг установлен в Task перед вызовом функции")
                                
                                await fertilizePlant()
                                
                                // Снимаем блокировку после завершения
                                globalOperationLock.lock()
                                activeOperations.remove(plantInstanceId)
                                globalOperationLock.unlock()
                                print("🔓 fertilizePlant: Блокировка снята для растения \(plantInstanceId)")
                            }
                        }) {
                            if isFertilizing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Удобрить")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColor.myBrown)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignColor.myBrown.opacity(0.15))
                        .cornerRadius(10)
                        .disabled(isWatering || isFertilizing)
                        .simultaneousGesture(TapGesture().onEnded { })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            
            // Сообщение об ошибке
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(DesignColor.mainRed)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignColor.Fills.tertiar, lineWidth: 1.0)
        )
        }
        .buttonStyle(PlainButtonStyle())
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
    
    private func waterPlant() async {
        guard let plantInstanceId = plantInstanceId else {
            print("❌ waterPlant: plantInstanceId отсутствует")
            await MainActor.run {
                isWatering = false
            }
            return
        }
        
        print("🔵 waterPlant: Начало выполнения для растения \(plantInstanceId)")
        
        // Дополнительная проверка на случай, если флаг не был установлен в обработчике
        let shouldProceed = await MainActor.run {
            if isFertilizing {
                print("⚠️ waterPlant: Операция удобрения уже выполняется, пропускаем вызов")
                isWatering = false
                return false
            }
            if !isWatering {
                print("⚠️ waterPlant: Флаг не установлен, устанавливаем сейчас")
                isWatering = true
            }
            errorMessage = nil
            print("✅ waterPlant: Флаг проверен/установлен, начинаем создание события")
            return true
        }
        
        guard shouldProceed else {
            print("❌ waterPlant: Вызов заблокирован, выходим")
            return
        }
        
        do {
            print("💧 waterPlant: Вызываем createWateringEvent для растения \(plantInstanceId)")
            _ = try await APIService.shared.createWateringEvent(
                greenhouseId: greenhouse.id,
                plantInstanceId: plantInstanceId,
                type: "watering",
                comment: nil
            )
            
            print("✅ Полив успешно выполнен для растения \(plantInstanceId)")
            
            // Ждем немного, чтобы сервер успел пересчитать данные о поливе
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            // Обновляем данные
            await MainActor.run {
                isWatering = false
            }
            
            // Обновляем данные о поливе
            await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
            
            // Отправляем уведомление об обновлении
            NotificationCenter.default.post(name: NSNotification.Name("NextWateringUpdated"), object: nil)
        } catch {
            print("❌ Ошибка полива: \(error)")
            await MainActor.run {
                isWatering = false
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Ошибка полива: \(error.localizedDescription)"
                }
            }
            // Снимаем блокировку в случае ошибки
            globalOperationLock.lock()
            activeOperations.remove(plantInstanceId)
            globalOperationLock.unlock()
            print("🔓 waterPlant: Блокировка снята после ошибки для растения \(plantInstanceId)")
        }
    }
    
    private func fertilizePlant() async {
        guard let plantInstanceId = plantInstanceId else {
            print("❌ fertilizePlant: plantInstanceId отсутствует")
            await MainActor.run {
                isFertilizing = false
            }
            return
        }
        
        print("🟢 fertilizePlant: Начало выполнения для растения \(plantInstanceId)")
        
        // Дополнительная проверка на случай, если флаг не был установлен в обработчике
        let shouldProceed = await MainActor.run {
            if isWatering {
                print("⚠️ fertilizePlant: Операция полива уже выполняется, пропускаем вызов")
                isFertilizing = false
                return false
            }
            if !isFertilizing {
                print("⚠️ fertilizePlant: Флаг не установлен, устанавливаем сейчас")
                isFertilizing = true
            }
            errorMessage = nil
            print("✅ fertilizePlant: Флаг проверен/установлен, начинаем создание события")
            return true
        }
        
        guard shouldProceed else {
            print("❌ fertilizePlant: Вызов заблокирован, выходим")
            return
        }
        
        do {
            print("🌿 fertilizePlant: Вызываем createWateringEvent для растения \(plantInstanceId)")
            _ = try await APIService.shared.createWateringEvent(
                greenhouseId: greenhouse.id,
                plantInstanceId: plantInstanceId,
                type: "fertilizing",
                comment: nil
            )
            
            print("✅ Удобрение успешно выполнено для растения \(plantInstanceId)")
            
            // Ждем немного, чтобы сервер успел пересчитать данные об удобрении
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            // Обновляем данные
            await MainActor.run {
                isFertilizing = false
            }
            
            // Обновляем данные об удобрении
            await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
            
            // Отправляем уведомление об обновлении
            NotificationCenter.default.post(name: NSNotification.Name("NextFertilizingUpdated"), object: nil)
        } catch {
            print("❌ Ошибка удобрения: \(error)")
            await MainActor.run {
                isFertilizing = false
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Ошибка удобрения: \(error.localizedDescription)"
                }
            }
            // Снимаем блокировку в случае ошибки
            globalOperationLock.lock()
            activeOperations.remove(plantInstanceId)
            globalOperationLock.unlock()
            print("🔓 fertilizePlant: Блокировка снята после ошибки для растения \(plantInstanceId)")
        }
    }
}

// MARK: - Sensor Card View
struct SensorCardView: View {
    let greenhouse: GreenhouseOut
    let onDisconnect: () -> Void
    
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var bleManager = BLEManager()
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @State private var isDisconnecting = false
    @State private var errorMessage: String?
    
    // Проверяем, является ли пользователь администратором
    private var isAdmin: Bool {
        authManager.currentUser?.role == "admin"
    }
    
    // Название датчика (используем sensor_id или можно использовать имя теплицы)
    private var sensorName: String {
        if let sensorId = greenhouse.sensor_id {
            return "Датчик \(sensorId.prefix(8))"
        }
        return "Датчик"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя часть: иконка датчика, название датчика и теплицы
            HStack(spacing: 12) {
                // Иконка датчика
                ZStack {
                    Circle()
                        .fill(DesignColor.mainAccent.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColor.mainAccent)
                }
                
                // Название датчика и теплицы
                VStack(alignment: .leading, spacing: 4) {
                    Text(sensorName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(greenhouse.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Разделитель
            Divider()
                .background(Color.gray.opacity(0.2))
                .padding(.horizontal, 16)
            
            // Кнопка отключения (только для админа)
            if isAdmin {
                Button(action: {
                    Task {
                        await disconnectSensor()
                    }
                }) {
                    if isDisconnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Отключить")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignColor.mainRed)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(DesignColor.mainRed.opacity(0.1))
                .cornerRadius(10)
                .disabled(isDisconnecting)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            
            // Сообщение об ошибке
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(DesignColor.mainRed)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignColor.Fills.tertiar, lineWidth: 1.0)
        )
    }
    
    private func disconnectSensor() async {
        await MainActor.run {
            isDisconnecting = true
            errorMessage = nil
        }
        
        // Проверяем, нужно ли отключаться от устройства (до удаления соответствия)
        let savedBLEIdentifier = UserDefaults.standard.string(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
        var shouldDisconnect = false
        if let connectedDevice = bleManager.lastConnectedDevice,
           let savedBLE = savedBLEIdentifier {
            shouldDisconnect = connectedDevice.id.uuidString == savedBLE
            print("🔍 Проверка отключения: connectedDevice=\(connectedDevice.id.uuidString), savedBLE=\(savedBLE), shouldDisconnect=\(shouldDisconnect)")
        } else {
            print("🔍 Проверка отключения: connectedDevice=\(bleManager.lastConnectedDevice?.id.uuidString ?? "nil"), savedBLE=\(savedBLEIdentifier ?? "nil")")
        }
        
        do {
            // Отвязываем датчик от теплицы в БД
            try await APIService.shared.unbindSensorFromGreenhouse(greenhouseId: greenhouse.id)
            print("✅ Датчик успешно отвязан от теплицы в БД")
            
            // Отключаемся от устройства, если это датчик этой теплицы (до удаления соответствия)
            if shouldDisconnect {
                print("🔌 Отключаемся от устройства...")
                await MainActor.run {
                    bleManager.disconnect()
                }
                print("✅ Отключено от устройства")
            } else {
                print("ℹ️ Не отключаемся от устройства (это не датчик этой теплицы или устройство не подключено)")
            }
            
            // Удаляем сохраненное соответствие
            UserDefaults.standard.removeObject(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
            print("🗑️ Удалено соответствие из UserDefaults")
            
            // Очищаем данные датчика для этой теплицы
            await MainActor.run {
                sensorDataManager.clearSensorData(greenhouseId: greenhouse.id)
            }
            
            // Вызываем callback для обновления данных
            await MainActor.run {
                isDisconnecting = false
                onDisconnect()
            }
            
            // Отправляем уведомление об обновлении
            NotificationCenter.default.post(name: NSNotification.Name("GreenhouseUpdated"), object: nil)
        } catch {
            print("❌ Ошибка отвязки датчика: \(error)")
            await MainActor.run {
                isDisconnecting = false
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                    print("API Error detail: \(apiError.detail)")
                } else {
                    errorMessage = "Ошибка отвязки датчика: \(error.localizedDescription)"
                    print("General error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Summary Block View
enum SummaryTab: String, CaseIterable {
    case byGreenhouses = "По теплицам"
    case byWorkers = "По рабочим"
}

struct SummaryBlockView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @StateObject private var viewModel = SummaryViewModel()
    @State private var selectedTab: SummaryTab = .byGreenhouses
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок блока
            HStack(alignment: .center, spacing: 12) {
                Text("Сводка")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Переключатель вкладок
            CustomSegmentedControl(
                items: [
                    SegmentItem(title: "По теплицам", icon: "building.2", color: DesignColor.myDarkBlue),
                    SegmentItem(title: "По рабочим", icon: "person.2", color: DesignColor.myPerple)
                ],
                selection: $selectedTab
            )
            .padding(.horizontal)
            
            // Контент вкладок
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Загрузка данных...")
                        .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                switch selectedTab {
                case .byGreenhouses:
                    SummaryByGreenhousesView(viewModel: viewModel)
                case .byWorkers:
                    SummaryByWorkersView(viewModel: viewModel)
                }
            }
        }
        .task {
            // При первой загрузке загружаем данные для текущей вкладки
            await viewModel.loadData(for: selectedTab)
        }
        .onChange(of: selectedTab) { newTab in
            viewModel.resetPagination()
            // Загружаем данные только для новой вкладки, если они еще не загружены
            Task {
                await viewModel.loadDataIfNeeded(for: newTab)
            }
        }
    }
}

// MARK: - Summary ViewModel
@MainActor
class SummaryViewModel: ObservableObject {
    @Published var isLoading = false
    
    // Данные по теплицам
    @Published var allWateringEvents: [WaterEventOut] = []
    @Published var allFertilizingEvents: [WaterEventOut] = []
    @Published var allOverdueReports: [OverdueReportOut] = []
    @Published var allGreenhouses: [GreenhouseOut] = []
    @Published var allUsers: [String: UserOut] = [:] // userId -> UserOut
    @Published var allPlantTypes: [String: PlantTypeOut] = [:] // plant_type_id -> PlantTypeOut
    @Published var allPlantInstances: [String: PlantInstanceOut] = [:] // plant_instance_id -> PlantInstanceOut
    
    // Данные по рабочим
    @Published var allWorkers: [UserOut] = []
    @Published var workerEvents: [String: [WaterEventOut]] = [:] // userId -> [events]
    
    // Флаги загруженных данных
    private var greenhousesDataLoaded = false
    private var workersDataLoaded = false
    
    // Пагинация
    @Published var currentReportPage: Int = 1
    @Published var currentWorkerPage: Int = 1
    private let itemsPerPage = 10
    
    func loadData(for tab: SummaryTab? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        // Сбрасываем пагинацию при загрузке
        resetPagination()
        
        do {
            // Загружаем базовые данные параллельно
            async let greenhousesTask = APIService.shared.getGreenhouses()
            async let workersTask = APIService.shared.getWorkers()
            async let plantTypesTask = APIService.shared.getPlantTypes()
            
            // Ждем завершения базовых загрузок
            allGreenhouses = try await greenhousesTask
            allWorkers = try await workersTask
            let plantTypes = try await plantTypesTask
            allPlantTypes = Dictionary(uniqueKeysWithValues: plantTypes.map { ($0.id, $0) })
            
            // Создаем словарь пользователей
            var usersDict: [String: UserOut] = [:]
            for worker in allWorkers {
                usersDict[worker.id] = worker
            }
            if let currentUser = AuthManager.shared.currentUser {
                usersDict[currentUser.id] = currentUser
            }
            allUsers = usersDict
            
            // Загружаем данные в зависимости от вкладки
            if let tab = tab {
                // Загружаем только для текущей вкладки, если еще не загружено
                switch tab {
                case .byGreenhouses:
                    if !greenhousesDataLoaded {
                        await loadGreenhousesData()
                        greenhousesDataLoaded = true
                    }
                case .byWorkers:
                    if !workersDataLoaded {
                        await loadWorkersData()
                        workersDataLoaded = true
                    }
                }
            } else {
                // Загружаем для обеих вкладок параллельно, если еще не загружено
                if !greenhousesDataLoaded {
                    await loadGreenhousesData()
                    greenhousesDataLoaded = true
                }
                if !workersDataLoaded {
                    await loadWorkersData()
                    workersDataLoaded = true
                }
            }
            
            print("📊 SummaryViewModel: Загружено \(allWateringEvents.count) поливов, \(allFertilizingEvents.count) удобрений, \(allOverdueReports.count) отчетов")
        } catch {
            print("❌ SummaryViewModel: Ошибка загрузки данных: \(error)")
        }
    }
    
    // Загружает данные только если они еще не загружены (без установки isLoading)
    func loadDataIfNeeded(for tab: SummaryTab) async {
        // Проверяем, нужно ли загружать базовые данные
        let needsBaseData = allGreenhouses.isEmpty || allWorkers.isEmpty || allPlantTypes.isEmpty
        
        if needsBaseData {
            // Если базовых данных нет, загружаем все
            await loadData(for: tab)
            return
        }
        
        // Если базовые данные есть, загружаем только данные для вкладки, если нужно
        switch tab {
        case .byGreenhouses:
            if !greenhousesDataLoaded {
                await loadGreenhousesData()
                greenhousesDataLoaded = true
            }
        case .byWorkers:
            if !workersDataLoaded {
                await loadWorkersData()
                workersDataLoaded = true
            }
        }
    }
    
    // Загрузка данных для вкладки "По теплицам"
    private func loadGreenhousesData() async {
        // Загружаем события и отчеты параллельно
        async let wateringTask = APIService.shared.getWateringEvents()
        async let fertilizingTask = APIService.shared.getFertilizingEvents()
        async let overdueTask = APIService.shared.getOverdueReports()
        
        do {
            allWateringEvents = try await wateringTask
            allFertilizingEvents = try await fertilizingTask
            allOverdueReports = try await overdueTask
        } catch {
            print("❌ Ошибка загрузки данных по теплицам: \(error)")
        }
        
        // Загружаем растения только для тех теплиц, которые есть в событиях
        let greenhouseIdsInEvents = Set(
            (allWateringEvents + allFertilizingEvents).map { $0.greenhouse_id } +
            allOverdueReports.map { $0.greenhouse_id }
        )
        
        // Загружаем растения параллельно только для нужных теплиц
        await withTaskGroup(of: Void.self) { group in
            for greenhouseId in greenhouseIdsInEvents {
                group.addTask {
                    do {
                        let instances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouseId)
                        await MainActor.run {
                            for instance in instances {
                                self.allPlantInstances[instance.id] = instance
                            }
                        }
                    } catch {
                        print("❌ Ошибка загрузки растений для теплицы \(greenhouseId): \(error)")
                    }
                }
            }
        }
    }
    
    // Загрузка данных для вкладки "По рабочим"
    private func loadWorkersData() async {
        // Загружаем события по каждому рабочему параллельно
        await withTaskGroup(of: Void.self) { group in
            for worker in allWorkers {
                group.addTask {
                    do {
                        async let wateringTask = APIService.shared.getWateringEvents(userId: worker.id)
                        async let fertilizingTask = APIService.shared.getFertilizingEvents(userId: worker.id)
                        
                        let watering = try await wateringTask
                        let fertilizing = try await fertilizingTask
                        let events = (watering + fertilizing).sorted { $0.created_at > $1.created_at }
                        
                        await MainActor.run {
                            self.workerEvents[worker.id] = events
                        }
                    } catch {
                        print("❌ Ошибка загрузки событий для рабочего \(worker.id): \(error)")
                    }
                }
            }
        }
        
        // Загружаем растения только для тех теплиц, которые есть в событиях рабочих
        let greenhouseIdsInWorkerEvents = Set(
            workerEvents.values.flatMap { $0.map { $0.greenhouse_id } }
        )
        
        // Загружаем растения параллельно только для нужных теплиц
        await withTaskGroup(of: Void.self) { group in
            for greenhouseId in greenhouseIdsInWorkerEvents {
                // Проверяем, не загружены ли уже растения для этой теплицы
                if allPlantInstances.values.contains(where: { $0.greenhouse_id == greenhouseId }) {
                    continue
                }
                
                group.addTask {
                    do {
                        let instances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouseId)
                        await MainActor.run {
                            for instance in instances {
                                self.allPlantInstances[instance.id] = instance
                            }
                        }
                    } catch {
                        print("❌ Ошибка загрузки растений для теплицы \(greenhouseId): \(error)")
                    }
                }
            }
        }
    }
    
    // Объединенные события и отчеты для отображения по теплицам
    var allReportItems: [SummaryReportItem] {
        var items: [SummaryReportItem] = []
        
        // Добавляем события
        for event in (allWateringEvents + allFertilizingEvents) {
            items.append(.event(event))
        }
        
        // Добавляем отчеты о просрочках
        for report in allOverdueReports {
            items.append(.report(report))
        }
        
        // Сортируем по дате создания (новые сверху)
        return items.sorted { item1, item2 in
            item1.createdAt > item2.createdAt
        }
    }
    
    // Пагинированные элементы для отображения по теплицам
    var paginatedReportItems: [SummaryReportItem] {
        let all = allReportItems
        let startIndex = (currentReportPage - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, all.count)
        guard startIndex < all.count else { return [] }
        return Array(all[startIndex..<endIndex])
    }
    
    // Общее количество страниц (по теплицам)
    var totalReportPages: Int {
        let total = allReportItems.count
        return max(1, (total + itemsPerPage - 1) / itemsPerPage)
    }
    
    // Проверка, можно ли перейти на следующую страницу (по теплицам)
    var canGoToNextReportPage: Bool {
        currentReportPage < totalReportPages
    }
    
    // Проверка, можно ли перейти на предыдущую страницу (по теплицам)
    var canGoToPreviousReportPage: Bool {
        currentReportPage > 1
    }
    
    // Перейти на следующую страницу (по теплицам)
    func nextReportPage() {
        if canGoToNextReportPage {
            currentReportPage += 1
        }
    }
    
    // Перейти на предыдущую страницу (по теплицам)
    func previousReportPage() {
        if canGoToPreviousReportPage {
            currentReportPage -= 1
        }
    }
    
    // Все события рабочих (отсортированные)
    var allWorkerEventsSorted: [WaterEventOut] {
        return allWorkers.flatMap { worker in
            workerEvents[worker.id] ?? []
        }.sorted { $0.created_at > $1.created_at }
    }
    
    // Пагинированные события рабочих
    var paginatedWorkerEvents: [WaterEventOut] {
        let all = allWorkerEventsSorted
        let startIndex = (currentWorkerPage - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, all.count)
        guard startIndex < all.count else { return [] }
        return Array(all[startIndex..<endIndex])
    }
    
    // Общее количество страниц (по рабочим)
    var totalWorkerPages: Int {
        let total = allWorkerEventsSorted.count
        return max(1, (total + itemsPerPage - 1) / itemsPerPage)
    }
    
    // Проверка, можно ли перейти на следующую страницу (по рабочим)
    var canGoToNextWorkerPage: Bool {
        currentWorkerPage < totalWorkerPages
    }
    
    // Проверка, можно ли перейти на предыдущую страницу (по рабочим)
    var canGoToPreviousWorkerPage: Bool {
        currentWorkerPage > 1
    }
    
    // Перейти на следующую страницу (по рабочим)
    func nextWorkerPage() {
        if canGoToNextWorkerPage {
            currentWorkerPage += 1
        }
    }
    
    // Перейти на предыдущую страницу (по рабочим)
    func previousWorkerPage() {
        if canGoToPreviousWorkerPage {
            currentWorkerPage -= 1
        }
    }
    
    // Сброс пагинации при переключении вкладок
    func resetPagination() {
        currentReportPage = 1
        currentWorkerPage = 1
    }
    
    func getUserName(userId: String) -> String {
        return allUsers[userId]?.name ?? "Неизвестно"
    }
    
    func getUser(userId: String) -> UserOut? {
        return allUsers[userId]
    }
    
    func getPlantTypeName(plantInstanceId: String?) -> String {
        guard let plantInstanceId = plantInstanceId,
              let plantInstance = allPlantInstances[plantInstanceId],
              let plantType = allPlantTypes[plantInstance.plant_type_id] else {
            return "—"
        }
        return plantType.name
    }
    
    func getGreenhouseName(greenhouseId: String) -> String {
        return allGreenhouses.first(where: { $0.id == greenhouseId })?.name ?? "Неизвестно"
    }
}

// MARK: - Summary Report Item
enum SummaryReportItem: Identifiable {
    case event(WaterEventOut)
    case report(OverdueReportOut)
    
    var id: String {
        switch self {
        case .event(let event):
            return event.id
        case .report(let report):
            return report.id
        }
    }
    
    var createdAt: Date {
        switch self {
        case .event(let event):
            return parseSummaryDate(event.created_at) ?? Date()
        case .report(let report):
            return parseSummaryDate(report.created_at) ?? Date()
        }
    }
}

private func parseSummaryDate(_ dateString: String) -> Date? {
    var isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: dateString) { return date }
    
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: dateString) { return date }
    
    if dateString.contains("T") {
        let parts = dateString.split(separator: "T")
        guard parts.count == 2 else { return nil }
        
        let datePart = String(parts[0])
        var timePart = String(parts[1]).replacingOccurrences(of: "Z", with: "")
        
        if let dotIndex = timePart.firstIndex(of: ".") {
            timePart = String(timePart[..<dotIndex])
        }
        
        if !timePart.contains(":") {
            timePart = timePart.count == 1 ? "0\(timePart):00:00" : "\(timePart):00:00"
        } else {
            let components = timePart.split(separator: ":")
            if components.count == 2 {
                timePart = "\(timePart):00"
            }
        }
        
        let fixed = "\(datePart)T\(timePart)"
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        parser.locale = Locale(identifier: "en_US_POSIX")
        return parser.date(from: fixed)
    }
    
    return nil
}

// MARK: - Summary By Greenhouses View
struct SummaryByGreenhousesView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.allReportItems.isEmpty {
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
                ScrollView {
                    VStack(spacing: 0) {
                        // Заголовок таблицы
                        HStack(spacing: 0) {
                            Text("Тип")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Дата и время")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Детали")
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
                        
                        // Строки таблицы (пагинированные)
                        ForEach(viewModel.paginatedReportItems) { item in
                            switch item {
                            case .event(let event):
                                ReportRowView(
                                    event: event,
                                    userName: viewModel.getUserName(userId: event.user_id),
                                    plantTypeName: viewModel.getPlantTypeName(plantInstanceId: event.plant_instance_id),
                                    userId: event.user_id,
                                    user: viewModel.getUser(userId: event.user_id)
                                )
                                .environmentObject(bleManager)
                                .environmentObject(sensorDataManager)
                                .environmentObject(wateringDataManager)
                                .environmentObject(fertilizingDataManager)
                            case .report(let report):
                                OverdueReportRowView(report: report)
                            }
                        }
                        
                        // Навигация по страницам
                        HStack {
                            Button(action: {
                                viewModel.previousReportPage()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Назад")
                                }
                                .font(.subheadline)
                                .foregroundColor(viewModel.canGoToPreviousReportPage ? DesignColor.mainAccent : .gray)
                            }
                            .disabled(!viewModel.canGoToPreviousReportPage)
                            
                            Spacer()
                            
                            Text("Страница \(viewModel.currentReportPage) из \(viewModel.totalReportPages)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.nextReportPage()
                            }) {
                                HStack(spacing: 4) {
                                    Text("Вперед")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .foregroundColor(viewModel.canGoToNextReportPage ? DesignColor.mainAccent : .gray)
                            }
                            .disabled(!viewModel.canGoToNextReportPage)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Summary By Workers View
struct SummaryByWorkersView: View {
    @ObservedObject var viewModel: SummaryViewModel
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.allWorkers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Нет рабочих")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                if viewModel.allWorkerEventsSorted.isEmpty {
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
                    ScrollView {
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
                            
                            // Строки таблицы для всех рабочих (пагинированные)
                            ForEach(viewModel.paginatedWorkerEvents) { event in
                                WorkerReportRowView(
                                    event: event,
                                    greenhouseName: viewModel.getGreenhouseName(greenhouseId: event.greenhouse_id),
                                    plantTypeName: viewModel.getPlantTypeName(plantInstanceId: event.plant_instance_id),
                                    greenhouseId: event.greenhouse_id
                                )
                                .environmentObject(bleManager)
                                .environmentObject(sensorDataManager)
                                .environmentObject(wateringDataManager)
                                .environmentObject(fertilizingDataManager)
                            }
                            
                            // Навигация по страницам
                            HStack {
                                Button(action: {
                                    viewModel.previousWorkerPage()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Назад")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.canGoToPreviousWorkerPage ? DesignColor.mainAccent : .gray)
                                }
                                .disabled(!viewModel.canGoToPreviousWorkerPage)
                                
                                Spacer()
                                
                                Text("Страница \(viewModel.currentWorkerPage) из \(viewModel.totalWorkerPages)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.nextWorkerPage()
                                }) {
                                    HStack(spacing: 4) {
                                        Text("Вперед")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.canGoToNextWorkerPage ? DesignColor.mainAccent : .gray)
                                }
                                .disabled(!viewModel.canGoToNextWorkerPage)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .padding(.horizontal)
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


