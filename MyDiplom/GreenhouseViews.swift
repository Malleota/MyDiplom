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
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
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
                            ForEach(viewModel.greenhouses, id: \.id) { greenhouse in
                                NavigationLink(destination: GreenhouseDetailView(greenhouseId: greenhouse.id)
                                    .environmentObject(bleManager)
                                    .environmentObject(sensorDataManager)) {
                                    GreenhouseCardView(
                                        greenhouse: greenhouse,
                                        sensorData: viewModel.getSensorDataForGreenhouse(greenhouse, bleManager: bleManager, sensorDataManager: sensorDataManager),
                                        nextWatering: wateringDataManager.getNextWatering(greenhouseId: greenhouse.id)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id("greenhouse_\(greenhouse.id)") // Стабильный идентификатор для предотвращения пересоздания
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
                // Загружаем данные о поливах для всех теплиц
                for greenhouse in viewModel.greenhouses {
                    await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                }
            }
            .refreshable {
                await viewModel.loadGreenhouses(bleManager: bleManager)
                // Обновляем данные о поливах для всех теплиц
                for greenhouse in viewModel.greenhouses {
                    await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GreenhouseUpdated"))) { _ in
                // НЕ обновляем список при обновлении данных датчика, чтобы не закрывать открытый экран
                // Данные датчиков обновляются через BLE в реальном времени, поэтому обновление списка не требуется
                // Если нужно обновить список (например, при добавлении/удалении теплицы), это делается вручную через pull-to-refresh
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SensorDataUpdated"))) { notification in
                // Обновляем UI при обновлении данных через глобальный менеджер
                // Данные уже обновлены в sensorDataManager, просто обновляем view
            }
            .onAppear {
                // Регистрируем экран, если есть теплицы с sensor_id
                checkAndRegisterScreen()
                // Данные о поливах обновляются через WebSocket/другой механизм, не при открытии экрана
            }
            .onDisappear {
                // Отменяем регистрацию экрана только если мы действительно выходим (не переходим на детальный экран)
                // В NavigationView список остается активным при переходе на детальный экран,
                // поэтому onDisappear вызывается только при полном выходе из NavigationView
                if isScreenRegistered {
                    sensorDataManager.unregisterActiveScreen()
                    isScreenRegistered = false
                }
            }
            .onChange(of: viewModel.greenhouses) { newGreenhouses in
                // Проверяем и регистрируем экран при изменении списка теплиц
                checkAndRegisterScreen()
                // Регистрируем теплицы с sensor_id для отслеживания через WebSocket
                Task {
                    for greenhouse in newGreenhouses {
                        if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty, isScreenRegistered {
                            sensorDataManager.registerGreenhouse(greenhouseId: greenhouse.id)
                            await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextWateringUpdated"))) { _ in
                // Обновляем UI при обновлении данных о поливах
            }
            // Данные о поливах обновляются автоматически на бэкенде после создания события полива
        }
    }
    
    @State private var isScreenRegistered = false
    
    private func checkAndRegisterScreen() {
        // Регистрируем экран, если есть теплицы с sensor_id
        let hasSensors = viewModel.greenhouses.contains { greenhouse in
            guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
                return false
            }
            return true
        }
        if hasSensors && !isScreenRegistered {
            sensorDataManager.registerActiveScreen()
            isScreenRegistered = true
            
            // Регистрируем все теплицы с sensor_id для отслеживания
            for greenhouse in viewModel.greenhouses {
                if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                    sensorDataManager.registerGreenhouse(greenhouseId: greenhouse.id)
                    // Загружаем начальные данные
                    Task {
                        await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                    }
                }
            }
        } else if !hasSensors && isScreenRegistered {
            sensorDataManager.unregisterActiveScreen()
            isScreenRegistered = false
        }
    }
}

// MARK: - Greenhouse Card View

struct GreenhouseCardView: View {
    let greenhouse: GreenhouseOut
    let sensorData: SensorReadingOut?
    let nextWatering: NextWateringOut?
    
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
                    if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                        // Датчик подключен - показываем данные или "--"
                        HStack(spacing: 12) {
                            Label(
                                sensorData != nil ? String(format: "%.1f°C", sensorData!.temperature) : "--°C",
                                systemImage: "thermometer"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            Label(
                                sensorData != nil ? String(format: "%.0f%%", sensorData!.humidity) : "--%",
                                systemImage: "humidity"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Время до следующего полива
                    if let nextWatering = nextWatering {
                        if let daysUntil = nextWatering.days_until {
                            // Есть интервал, показываем дни до следующего полива
                            if nextWatering.is_overdue {
                                Label("Полив просрочен на \(abs(daysUntil)) дн.", systemImage: "drop.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            } else if daysUntil == 0 {
                                Label("Полив сегодня", systemImage: "drop.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            } else {
                                Label("Полив через \(daysUntil) дн.", systemImage: "drop.fill")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.mainAccent)
                            }
                        } else if let lastWateringDate = nextWatering.next_watering_date {
                            // Нет интервала, но есть дата последнего полива (полив по всей теплице)
                            // Показываем дату последнего полива
                            Label("Последний полив: \(formatDate(lastWateringDate))", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            // Нет данных о поливе
                            Label("Полив не запланирован", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("Загрузка...", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
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
    @Published var isLoading = false
    
    func loadGreenhouses(bleManager: BLEManager? = nil, forceReload: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedGreenhouses = try await APIService.shared.getGreenhouses()
            print("📥 loadGreenhouses: Загружено \(fetchedGreenhouses.count) теплиц")
            
            // Если это не принудительная перезагрузка, обновляем только измененные теплицы
            // чтобы не пересоздавать NavigationLink и не закрывать открытый экран
            if !forceReload && !greenhouses.isEmpty {
                // Обновляем только измененные теплицы, сохраняя порядок
                var updatedGreenhouses = greenhouses
                var hasChanges = false
                
                for (index, oldGreenhouse) in updatedGreenhouses.enumerated() {
                    if let newGreenhouse = fetchedGreenhouses.first(where: { $0.id == oldGreenhouse.id }) {
                        // Проверяем, изменилась ли теплица
                        if oldGreenhouse.sensor_id != newGreenhouse.sensor_id ||
                           oldGreenhouse.name != newGreenhouse.name {
                            updatedGreenhouses[index] = newGreenhouse
                            hasChanges = true
                        }
                    } else {
                        // Теплица была удалена
                        hasChanges = true
                    }
                }
                
                // Проверяем, есть ли новые теплицы
                let oldIds = Set(greenhouses.map { $0.id })
                let newIds = Set(fetchedGreenhouses.map { $0.id })
                if oldIds != newIds {
                    hasChanges = true
                }
                
                if hasChanges {
                    // Если есть изменения, обновляем список
                    greenhouses = fetchedGreenhouses
                } else {
                    // Если изменений нет, обновляем только данные внутри существующих теплиц
                    greenhouses = updatedGreenhouses
                }
            } else {
                // При первой загрузке или принудительной перезагрузке обновляем полностью
                greenhouses = fetchedGreenhouses
            }
            
            // Собираем все ble_identifier датчиков, привязанных к теплицам
            var boundSensorIdentifiers: [String] = []
            for greenhouse in greenhouses {
                if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                    // Получаем сохраненный ble_identifier для этой теплицы
                    if let bleIdentifier = UserDefaults.standard.string(forKey: "greenhouse_\(greenhouse.id)_ble_identifier") {
                        boundSensorIdentifiers.append(bleIdentifier)
                        print("📋 Найден привязанный датчик для теплицы \(greenhouse.name): \(bleIdentifier)")
                    }
                }
            }
            
            // Обновляем список привязанных датчиков в BLEManager
            if let bleManager = bleManager {
                bleManager.updateBoundSensors(boundSensorIdentifiers)
            }
            
            // Данные датчиков будут браться из BLE через getSensorDataForGreenhouse
            // или из глобального SensorDataManager, который обновляет их автоматически
            // Регистрация экрана происходит в View через onChange
        } catch {
            print("❌ Ошибка загрузки теплиц: \(error)")
        }
    }
    
    func getSensorDataForGreenhouse(_ greenhouse: GreenhouseOut, bleManager: BLEManager, sensorDataManager: SensorDataManager) -> SensorReadingOut? {
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
                print("📡 Используем данные из BLE для теплицы \(greenhouse.name) (совпадение по ble_identifier)")
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
                print("📡 Используем данные из BLE для теплицы \(greenhouse.name) (нет сохраненного ble_identifier)")
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
        
        // Если данных нет, но sensor_id есть, загружаем с сервера асинхронно через глобальный менеджер
        Task {
            await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
        }
        
        // Возвращаем nil, данные будут загружены асинхронно
        return nil
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
                    .foregroundColor(DesignColor.mainAccent)
                
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
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @State private var greenhouse: GreenhouseOut?
    @State private var sensorData: SensorReadingOut?
    @State private var isLoading = true
    @State private var showDeviceList = false
    @State private var isBinding = false
    @State private var isUnbinding = false
    @State private var errorMessage: String?
    @State private var isScreenRegistered = false
    @State private var plantInstances: [PlantInstanceOut] = []
    @State private var plantTypes: [String: PlantTypeOut] = [:] // plant_type_id -> PlantTypeOut
    @State private var plantWaterings: [String: NextWateringOut] = [:] // plant_instance_id -> NextWateringOut
    @State private var isLoadingPlants = false
    
    // Отсортированный список растений по поливу
    private var sortedPlantInstances: [PlantInstanceOut] {
        plantInstances.sorted { plant1, plant2 in
            let watering1 = plantWaterings[plant1.id]
            let watering2 = plantWaterings[plant2.id]
            
            // Если у обоих есть данные о поливе
            if let w1 = watering1, let w2 = watering2 {
                // Просроченные поливы - вверху
                if w1.is_overdue && !w2.is_overdue {
                    return true
                }
                if !w1.is_overdue && w2.is_overdue {
                    return false
                }
                
                // Если оба просрочены, сортируем по количеству дней просрочки (больше = выше)
                if w1.is_overdue && w2.is_overdue {
                    let days1 = abs(w1.days_until ?? Int.max)
                    let days2 = abs(w2.days_until ?? Int.max)
                    return days1 > days2
                }
                
                // Полив сегодня (days_until == 0) - после просроченных
                if let days1 = w1.days_until, let days2 = w2.days_until {
                    if days1 == 0 && days2 != 0 {
                        return true
                    }
                    if days1 != 0 && days2 == 0 {
                        return false
                    }
                    // Оба имеют days_until, сортируем по возрастанию
                    return days1 < days2
                }
                
                // Если у одного есть days_until, а у другого нет
                if w1.days_until != nil && w2.days_until == nil {
                    return true
                }
                if w1.days_until == nil && w2.days_until != nil {
                    return false
                }
            }
            
            // Если только у первого есть данные о поливе
            if watering1 != nil && watering2 == nil {
                return true
            }
            
            // Если только у второго есть данные о поливе
            if watering1 == nil && watering2 != nil {
                return false
            }
            
            // Если у обоих нет данных, сохраняем исходный порядок
            return false
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Загрузка...")
            } else if let greenhouse = greenhouse {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Заголовок: Название и описание с картинкой
                        HStack(alignment: .top, spacing: 12) {
                            // Вертикальный контейнер с названием и описанием
                            VStack(alignment: .leading, spacing: 0) {
                                Text(greenhouse.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                if let description = greenhouse.description {
                                    Text(description)
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Картинка справа
                            if let imageUrl = greenhouse.image_url, let url = URL(string: imageUrl) {
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
                                        Image(systemName: "building.2.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 24))
                                    )
                            }
                        }
                        .padding(8)
                        .padding(.horizontal)
                        
                        // Блок "Текущие данные"
                        VStack(alignment: .leading, spacing: 16) {
                          //  Text("Текущие данные")
                               // .font(.headline)
                               // .padding(.horizontal)
                            
                            if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                                // Датчик подключен (sensor_id не пустой)
                                VStack( spacing: 16) {
                                    // Название датчика, батарея и кнопка отвязать
                                    HStack {
                                        Text("Текущие данные")
                                            .font(.title3)
                                            .fontWeight(.semibold)

                                        Spacer()
                                        
                                        // Батарея из BLE данных, если доступна
                                        if let connectedDevice = bleManager.lastConnectedDevice,
                                           let bleSensorData = bleManager.sensors[connectedDevice.id] {
                                            HStack(spacing: 4) {
                                                Image(systemName: "battery.100")
                                                    .foregroundColor(batteryColor(bleSensorData.batteryPercent))
                                                Text("\(bleSensorData.batteryPercent)%")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // Кнопка отвязать
                                        Button(action: {
                                            Task {
                                                await unbindSensor()
                                            }
                                        }) {
                                            if isUnbinding {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            } else {
                                                Text("Отключить")
                                                    .font(.caption)
                                                    .foregroundColor(DesignColor.mainRed.opacity(0.8))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(DesignColor.mainRed.opacity(0.1))
                                        .cornerRadius(40)
                                        .disabled(isUnbinding)
                                    }
                                    .padding(.horizontal)
                                    
                                    // Две карточки: температура и влажность
                                    HStack(spacing: 12) {
                                        // Карточка температуры
                                        SensorDataCard(
                                            icon: "thermometer",
                                            title: "Температура",
                                            value: sensorData != nil ? String(format: "%.1f", sensorData!.temperature) : "--",
                                            unit: "°C"
                                        )
                                        
                                        // Карточка влажности
                                        SensorDataCard(
                                            icon: "drop.fill",
                                            title: "Влажность",
                                            value: sensorData != nil ? String(format: "%.0f", sensorData!.humidity) : "--",
                                            unit: "%"
                                        )
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                // Датчик не подключен
                                VStack(spacing: 16) {
                                    // Карточка подключения датчика
                                    HStack(alignment: .center) {
                                        HStack(alignment: .center, spacing: 8) {
                                            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                                .font(.subheadline)
                                            Text("Подключить датчик")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .tracking(-0.5)
                                                .lineSpacing(15)
                                        }
                                        
                                        Spacer()

                                        Button(action: {
                                            bleManager.startScan(disableAutoConnect: true)
                                            showDeviceList = true
                                        }) {
                                            if isBinding {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            } else {
                                                Text("Подключить")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .tracking(-0.5)
                                                    .lineSpacing(15)
                                                    .foregroundColor(DesignColor.mainAccent)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(DesignColor.mainAccent.opacity(0.1))
                                        .cornerRadius(40)
                                        .disabled(isUnbinding)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(DesignColor.Fills.tertiar, lineWidth: 1.0)
                                    )
                                    .padding(.horizontal)
                                    
                                    if let error = errorMessage {
                                        Text(error)
                                            .font(.footnote)
                                            .foregroundColor(DesignColor.mainRed)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    
                                    if isBinding {
                                        ProgressView("Привязка датчика...")
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        
                        // Список растений
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Растения")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            if isLoadingPlants {
                                ProgressView("Загрузка растений...")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if plantInstances.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Нет растений")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(sortedPlantInstances) { plantInstance in
                                        PlantCardView(
                                            plantInstance: plantInstance,
                                            plantType: plantTypes[plantInstance.plant_type_id],
                                            nextWatering: plantWaterings[plantInstance.id]
                                        )
                                    }
                                }
                                .padding(.horizontal)
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
        .navigationBarTitleDisplayMode(.inline)
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
            await loadPlants()
        }
        // Данные о поливах обновляются через WebSocket/другой механизм, не при открытии экрана
        .onChange(of: bleManager.lastConnectedDevice?.id) { _ in
            // Обновляем данные при изменении подключенного устройства
            updateSensorDataFromBLE()
        }
        .onReceive(bleManager.$sensors) { _ in
            // Обновляем данные при изменении BLE данных
            updateSensorDataFromBLE()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SensorDataUpdated"))) { notification in
            // Обновляем данные при обновлении через глобальный менеджер
            if let userInfo = notification.userInfo,
               let greenhouseId = userInfo["greenhouse_id"] as? String,
               greenhouseId == self.greenhouseId,
               let updatedData = userInfo["sensor_data"] as? SensorReadingOut {
                sensorData = updatedData
            }
        }
        .onReceive(sensorDataManager.$sensorData) { _ in
            // Обновляем данные при изменении в глобальном менеджере
            updateSensorDataFromManager()
        }
        // Данные о поливах обновляются автоматически на бэкенде после создания события полива
        .onChange(of: greenhouse?.sensor_id) { newSensorId in
            // Обновляем регистрацию при изменении sensor_id
            if let sensorId = newSensorId, !sensorId.isEmpty {
                if !isScreenRegistered {
                    sensorDataManager.registerActiveScreen()
                    isScreenRegistered = true
                }
                // Регистрируем теплицу для отслеживания через WebSocket
                if let greenhouse = greenhouse {
                    sensorDataManager.registerGreenhouse(greenhouseId: greenhouse.id)
                    Task {
                        await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                    }
                }
            } else {
                if isScreenRegistered {
                    sensorDataManager.unregisterActiveScreen()
                    isScreenRegistered = false
                }
                // Отменяем регистрацию теплицы
                if let greenhouse = greenhouse {
                    sensorDataManager.unregisterGreenhouse(greenhouseId: greenhouse.id)
                }
            }
        }
        .onDisappear {
            // Отменяем регистрацию экрана
            if isScreenRegistered {
                sensorDataManager.unregisterActiveScreen()
                isScreenRegistered = false
            }
            // Отменяем регистрацию теплицы
            if let greenhouse = greenhouse {
                sensorDataManager.unregisterGreenhouse(greenhouseId: greenhouse.id)
            }
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
    
    private func loadPlants() async {
        isLoadingPlants = true
        defer { isLoadingPlants = false }
        
        do {
            // Загружаем список растений
            let instances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouseId)
            await MainActor.run {
                plantInstances = instances
            }
            
            // Загружаем данные о поливе для каждого растения
            let waterings = try await APIService.shared.getNextWateringForPlants(greenhouseId: greenhouseId)
            var wateringDict: [String: NextWateringOut] = [:]
            for watering in waterings {
                if let plantInstanceId = watering.plant_instance_id {
                    wateringDict[plantInstanceId] = watering
                }
            }
            await MainActor.run {
                plantWaterings = wateringDict
            }
            
            // Загружаем информацию о типах растений
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
        } catch {
            print("❌ Ошибка загрузки растений: \(error)")
        }
    }
    
    private func loadGreenhouse() async {
        do {
            let fetched = try await APIService.shared.getGreenhouse(id: greenhouseId)
            print("📥 loadGreenhouse: Загружена теплица \(fetched.name), sensor_id=\(fetched.sensor_id ?? "nil")")
            await MainActor.run {
                greenhouse = fetched
            }
            
            // Регистрация экрана произойдет автоматически через onChange(of: greenhouse?.sensor_id)
            // при установке значения greenhouse
            
            // Обновляем данные датчика из BLE, если он подключен, или загружаем с сервера
            var hasSensorData = false
            await MainActor.run {
                updateSensorDataFromBLE()
                hasSensorData = sensorData != nil
            }
            
            // Обновляем данные из глобального менеджера
            updateSensorDataFromManager()
            
            // Если BLE данные недоступны, но есть sensor_id, загружаем данные с сервера через глобальный менеджер
            if let sensorId = fetched.sensor_id,
               !sensorId.isEmpty,
               !hasSensorData {
                await sensorDataManager.loadSensorDataForGreenhouse(fetched)
                updateSensorDataFromManager()
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
    
    private func loadSensorDataFromServer() async {
        guard let greenhouse = greenhouse,
              let sensorId = greenhouse.sensor_id,
              !sensorId.isEmpty else {
            return
        }
        
        // Используем глобальный менеджер для загрузки данных
        await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
        updateSensorDataFromManager()
    }
    
    private func updateSensorDataFromManager() {
        guard let greenhouse = greenhouse else { return }
        
        // Получаем данные из глобального менеджера
        if let managerData = sensorDataManager.getSensorData(greenhouseId: greenhouse.id) {
            sensorData = managerData
        }
    }
    
    private func updateSensorDataFromBLE() {
        guard let greenhouse = greenhouse,
              let sensorId = greenhouse.sensor_id,
              !sensorId.isEmpty else {
            // Если нет sensor_id, очищаем данные
            sensorData = nil
            return
        }
        
        // Проверяем, есть ли подключенное устройство и данные BLE
        guard let connectedDevice = bleManager.lastConnectedDevice,
              let bleSensorData = bleManager.sensors[connectedDevice.id] else {
            // Если BLE не подключен, не очищаем данные (они могут быть загружены с сервера)
            // Только если данных вообще нет, попробуем загрузить с сервера
            if sensorData == nil {
                Task {
                    await loadSensorDataFromServer()
                }
            }
            return
        }
        
        // Проверяем, совпадает ли UUID подключенного устройства с ble_identifier датчика этой теплицы
        let connectedDeviceUUID = connectedDevice.id.uuidString
        
        // Получаем сохраненный ble_identifier для этой теплицы
        let savedBLEIdentifier = UserDefaults.standard.string(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
        
        // Если есть сохраненный ble_identifier и он совпадает с подключенным устройством
        if let savedBLE = savedBLEIdentifier, savedBLE == connectedDeviceUUID {
            // Используем данные из BLE
            print("📡 updateSensorDataFromBLE: Обновляем данные из BLE для теплицы \(greenhouse.name) (совпадение по ble_identifier)")
            sensorData = SensorReadingOut(
                id: "",
                sensor_id: greenhouse.sensor_id ?? "",
                greenhouse_id: greenhouse.id,
                temperature: bleSensorData.temperature,
                humidity: bleSensorData.humidity,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
        } else if savedBLEIdentifier == nil {
            // Если нет сохраненного ble_identifier, но устройство подключено
            // Предполагаем, что это тот же датчик (для обратной совместимости)
            print("📡 updateSensorDataFromBLE: Обновляем данные из BLE для теплицы \(greenhouse.name) (нет сохраненного ble_identifier)")
            sensorData = SensorReadingOut(
                id: "",
                sensor_id: greenhouse.sensor_id ?? "",
                greenhouse_id: greenhouse.id,
                temperature: bleSensorData.temperature,
                humidity: bleSensorData.humidity,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
        } else {
            // Если ble_identifier не совпадает, не используем BLE данные
            // Но не очищаем sensorData, так как данные могут быть с сервера
            print("⚠️ updateSensorDataFromBLE: UUID не совпадает для теплицы \(greenhouse.name) (saved: \(savedBLEIdentifier ?? "nil"), connected: \(connectedDeviceUUID))")
            // Если данных нет, попробуем загрузить с сервера
            if sensorData == nil {
                Task {
                    await loadSensorDataFromServer()
                }
            }
        }
    }
    
    private func unbindSensor() async {
        guard let greenhouse = greenhouse else { return }
        
        await MainActor.run {
            isUnbinding = true
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
            
            // Обновляем данные теплицы
            await loadGreenhouse()
            
            // Отменяем регистрацию экрана, так как sensor_id был удален
            await MainActor.run {
                if let sensorId = greenhouse.sensor_id, !sensorId.isEmpty {
                    // Если sensor_id все еще есть (не должен быть), оставляем регистрацию
                } else {
                    sensorDataManager.unregisterActiveScreen()
                }
            }
            
            // НЕ отправляем уведомление для обновления списка, чтобы не закрывать открытый экран
            // Данные обновляются локально через loadGreenhouse()
            
            await MainActor.run {
                isUnbinding = false
            }
            
            // НЕ закрываем экран - остаемся на странице теплицы
        } catch {
            print("❌ Ошибка отвязки датчика: \(error)")
            await MainActor.run {
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                    print("API Error detail: \(apiError.detail)")
                } else {
                    errorMessage = "Ошибка отвязки датчика: \(error.localizedDescription)"
                    print("General error: \(error.localizedDescription)")
                }
                isUnbinding = false
            }
        }
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
            
            // Сохраняем соответствие между теплицей и ble_identifier
            let bleIdentifier = device.id.uuidString
            UserDefaults.standard.set(bleIdentifier, forKey: "greenhouse_\(greenhouseId)_ble_identifier")
            print("💾 Сохранено соответствие: greenhouse_\(greenhouseId) -> \(bleIdentifier)")
            
            // Подключаемся к устройству через BLE
            print("Подключение к устройству через BLE...")
            await MainActor.run {
                bleManager.connect(to: device)
            }
            
            // Ждем немного, чтобы подключение установилось
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            
            // Успешно привязано и подключено, обновляем данные теплицы
            await loadGreenhouse()
            
            // Регистрация экрана произойдет автоматически через loadGreenhouse при наличии sensor_id
            // (loadGreenhouse уже зарегистрирует экран, но на всякий случай)
            
            // НЕ отправляем уведомление для обновления списка, чтобы не закрывать открытый экран
            // Данные обновляются локально через loadGreenhouse()
            
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

// MARK: - Helper Functions

private func parseDate(_ dateString: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        return date
    }
    // Попробуем без дробных секунд
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}

private func formatDate(_ dateString: String) -> String {
    guard let date = parseDate(dateString) else {
        return "выполнен"
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

// MARK: - Sensor Data Card

struct SensorDataCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(DesignColor.mainAccent)
                 Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                     .tracking(-0.5)
                    .lineSpacing(15)
                    .foregroundColor(DesignColor.mainAccent)
            }
 
            HStack(alignment: .top, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(unit)
                        .font(.title2)
                        .fontWeight(.semibold)
            }
            //.padding(.leading,8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignColor.Fills.tertiar, lineWidth: 1.0)
        )
    }
}

// MARK: - Plant Card View

struct PlantCardView: View {
    let plantInstance: PlantInstanceOut
    let plantType: PlantTypeOut?
    let nextWatering: NextWateringOut?
    
    var body: some View {
        HStack(spacing: 12) {
            // Картинка растения
            if let plantType = plantType, let imageUrl = plantType.image_url, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                    )
            }
            
            // Информация о растении
            VStack(alignment: .leading, spacing: 6) {
                // Заголовок (название растения)
                Text(plantType?.name ?? "Растение")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Данные о поливе
                if let nextWatering = nextWatering {
                    if let daysUntil = nextWatering.days_until {
                        // Есть интервал, показываем дни до следующего полива
                        if nextWatering.is_overdue {
                            Label("Полив просрочен на \(abs(daysUntil)) дн.", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        } else if daysUntil == 0 {
                            Label("Полив сегодня", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        } else {
                            Label("Полив через \(daysUntil) дн.", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(DesignColor.mainAccent)
                        }
                    } else if let lastWateringDate = nextWatering.next_watering_date {
                        // Нет интервала, но есть дата последнего полива
                        Label("Последний полив: \(formatDate(lastWateringDate))", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        // Нет данных о поливе
                        Label("Полив не запланирован", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Label("Загрузка...", systemImage: "drop.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}


