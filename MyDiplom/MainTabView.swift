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

                    // Блок "Подключенные датчики"
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
                .padding(.vertical)
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
        
        // Проверяем, нужно ли отключаться от устройства
        let savedBLEIdentifier = UserDefaults.standard.string(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
        var shouldDisconnect = false
        if let connectedDevice = bleManager.lastConnectedDevice,
           let savedBLE = savedBLEIdentifier {
            shouldDisconnect = connectedDevice.id.uuidString == savedBLE
        }
        
        do {
            // Отвязываем датчик от теплицы в БД
            try await APIService.shared.unbindSensorFromGreenhouse(greenhouseId: greenhouse.id)
            print("✅ Датчик успешно отвязан от теплицы в БД")
            
            // Отключаемся от устройства, если это датчик этой теплицы
            if shouldDisconnect {
                await MainActor.run {
                    bleManager.disconnect()
                }
            }
            
            // Удаляем сохраненное соответствие
            UserDefaults.standard.removeObject(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
            
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
                } else {
                    errorMessage = "Ошибка отвязки датчика: \(error.localizedDescription)"
                }
            }
        }
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


