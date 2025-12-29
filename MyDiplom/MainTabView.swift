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

// MARK: - Skeleton Components for Blocks
struct GreenhouseCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя часть: иконка, название
            HStack(spacing: 12) {
                SkeletonView(width: 60, height: 60, cornerRadius: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(width: 150, height: 18, cornerRadius: 4)
                    SkeletonView(width: 100, height: 14, cornerRadius: 4)
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
                HStack(spacing: 8) {
                    SkeletonView(width: 14, height: 14, cornerRadius: 7)
                    SkeletonView(width: 120, height: 16, cornerRadius: 4)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                HStack(spacing: 8) {
                    SkeletonView(width: 14, height: 14, cornerRadius: 7)
                    SkeletonView(width: 140, height: 16, cornerRadius: 4)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityHidden(true)
    }
}

struct SensorCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonView(width: 150, height: 20, cornerRadius: 4)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    SkeletonView(width: 100, height: 16, cornerRadius: 4)
                    Spacer()
                    SkeletonView(width: 60, height: 16, cornerRadius: 4)
                }
                HStack {
                    SkeletonView(width: 100, height: 16, cornerRadius: 4)
                    Spacer()
                    SkeletonView(width: 60, height: 16, cornerRadius: 4)
                }
                HStack {
                    SkeletonView(width: 100, height: 16, cornerRadius: 4)
                    Spacer()
                    SkeletonView(width: 60, height: 16, cornerRadius: 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityHidden(true)
    }
}

struct SummaryStatisticsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack {
                SkeletonView(width: 80, height: 20, cornerRadius: 4)
                Spacer()
                SkeletonView(width: 100, height: 32, cornerRadius: 8)
            }
            .padding(.horizontal)
            
            // Карточки статистики
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StatisticCardSkeleton()
                        StatisticCardSkeleton()
                    }
                    HStack(spacing: 12) {
                        StatisticCardSkeleton()
                        StatisticCardSkeleton()
                    }
                }
                .padding(.horizontal)
            }
        }
        .accessibilityHidden(true)
    }
}

struct StatisticCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView(width: 100, height: 14, cornerRadius: 4)
            SkeletonView(width: 60, height: 24, cornerRadius: 4)
            Spacer()
            HStack {
                Spacer()
                SkeletonView(width: 24, height: 24, cornerRadius: 12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityHidden(true)
    }
}

struct ReportsBlockSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack {
                SkeletonView(width: 80, height: 20, cornerRadius: 4)
                Spacer()
            }
            .padding(.horizontal)
            
            // Переключатель вкладок
            SkeletonView(width: nil, height: 40, cornerRadius: 8)
                .padding(.horizontal)
            
            // Контент
            VStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    ReportRowSkeleton()
                }
            }
            .padding(.horizontal)
        }
        .accessibilityHidden(true)
    }
}

struct ReportRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 60, height: 60, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(width: 150, height: 16, cornerRadius: 4)
                SkeletonView(width: 100, height: 14, cornerRadius: 4)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityHidden(true)
    }
}

struct WorkerReportSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок
            HStack {
                SkeletonView(width: 100, height: 20, cornerRadius: 4)
                Spacer()
            }
            .padding(.horizontal)
            
            // Таблица
            VStack(spacing: 0) {
                // Заголовок таблицы
                HStack(spacing: 0) {
                    ForEach(0..<4) { _ in
                        SkeletonView(width: nil, height: 16, cornerRadius: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                
                // Строки
                ForEach(0..<3) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<4) { _ in
                            SkeletonView(width: nil, height: 14, cornerRadius: 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MainTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var bleManager = BLEManager()
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @State private var selectedTab = 0
    @State private var navigateToGreenhouseId: String? = nil
    
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
            GreenhouseListView()
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
        .onAppear {
            // Настраиваем фон таб бара, чтобы он соответствовал системному фону
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemBackground
            tabBarAppearance.shadowColor = UIColor.separator
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToGreenhouse"))) { notification in
            // Обрабатываем навигацию к теплице из уведомления
            if let userInfo = notification.userInfo,
               let greenhouseId = userInfo["greenhouse_id"] as? String {
                print("📱 MainTabView: Навигация к теплице \(greenhouseId) из уведомления")
                
                // Переключаемся на вкладку "Теплицы"
                selectedTab = 2
                
                // Даем время TabView переключиться, затем устанавливаем навигацию
                Task { @MainActor in
                    // Небольшая задержка для переключения таба
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
                    
                    // Отправляем уведомление в GreenhouseListView для навигации
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToGreenhouseDetail"),
                        object: nil,
                        userInfo: ["greenhouse_id": greenhouseId]
                    )
                }
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
    @StateObject private var notificationStore = NotificationStore.shared
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var hasInitialLoadStarted = false
    
    // Состояния для отчета рабочего
    @State private var wateringEvents: [WaterEventOut] = []
    @State private var fertilizingEvents: [WaterEventOut] = []
    @State private var isLoadingReports = false
    @State private var greenhouses: [GreenhouseOut] = []
    @State private var plantInstances: [PlantInstanceOut] = []
    @State private var plantTypes: [String: PlantTypeOut] = [:]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 32) {
                        // Шапка с аватаром и приветствием
                        HStack(spacing: 12) {
                            if authManager.currentUser == nil {
                            // Skeleton для шапки
                            HStack(spacing: 12) {
                                SkeletonView(width: 56, height: 56, cornerRadius: 8)
                                SkeletonView(width: 200, height: 28, cornerRadius: 6)
                                Spacer()
                            }
                        } else {
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
                            
                            Text("Привет, \(authManager.currentUser?.name ?? "")!")
                                .font(.title2.bold())
                            
                            Spacer()
                            
                            // Кнопка уведомлений
                            Button(action: {
                                showNotifications = true
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                    
                                    // Бейдж с количеством непрочитанных
                                    if notificationStore.unreadCount > 0 {
                                        Text("\(notificationStore.unreadCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Блок "Сводка" - только для админа (выше всех блоков)
                    if authManager.currentUser?.role == "admin" {
                        SummaryStatisticsBlockView()
                            .environmentObject(manager)
                            .environmentObject(sensorDataManager)
                            .environmentObject(wateringDataManager)
                            .environmentObject(fertilizingDataManager)
                    }

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
                        if viewModel.isLoading || (!hasInitialLoadStarted && viewModel.greenhousesRequiringAttention.isEmpty) {
                            // Skeleton для блока "Требуют внимания"
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<2) { _ in
                                        GreenhouseCardSkeleton()
                                            .frame(width: 320)
                                    }
                                }
                                .padding(.horizontal)
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
                                GreenhouseCardWrapper(
                                    greenhouse: greenhouse,
                                    viewModel: viewModel,
                                    manager: manager,
                                    sensorDataManager: sensorDataManager,
                                    wateringDataManager: wateringDataManager,
                                    fertilizingDataManager: fertilizingDataManager
                                )
                            }
                            .padding(.horizontal)
                        } else {
                            // Горизонтальный скролл карточек для нескольких теплиц
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.greenhousesRequiringAttention, id: \.id) { greenhouse in
                                        GreenhouseCardWrapper(
                                            greenhouse: greenhouse,
                                            viewModel: viewModel,
                                            manager: manager,
                                            sensorDataManager: sensorDataManager,
                                            wateringDataManager: wateringDataManager,
                                            fertilizingDataManager: fertilizingDataManager
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
                        if viewModel.isLoading || (!hasInitialLoadStarted && viewModel.greenhousesWithSensors.isEmpty) {
                            // Skeleton для блока "Подключенные датчики"
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<2) { _ in
                                        SensorCardSkeleton()
                                            .frame(width: 320)
                                    }
                                }
                                .padding(.horizontal)
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
                            .padding(.vertical, 32)
                            .padding(.horizontal)
                        } else if viewModel.greenhousesWithSensors.count == 1 {
                            // Если один датчик - показываем на всю ширину с отступами
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
                    
                    // Блок "Отчеты" - для админа и рабочего (в одном месте)
                    if let user = authManager.currentUser {
                        if user.role == "admin" {
                            ReportsBlockView()
                                .environmentObject(manager)
                                .environmentObject(sensorDataManager)
                                .environmentObject(wateringDataManager)
                                .environmentObject(fertilizingDataManager)
                        } else if user.role == "worker" {
                            WorkerReportBlockView(
                                wateringEvents: $wateringEvents,
                                fertilizingEvents: $fertilizingEvents,
                                isLoadingReports: $isLoadingReports,
                                greenhouses: greenhouses,
                                plantInstances: plantInstances,
                                plantTypes: plantTypes
                            )
                            .environmentObject(manager)
                            .environmentObject(sensorDataManager)
                            .environmentObject(wateringDataManager)
                            .environmentObject(fertilizingDataManager)
                        }
                    }
                }
                .padding(.vertical, 32)
                .modifier(ScrollDismissesKeyboardModifier())
                .id("homeScroll_\(hasInitialLoadStarted ? "loaded" : "loading")")
                .modifier(ScrollDisabledModifier(isDisabled: viewModel.isLoading && !hasInitialLoadStarted))
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
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
                    .environmentObject(notificationStore)
                    .environmentObject(manager)
                    .environmentObject(sensorDataManager)
                    .environmentObject(wateringDataManager)
                    .environmentObject(fertilizingDataManager)
            }
            .task {
                if authManager.currentUser == nil {
                    await authManager.loadUserData()
                }
                hasInitialLoadStarted = true
                await viewModel.loadData(
                    bleManager: manager,
                    sensorDataManager: sensorDataManager,
                    wateringDataManager: wateringDataManager,
                    fertilizingDataManager: fertilizingDataManager
                )
                // Загружаем отчет для рабочего (параллельная загрузка теплиц и типов растений)
                if let user = authManager.currentUser, user.role == "worker" {
                    async let greenhousesTask = loadGreenhouses()
                    async let plantTypesTask = loadPlantTypes()
                    await greenhousesTask
                    await plantTypesTask
                    await loadReports()
                }
            }
            .refreshable {
                await viewModel.loadData(
                    bleManager: manager,
                    sensorDataManager: sensorDataManager,
                    wateringDataManager: wateringDataManager,
                    fertilizingDataManager: fertilizingDataManager
                )
                // Обновляем отчет для рабочего (параллельная загрузка теплиц и типов растений)
                if let user = authManager.currentUser, user.role == "worker" {
                    async let greenhousesTask = loadGreenhouses()
                    async let plantTypesTask = loadPlantTypes()
                    await greenhousesTask
                    await plantTypesTask
                    await loadReports()
                }
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
    
    // MARK: - Helper Methods for Worker Reports
    
    private func loadGreenhouses() async {
        // Для воркеров getGreenhouses() автоматически возвращает только их теплицы
        // Для админов getGreenhouses() возвращает все теплицы
        do {
            greenhouses = try await APIService.shared.getGreenhouses()
        } catch {
            print("❌ HomeView.loadGreenhouses: Ошибка загрузки теплиц: \(error)")
        }
    }
    
    private func loadPlantTypes() async {
        do {
            let allPlantTypes = try await APIService.shared.getPlantTypes()
            var typesDict: [String: PlantTypeOut] = [:]
            for plantType in allPlantTypes {
                typesDict[plantType.id] = plantType
            }
            plantTypes = typesDict
        } catch {
            print("❌ HomeView.loadPlantTypes: Ошибка загрузки типов растений: \(error)")
        }
    }
    
    private func loadReports() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoadingReports = true
        defer { isLoadingReports = false }
        
        do {
            // Параллельная загрузка событий полива и удобрения
            async let wateringTask = APIService.shared.getWateringEvents(userId: userId)
            async let fertilizingTask = APIService.shared.getFertilizingEvents(userId: userId)
            
            let (watering, fertilizing) = try await (wateringTask, fertilizingTask)
            
            wateringEvents = watering
            fertilizingEvents = fertilizing
            
            // Собираем уникальные ID теплиц из всех событий
            var uniqueGreenhouseIds = Set<String>()
            for event in watering {
                uniqueGreenhouseIds.insert(event.greenhouse_id)
            }
            for event in fertilizing {
                uniqueGreenhouseIds.insert(event.greenhouse_id)
            }
            
            // Параллельная загрузка теплиц из событий
            let allGreenhousesFromEvents = await withTaskGroup(of: GreenhouseOut?.self) { group in
                var loadedGreenhouses: [GreenhouseOut] = []
                
                for greenhouseId in uniqueGreenhouseIds {
                    group.addTask {
                        do {
                            return try await APIService.shared.getGreenhouse(id: greenhouseId)
                        } catch {
                            // Если теплица недоступна (403), пропускаем её
                            if let apiError = error as? APIError, !(apiError.detail.contains("доступа") || apiError.detail.contains("Access denied")) {
                                print("❌ HomeView.loadReports: Ошибка загрузки теплицы \(greenhouseId): \(error)")
                            }
                            return nil
                        }
                    }
                }
                
                for await greenhouse in group {
                    if let greenhouse = greenhouse {
                        loadedGreenhouses.append(greenhouse)
                    }
                }
                
                return loadedGreenhouses
            }
            
            // Объединяем текущие теплицы с теплицами из событий
            var allGreenhousesSet = Set(greenhouses.map { $0.id })
            for gh in allGreenhousesFromEvents {
                if !allGreenhousesSet.contains(gh.id) {
                    greenhouses.append(gh)
                    allGreenhousesSet.insert(gh.id)
                }
            }
            
            // Параллельная загрузка растений из всех теплиц
            let allPlantInstances = await withTaskGroup(of: [PlantInstanceOut].self) { group in
                var allInstances: [PlantInstanceOut] = []
                
                for greenhouse in greenhouses {
                    group.addTask {
                        do {
                            return try await APIService.shared.getPlantInstances(greenhouseId: greenhouse.id)
                        } catch {
                            print("❌ HomeView.loadReports: Ошибка загрузки растений для теплицы \(greenhouse.id): \(error)")
                            return []
                        }
                    }
                }
                
                for await instances in group {
                    allInstances.append(contentsOf: instances)
                }
                
                return allInstances
            }
            
            plantInstances = allPlantInstances
        } catch {
            print("❌ HomeView.loadReports: Ошибка загрузки отчетов: \(error)")
        }
    }
}

// MARK: - Home ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var greenhousesRequiringAttention: [GreenhouseOut] = []
    @Published var allGreenhouses: [GreenhouseOut] = [] {
        didSet {
            // Обновляем кэш при изменении списка теплиц
            _greenhousesWithSensors = nil
        }
    }
    @Published var isLoading = false
    
    // Кэшированный список теплиц с датчиками
    private var _greenhousesWithSensors: [GreenhouseOut]?
    
    // Получаем теплицы с привязанными датчиками (с кэшированием)
    var greenhousesWithSensors: [GreenhouseOut] {
        if let cached = _greenhousesWithSensors {
            return cached
        }
        let filtered = allGreenhouses.filter { greenhouse in
            guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
                return false
            }
            return true
        }
        _greenhousesWithSensors = filtered
        return filtered
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
            
            // Параллельная загрузка данных о поливах, удобрениях и датчиках для всех теплиц
            await withTaskGroup(of: Void.self) { group in
                for greenhouse in allGreenhouses {
                    group.addTask {
                        // Параллельная загрузка полива и удобрения для каждой теплицы
                        async let wateringTask = wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                        async let fertilizingTask = fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
                        
                        await wateringTask
                        await fertilizingTask
                        
                        // Регистрируем теплицу для отслеживания данных датчика (на главном акторе)
                        if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                            await MainActor.run {
                                sensorDataManager.registerGreenhouse(greenhouseId: greenhouse.id)
                            }
                            // loadSensorDataForGreenhouse автоматически выполнится на главном акторе
                            await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                        }
                    }
                }
            }
            
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
        // Используем compactMap для более эффективной фильтрации
        greenhousesRequiringAttention = allGreenhouses.compactMap { greenhouse in
            let nextWatering = wateringDataManager.getNextWatering(greenhouseId: greenhouse.id)
            let nextFertilizing = fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id)
            
            return requiresAttention(
                greenhouse: greenhouse,
                nextWatering: nextWatering,
                nextFertilizing: nextFertilizing
            ) ? greenhouse : nil
        }
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
                return true
            }
            // Полив требуется сегодня (days_until == 0)
            if let daysUntil = watering.days_until {
                if daysUntil == 0 {
                    return true
                }
            }
        }
        
        // Проверяем удобрение
        if let fertilizing = nextFertilizing {
            // Просроченное удобрение - всегда требует внимания
            if fertilizing.is_overdue {
                return true
            }
            // Удобрение требуется сегодня (days_until == 0)
            if let daysUntil = fertilizing.days_until {
                if daysUntil == 0 {
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

// MARK: - Greenhouse Card Wrapper (оптимизация вычислений)
struct GreenhouseCardWrapper: View {
    let greenhouse: GreenhouseOut
    let viewModel: HomeViewModel
    let manager: BLEManager
    let sensorDataManager: SensorDataManager
    let wateringDataManager: WateringDataManager
    let fertilizingDataManager: FertilizingDataManager
    
    // Вычисляем значения один раз
    private var nextWatering: NextWateringOut? {
        wateringDataManager.getNextWatering(greenhouseId: greenhouse.id)
    }
    
    private var nextFertilizing: NextWateringOut? {
        fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id)
    }
    
    private var sensorData: SensorReadingOut? {
        viewModel.getSensorDataForGreenhouse(greenhouse, bleManager: manager, sensorDataManager: sensorDataManager)
    }
    
    private var plantImageUrl: String? {
        viewModel.getPlantImageUrl(
            greenhouse: greenhouse,
            nextWatering: nextWatering,
            nextFertilizing: nextFertilizing
        )
    }
    
    var body: some View {
        FlatGreenhouseCardView(
            greenhouse: greenhouse,
            sensorData: sensorData,
            nextWatering: nextWatering,
            nextFertilizing: nextFertilizing,
            plantImageUrl: plantImageUrl
        )
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
                            SkeletonView(width: 60, height: 60, cornerRadius: 12)
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
                            .foregroundColor(.primary.opacity(0.8))
                        
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
                        .foregroundColor(.primary.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Text("Удобрение:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary.opacity(0.8))
                        
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
                            }
                            globalOperationLock.unlock()
                            
                            if isAlreadyActive {
                                return
                            }
                            
                            Task { @MainActor in
                                // Дополнительная проверка на MainActor
                                if isWatering || isFertilizing {
                                    globalOperationLock.lock()
                                    activeOperations.remove(plantInstanceId)
                                    globalOperationLock.unlock()
                                    return
                                }
                                isWatering = true
                                
                                await waterPlant()
                                
                                // Снимаем блокировку после завершения
                                globalOperationLock.lock()
                                activeOperations.remove(plantInstanceId)
                                globalOperationLock.unlock()
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
                            }
                            globalOperationLock.unlock()
                            
                            if isAlreadyActive {
                                return
                            }
                            
                            Task { @MainActor in
                                // Дополнительная проверка на MainActor
                                if isWatering || isFertilizing {
                                    globalOperationLock.lock()
                                    activeOperations.remove(plantInstanceId)
                                    globalOperationLock.unlock()
                                    return
                                }
                                isFertilizing = true
                                
                                await fertilizePlant()
                                
                                // Снимаем блокировку после завершения
                                globalOperationLock.lock()
                                activeOperations.remove(plantInstanceId)
                                globalOperationLock.unlock()
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
            await MainActor.run {
                isWatering = false
            }
            return
        }
        
        // Дополнительная проверка на случай, если флаг не был установлен в обработчике
        let shouldProceed = await MainActor.run {
            if isFertilizing {
                isWatering = false
                return false
            }
            if !isWatering {
                isWatering = true
            }
            errorMessage = nil
            return true
        }
        
        guard shouldProceed else {
            return
        }
        
        do {
            _ = try await APIService.shared.createWateringEvent(
                greenhouseId: greenhouse.id,
                plantInstanceId: plantInstanceId,
                type: "watering",
                comment: nil
            )
            
            // Ждем немного, чтобы сервер успел пересчитать данные о поливе
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда (как на экране теплицы)
            
            // Обновляем данные
            await MainActor.run {
                isWatering = false
            }
            
            // Обновляем данные о поливе для теплицы
            await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
            
            // Делаем еще одну попытку обновления через небольшую задержку
            // на случай, если сервер еще не успел пересчитать
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
            
            // Отправляем уведомления об обновлении
            NotificationCenter.default.post(name: NSNotification.Name("NextWateringUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("GreenhouseUpdated"), object: nil)
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
        }
    }
    
    private func fertilizePlant() async {
        guard let plantInstanceId = plantInstanceId else {
            await MainActor.run {
                isFertilizing = false
            }
            return
        }
        
        // Дополнительная проверка на случай, если флаг не был установлен в обработчике
        let shouldProceed = await MainActor.run {
            if isWatering {
                isFertilizing = false
                return false
            }
            if !isFertilizing {
                isFertilizing = true
            }
            errorMessage = nil
            return true
        }
        
        guard shouldProceed else {
            return
        }
        
        do {
            _ = try await APIService.shared.createWateringEvent(
                greenhouseId: greenhouse.id,
                plantInstanceId: plantInstanceId,
                type: "fertilizing",
                comment: nil
            )
            
            // Ждем немного, чтобы сервер успел пересчитать данные об удобрении
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда (как на экране теплицы)
            
            // Обновляем данные
            await MainActor.run {
                isFertilizing = false
            }
            
            // Обновляем данные об удобрении для теплицы
            await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
            
            // Делаем еще одну попытку обновления через небольшую задержку
            // на случай, если сервер еще не успел пересчитать
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
            
            // Отправляем уведомления об обновлении
            NotificationCenter.default.post(name: NSNotification.Name("NextFertilizingUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("GreenhouseUpdated"), object: nil)
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
    
    // Получаем данные датчика
    private var sensorData: SensorReadingOut? {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя часть: иконка датчика, название датчика и теплицы
            HStack(spacing: 12) {
                // Иконка датчика
                ZStack {
                    Circle()
                        .fill(DesignColor.mainAccent.opacity(0.1))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignColor.mainAccent)
                }
                
                // Название датчика и теплицы
                VStack(alignment: .leading, spacing: 4) {
                    Text(sensorName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(greenhouse.name)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    // Данные датчика (температура и влажность) под названием теплицы
                    if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "sensor")
                                .foregroundColor(DesignColor.myDarkBlue.opacity(0.8))
                                .font(.caption)
                            HStack(spacing: 8) {
                                Text(sensorData != nil ? String(format: "%.1f°C", sensorData!.temperature) : "--°C")
                                    .font(.caption)
                                    .foregroundColor(DesignColor.myDarkBlue.opacity(0.8))
                                
                                Text(sensorData != nil ? String(format: "%.0f%%", sensorData!.humidity) : "--%")
                                    .font(.caption)
                                    .foregroundColor(DesignColor.myDarkBlue.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DesignColor.myDarkBlue.opacity(0.1))
                        .cornerRadius(20)
                        .padding(.top, 4)
                    }
                }
                
                 Spacer()

                Button(action: {
                    Task {
                        await disconnectSensor()
                    }
                }) {
                    if isDisconnecting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Отключить")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(DesignColor.mainRed)
                    }
                }
                   .frame(maxWidth: 85)
                    .padding(.vertical, 6)
                    .background(DesignColor.mainRed.opacity(0.1))
                    .cornerRadius(8)
                    .disabled(isDisconnecting)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 8)        
                
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(DesignColor.mainRed)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignColor.Fills.tertiar, lineWidth: 1.0)
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SensorDataUpdated"))) { notification in
            // Обновляем UI при обновлении данных через глобальный менеджер
            // Данные уже обновлены в sensorDataManager, просто обновляем view
        }
        .onReceive(sensorDataManager.$sensorData) { _ in
            // Обновляем данные при изменении в глобальном менеджере
        }
        .onReceive(bleManager.$sensors) { _ in
            // Обновляем данные при изменении BLE данных
        }
        .onChange(of: bleManager.lastConnectedDevice?.id) { _ in
            // Обновляем данные при изменении подключенного устройства
        }
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
        }
        
        do {
            // Отвязываем датчик от теплицы в БД
            try await APIService.shared.unbindSensorFromGreenhouse(greenhouseId: greenhouse.id)
            
            // Отключаемся от устройства, если это датчик этой теплицы (до удаления соответствия)
            if shouldDisconnect {
                await MainActor.run {
                    bleManager.disconnect()
                }
            }
            
            // Удаляем сохраненное соответствие
            UserDefaults.standard.removeObject(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
            
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
                } else {
                    errorMessage = "Ошибка отвязки датчика: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Worker Report Block View (блок отчета рабочего)
struct WorkerReportBlockView: View {
    @Binding var wateringEvents: [WaterEventOut]
    @Binding var fertilizingEvents: [WaterEventOut]
    @Binding var isLoadingReports: Bool
    let greenhouses: [GreenhouseOut]
    let plantInstances: [PlantInstanceOut]
    let plantTypes: [String: PlantTypeOut]
    
    @EnvironmentObject var manager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок блока
            HStack(alignment: .center, spacing: 12) {
                Text("Мой отчет")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Индикатор загрузки
                if isLoadingReports {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            // Контент блока
            if isLoadingReports {
                // Skeleton для блока "Мой отчет"
                WorkerReportSkeleton()
            } else {
                let allEvents = (wateringEvents + fertilizingEvents).sorted { event1, event2 in
                    return event1.created_at > event2.created_at
                }
                
                if allEvents.isEmpty {
                    // Пустое состояние
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
                            
                            Text("Теплица")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Растение")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        
                        // Строки таблицы (показываем первые 5)
                        ForEach(Array(allEvents.prefix(5))) { event in
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
                        
                        // Кнопка "Показать все" если событий больше 5
                        if allEvents.count > 5 {
                            Button(action: {
                                // Можно добавить навигацию к полному отчету
                            }) {
                                Text("Показать все (\(allEvents.count))")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.mainAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func getGreenhouseName(greenhouseId: String) -> String {
        if let greenhouse = greenhouses.first(where: { $0.id == greenhouseId }) {
            return greenhouse.name
        }
        // Логируем только если не найдено (чтобы не засорять логи)
        if greenhouses.isEmpty {
            print("⚠️ WorkerReportBlockView.getGreenhouseName: Список теплиц пуст для id \(greenhouseId)")
        } else {
            print("⚠️ WorkerReportBlockView.getGreenhouseName: Теплица с id \(greenhouseId) не найдена. Всего теплиц: \(greenhouses.count)")
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
            } else {
                print("⚠️ WorkerReportBlockView.getPlantTypeName: Тип растения с id \(plantInstance.plant_type_id) не найден")
            }
        } else {
            print("⚠️ WorkerReportBlockView.getPlantTypeName: Экземпляр растения с id \(plantInstanceId) не найден")
        }
        
        return "—"
    }
}

// MARK: - Summary Statistics Block View (новый блок "Сводка")
struct SummaryStatisticsBlockView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @StateObject private var viewModel = SummaryViewModel()
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок блока с фильтром дат
            HStack(alignment: .center, spacing: 12) {
                Text("Сводка")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Фильтр по дате
                Button(action: {
                    showDatePicker = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(dateRangeText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.quaternarySystemFill))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // Контент (данные из SummaryGeneralView без фильтра)
            if viewModel.isLoading {
                SummaryStatisticsSkeleton()
            } else {
                SummaryGeneralView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DateFilterView(
                dateFrom: $viewModel.dateFrom,
                dateTo: $viewModel.dateTo,
                onApply: {
                    Task {
                        await viewModel.updateGeneralData()
                    }
                }
            )
        }
        .task {
            await viewModel.loadDataIfNeeded(for: .general)
        }
    }
    
    private var dateRangeText: String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let fromYear = calendar.component(.year, from: viewModel.dateFrom)
        let toYear = calendar.component(.year, from: viewModel.dateTo)
        
        // Показываем год, если выбран другой год или даты в разных годах
        let showYear = fromYear != currentYear || toYear != currentYear || fromYear != toYear
        
        let dateFormatter = DateFormatter()
        if showYear {
            dateFormatter.dateFormat = "dd.MM.yy"
        } else {
            dateFormatter.dateFormat = "dd.MM"
        }
        
        let fromString = dateFormatter.string(from: viewModel.dateFrom)
        let toString = dateFormatter.string(from: viewModel.dateTo)
        
        return "\(fromString) – \(toString)"
    }
}

// MARK: - Summary Tab Enum (для SummaryViewModel)
enum SummaryTab: String, CaseIterable {
    case general = "Общее"
    case byGreenhouses = "По теплицам"
    case byWorkers = "По рабочим"
}

// MARK: - Reports Block View (блок "Отчеты")
enum ReportsTab: String, CaseIterable {
    case byGreenhouses = "По теплицам"
    case byWorkers = "По рабочим"
}

struct ReportsBlockView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @StateObject private var viewModel = SummaryViewModel()
    @State private var selectedTab: ReportsTab = .byGreenhouses
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок блока
            HStack(alignment: .center, spacing: 12) {
                Text("Отчеты")
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
                ReportsBlockSkeleton()
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
            await viewModel.loadData(for: convertToSummaryTab(selectedTab))
        }
        .onChange(of: selectedTab) { newTab in
            viewModel.resetPagination()
            // Загружаем данные только для новой вкладки, если они еще не загружены
            Task {
                await viewModel.loadDataIfNeeded(for: convertToSummaryTab(newTab))
            }
        }
    }
    
    private func convertToSummaryTab(_ tab: ReportsTab) -> SummaryTab {
        switch tab {
        case .byGreenhouses:
            return .byGreenhouses
        case .byWorkers:
            return .byWorkers
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
    private var generalDataLoaded = false
    
    // Пагинация
    @Published var currentReportPage: Int = 1
    @Published var currentWorkerPage: Int = 1
    private let itemsPerPage = 10
    
    // Фильтр по дате для общей статистики (по умолчанию последние 7 дней)
    @Published var dateFrom: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -7, to: today) ?? today
    }()
    @Published var dateTo: Date = {
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date())
    }()
    
    // Статистика для вкладки "Общее"
    @Published var filteredWateringEvents: [WaterEventOut] = []
    @Published var filteredFertilizingEvents: [WaterEventOut] = []
    @Published var filteredOverdueReports: [OverdueReportOut] = []
    
    func loadData(for tab: SummaryTab? = nil) async {
        // Проверяем, не отменена ли задача
        guard !Task.isCancelled else { return }
        
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
            
            // Проверяем отмену после загрузки базовых данных
            guard !Task.isCancelled else { return }
            
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
                case .general:
                    await loadGeneralData()
                    generalDataLoaded = true
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
            
        } catch {
            // Игнорируем ошибку отмены - это нормальное поведение SwiftUI
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            // Проверяем, не отменена ли задача
            if Task.isCancelled {
                return
            }
            print("❌ SummaryViewModel: Ошибка загрузки данных: \(error)")
        }
    }
    
    // Загружает данные только если они еще не загружены (без установки isLoading)
    func loadDataIfNeeded(for tab: SummaryTab) async {
        // Проверяем, не отменена ли задача
        guard !Task.isCancelled else { return }
        
        // Проверяем, нужно ли загружать базовые данные
        let needsBaseData = allGreenhouses.isEmpty || allWorkers.isEmpty || allPlantTypes.isEmpty
        
        if needsBaseData {
            // Если базовых данных нет, загружаем все
            await loadData(for: tab)
            return
        }
        
        // Проверяем отмену перед загрузкой данных вкладки
        guard !Task.isCancelled else { return }
        
        // Если базовые данные есть, загружаем только данные для вкладки, если нужно
        switch tab {
        case .general:
            await loadGeneralData()
            generalDataLoaded = true
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
    
    // Загрузка данных для вкладки "Общее"
    func loadGeneralData() async {
        // Проверяем, не отменена ли задача
        guard !Task.isCancelled else { return }
        
        // Форматируем даты для API
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFromString = formatter.string(from: dateFrom)
        let dateToString = formatter.string(from: dateTo)
        
        // Загружаем события с фильтром по дате параллельно
        async let wateringTask = APIService.shared.getWateringEvents(dateFrom: dateFromString, dateTo: dateToString)
        async let fertilizingTask = APIService.shared.getFertilizingEvents(dateFrom: dateFromString, dateTo: dateToString)
        // Просрочки загружаем все (без фильтра по дате)
        async let overdueTask = APIService.shared.getOverdueReports()
        
        do {
            filteredWateringEvents = try await wateringTask
            filteredFertilizingEvents = try await fertilizingTask
            filteredOverdueReports = try await overdueTask
        } catch {
            // Игнорируем ошибку отмены - это нормальное поведение SwiftUI
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            // Проверяем, не отменена ли задача
            if Task.isCancelled {
                return
            }
            print("❌ Ошибка загрузки данных для общей статистики: \(error)")
        }
    }
    
    // Обновление данных при изменении фильтра
    func updateGeneralData() async {
        await loadGeneralData()
    }
    
    // Загрузка данных для вкладки "По теплицам"
    private func loadGreenhousesData() async {
        // Проверяем, не отменена ли задача
        guard !Task.isCancelled else { return }
        
        // Загружаем события и отчеты параллельно
        async let wateringTask = APIService.shared.getWateringEvents()
        async let fertilizingTask = APIService.shared.getFertilizingEvents()
        async let overdueTask = APIService.shared.getOverdueReports()
        
        do {
            allWateringEvents = try await wateringTask
            allFertilizingEvents = try await fertilizingTask
            allOverdueReports = try await overdueTask
        } catch {
            // Игнорируем ошибку отмены - это нормальное поведение SwiftUI
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            // Проверяем, не отменена ли задача
            if Task.isCancelled {
                return
            }
            print("❌ Ошибка загрузки данных по теплицам: \(error)")
            return
        }
        
        // Проверяем отмену перед загрузкой растений
        guard !Task.isCancelled else { return }
        
        // Загружаем растения только для тех теплиц, которые есть в событиях
        let greenhouseIdsInEvents = Set(
            (allWateringEvents + allFertilizingEvents).map { $0.greenhouse_id } +
            allOverdueReports.map { $0.greenhouse_id }
        )
        
        // Загружаем растения параллельно только для нужных теплиц
        await withTaskGroup(of: Void.self) { group in
            for greenhouseId in greenhouseIdsInEvents {
                group.addTask {
                    // Проверяем отмену перед каждой загрузкой
                    guard !Task.isCancelled else { return }
                    
                    do {
                        let instances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouseId)
                        await MainActor.run {
                            for instance in instances {
                                self.allPlantInstances[instance.id] = instance
                            }
                        }
                    } catch {
                        // Игнорируем ошибку отмены
                        if let urlError = error as? URLError, urlError.code == .cancelled {
                            return
                        }
                        if Task.isCancelled {
                            return
                        }
                        print("❌ Ошибка загрузки растений для теплицы \(greenhouseId): \(error)")
                    }
                }
            }
        }
    }
    
    // Загрузка данных для вкладки "По рабочим"
    private func loadWorkersData() async {
        // Проверяем, не отменена ли задача
        guard !Task.isCancelled else { return }
        
        // Загружаем события по каждому рабочему параллельно
        await withTaskGroup(of: Void.self) { group in
            for worker in allWorkers {
                group.addTask {
                    // Проверяем отмену перед каждой загрузкой
                    guard !Task.isCancelled else { return }
                    
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
                        // Игнорируем ошибку отмены
                        if let urlError = error as? URLError, urlError.code == .cancelled {
                            return
                        }
                        if Task.isCancelled {
                            return
                        }
                        print("❌ Ошибка загрузки событий для рабочего \(worker.id): \(error)")
                    }
                }
            }
        }
        
        // Проверяем отмену перед загрузкой растений
        guard !Task.isCancelled else { return }
        
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
                    // Проверяем отмену перед каждой загрузкой
                    guard !Task.isCancelled else { return }
                    
                    do {
                        let instances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouseId)
                        await MainActor.run {
                            for instance in instances {
                                self.allPlantInstances[instance.id] = instance
                            }
                        }
                    } catch {
                        // Игнорируем ошибку отмены
                        if let urlError = error as? URLError, urlError.code == .cancelled {
                            return
                        }
                        if Task.isCancelled {
                            return
                        }
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
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Заголовок таблицы
                        HStack(spacing: 0) {
                            Text("Тип")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)
                            
                            Text("Дата и время")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            
                            Text("Детали")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 150, alignment: .leading)
                            
                            Text("Тип растения")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 150, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                    }
                    // Минимальная ширина = сумма всех колонок (100 + 120 + 150 + 150) + отступы
                    .frame(minWidth: 520 + 32)
                }
                .padding(.top, 16)
            }
        }
    }
}

// MARK: - Summary General View
struct SummaryGeneralView: View {
    @ObservedObject var viewModel: SummaryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Карточки статистики
            ScrollView {
                VStack(spacing: 12) {
                    // Первая строка: Всего работников и Всего теплиц
                    HStack(spacing: 12) {
                        StatisticCardView(
                            title: "Всего рабочих",
                            value: "\(viewModel.allWorkers.count)",
                            icon: "person.2",
                            borderColor: DesignColor.myPerple
                        )
                        
                        StatisticCardView(
                            title: "Всего теплиц",
                            value: "\(viewModel.allGreenhouses.count)",
                            icon: "building.2",
                            borderColor: Color.green
                        )
                    }
                    
                    // Вторая строка: Выполнено поливов и Выполнено удобрений
                    HStack(spacing: 12) {
                        StatisticCardView(
                            title: "Всего поливов",
                            value: "\(viewModel.filteredWateringEvents.count)",
                            icon: "drop",
                            borderColor: DesignColor.myBlue
                        )
                        
                        StatisticCardView(
                            title: "Всего удобрений",
                            value: "\(viewModel.filteredFertilizingEvents.count)",
                            icon: "leaf",
                            borderColor: DesignColor.myBrown
                        )
                    }
                    
                    // Третья строка: Просрочки поливов (одна карточка на всю ширину, значение справа)
                    StatisticCardView(
                        title: "Всего просрочек",
                        value: "\(viewModel.filteredOverdueReports.count)",
                        icon: "exclamationmark.triangle",
                        borderColor: DesignColor.mainRed,
                        fillColor: DesignColor.mainRed.opacity(0.1),
                        isFullWidth: true,
                        valueOnRight: true
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .task {
            await viewModel.loadDataIfNeeded(for: .general)
        }
    }
}

// MARK: - Statistic Card View
struct StatisticCardView: View {
    let title: String
    let value: String
    let icon: String
    var borderColor: Color = DesignColor.mainAccent
    var fillColor: Color? = nil
    var isFullWidth: Bool = false
    var valueOnRight: Bool = false
    
    var body: some View {
        if valueOnRight {
            // Для карточки просрочек: значение справа
            HStack(alignment: .center, spacing: 12) {
                // Иконка и заголовок слева
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(borderColor.opacity(0.8))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(-0.4)
                }
                
                Spacer()
                
                // Значение справа
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.primary.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            //.background(fillColor ?? Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.tertiarySystemFill), lineWidth: 2)
            )
        } else {
            // Для остальных карточек: значение снизу
            VStack(alignment: .leading, spacing: 12) {
                // Иконка и заголовок
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(borderColor.opacity(0.8))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(-0.4)
                }
                
                // Значение
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.primary.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.tertiarySystemFill), lineWidth: 2)
            )
        }
    }
}

// MARK: - Date Filter View
struct DateFilterView: View {
    @Binding var dateFrom: Date
    @Binding var dateTo: Date
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Период")) {
                    DatePicker("От", selection: $dateFrom, displayedComponents: .date)
                    DatePicker("До", selection: $dateTo, displayedComponents: .date)
                }
            }
            .navigationTitle("Фильтр по дате")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
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
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Заголовок таблицы
                            HStack(spacing: 0) {
                                Text("Рабочий")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                
                                Text("Действие")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                
                                Text("Когда")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                                
                                Text("В какой теплице")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 150, alignment: .leading)
                                
                                Text("Тип растения")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 150, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            
                            // Строки таблицы для всех рабочих (пагинированные)
                            ForEach(viewModel.paginatedWorkerEvents) { event in
                                AdminWorkerReportRowView(
                                    event: event,
                                    workerName: viewModel.getUserName(userId: event.user_id),
                                    worker: viewModel.getUser(userId: event.user_id),
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                        }
                        // Минимальная ширина = сумма всех колонок (120 + 100 + 120 + 150 + 150) + отступы
                        .frame(minWidth: 640 + 32)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }
}

// MARK: - Admin Worker Report Row View (с ссылкой на рабочего)
struct AdminWorkerReportRowView: View {
    let event: WaterEventOut
    let workerName: String
    let worker: UserOut?
    let greenhouseName: String
    let plantTypeName: String
    let greenhouseId: String?
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    
    private var actionType: String {
        event.type == "watering" ? "Полив" : "Удобрение"
    }
    
    private var dateString: String {
        guard let date = parseDate(event.created_at) else {
            return event.created_at
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    private var timeString: String {
        guard let date = parseDate(event.created_at) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Пробуем ISO8601 форматы
        var isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) { return date }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) { return date }
        
        // Исправляем неполный формат "2025-11-25T2"
        if dateString.contains("T") {
            let parts = dateString.split(separator: "T")
            guard parts.count == 2 else { return nil }
            
            let datePart = String(parts[0])
            var timePart = String(parts[1]).replacingOccurrences(of: "Z", with: "")
            
            // Удаляем дробные секунды, если есть
            if let dotIndex = timePart.firstIndex(of: ".") {
                timePart = String(timePart[..<dotIndex])
            }
            
            // Исправляем неполное время
            if !timePart.contains(":") {
                timePart = timePart.count == 1 ? "0\(timePart):00:00" : "\(timePart):00:00"
            } else {
                let components = timePart.split(separator: ":")
                if components.count == 2 {
                    timePart = "\(timePart):00"
                }
            }
            
            // Парсим исправленную строку через DateFormatter
            let fixed = "\(datePart)T\(timePart)"
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            parser.locale = Locale(identifier: "en_US_POSIX")
            return parser.date(from: fixed)
        }
        
        return nil
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Рабочий с ссылкой
            if let worker = worker {
                NavigationLink(destination: WorkerProfileView(user: worker)
                    .environmentObject(bleManager)
                    .environmentObject(sensorDataManager)
                    .environmentObject(wateringDataManager)
                    .environmentObject(fertilizingDataManager)) {
                    Text(workerName)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(width: 120, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(workerName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(width: 120, alignment: .leading)
            }
            
            Text(actionType)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .leading)
            
            // Название теплицы с навигацией
            if let greenhouseId = greenhouseId {
                NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouseId)
                    .environmentObject(bleManager)
                    .environmentObject(sensorDataManager)
                    .environmentObject(wateringDataManager)
                    .environmentObject(fertilizingDataManager)) {
                    Text(greenhouseName)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(width: 150, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(greenhouseName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(width: 150, alignment: .leading)
            }
            
            Text(plantTypeName)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(width: 150, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
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

// MARK: - View Modifiers

struct ScrollDismissesKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.immediately)
        } else {
            content
        }
    }
}

struct ScrollDisabledModifier: ViewModifier {
    let isDisabled: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDisabled(isDisabled)
        } else {
            content
        }
    }
}
