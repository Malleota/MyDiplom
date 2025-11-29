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
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @StateObject private var viewModel = GreenhouseListViewModel()
    @State private var showCreateGreenhouse = false
    
    private var shouldShowCreateButton: Bool {
        AuthManager.shared.currentUser?.role != "worker"
    }
    
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
                        if AuthManager.shared.currentUser?.role != "worker" {
                            Text("Нажмите + чтобы создать первую теплицу")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
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
                                        nextWatering: wateringDataManager.getNextWatering(greenhouseId: greenhouse.id),
                                        nextFertilizing: fertilizingDataManager.getNextFertilizing(greenhouseId: greenhouse.id)
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
                    if shouldShowCreateButton {
                        Button(action: {
                            showCreateGreenhouse = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateGreenhouse) {
                CreateGreenhouseView()
            }
            .task {
                await viewModel.loadGreenhouses(bleManager: bleManager)
                // Загружаем данные о поливах и удобрениях для всех теплиц
                for greenhouse in viewModel.greenhouses {
                    await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                    await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
                }
            }
            .refreshable {
                await viewModel.loadGreenhouses(bleManager: bleManager)
                // Обновляем данные о поливах и удобрениях для всех теплиц
                for greenhouse in viewModel.greenhouses {
                    await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                    await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GreenhouseUpdated"))) { _ in
                // Обновляем список теплиц при создании/удалении теплицы
                Task {
                    await viewModel.loadGreenhouses(bleManager: bleManager, forceReload: true)
                    // Обновляем данные о поливах и удобрениях для всех теплиц
                    for greenhouse in viewModel.greenhouses {
                        await wateringDataManager.loadNextWateringForGreenhouse(greenhouse)
                        await fertilizingDataManager.loadNextFertilizingForGreenhouse(greenhouse)
                    }
                }
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NextFertilizingUpdated"))) { _ in
                // Обновляем UI при обновлении данных об удобрениях
            }
            // Данные о поливах и удобрениях обновляются автоматически на бэкенде после создания события
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
    let nextFertilizing: NextWateringOut?
    
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
                                Label("Просрочено на \(abs(daysUntil)) дн.", systemImage: "drop.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            } else if daysUntil == 0 {
                                Label("Сегодня", systemImage: "drop.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            } else {
                                Label("Через \(daysUntil) дн.", systemImage: "drop.fill")
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.mainAccent)
                            }
                        } else if let lastWateringDate = nextWatering.next_watering_date {
                            // Нет интервала, но есть дата последнего полива
                            // Показываем дату последнего полива
                            Label("Последний: \(formatDate(lastWateringDate))", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            // Нет данных о поливе
                            Label("Не запланирован", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("Загрузка...", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Время до следующего удобрения
                    if let nextFertilizing = nextFertilizing {
                        if let daysUntil = nextFertilizing.days_until {
                            // Есть интервал, показываем дни до следующего удобрения
                            if nextFertilizing.is_overdue {
                                Label("Просрочено на \(abs(daysUntil)) дн.", systemImage: "leaf.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            } else if daysUntil == 0 {
                                Label("Сегодня", systemImage: "leaf.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            } else {
                                Label("Через \(daysUntil) дн.", systemImage: "leaf.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        } else if let lastFertilizingDate = nextFertilizing.next_watering_date {
                            // Нет интервала, но есть дата последнего удобрения
                            // Показываем дату последнего удобрения
                            Label("Последнее: \(formatDate(lastFertilizingDate))", systemImage: "leaf.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            // Нет данных об удобрении
                            Label("Не запланировано", systemImage: "leaf.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label("Загрузка...", systemImage: "leaf.fill")
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
            let userRole = AuthManager.shared.currentUser?.role ?? "unknown"
            print("📥 loadGreenhouses: Загружено \(fetchedGreenhouses.count) теплиц для пользователя с ролью \(userRole)")
            
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

// MARK: - Create Greenhouse View

struct CreateGreenhouseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateGreenhouseViewModel()
    @State private var selectedSegment: ContentSegment = .plants
    
    enum ContentSegment: String, CaseIterable {
        case plants = "Растения"
        case workers = "Рабочие"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Название
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        SystemInputField(
                            placeholder: "Введите название теплицы",
                            text: $viewModel.name
                        )
                    }
                    
                    // Описание
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Описание")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 40)
                                .fill(DesignColor.Background.primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 40)
                                        .stroke(DesignColor.Fills.tertiar, lineWidth: 1)
                                )
                                .frame(height: 120)
                            
                            if #available(iOS 16.0, *) {
                                TextEditor(text: $viewModel.description)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.clear)
                                    .scrollContentBackground(.hidden)
                            } else {
                                TextEditor(text: $viewModel.description)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.clear)
                            }
                        }
                    }
                    
                    // Выбор картинки
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Изображение")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isLoadingImages {
                            ProgressView("Загрузка изображений...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.availableImages) { image in
                                        Button(action: {
                                            viewModel.selectedImageId = image.id
                                        }) {
                                            Group {
                                                if let imageUrl = APIService.shared.getFullImageURL(image.image_url) {
                                                    AsyncImage(url: imageUrl) { phase in
                                                        switch phase {
                                                        case .empty:
                                                            ProgressView()
                                                                .frame(width: 100, height: 100)
                                                        case .success(let img):
                                                            img
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                        case .failure(let error):
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(Color.gray.opacity(0.2))
                                                                .frame(width: 100, height: 100)
                                                                .overlay(
                                                                    Image(systemName: "photo")
                                                                        .foregroundColor(.gray)
                                                                )
                                                        @unknown default:
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .fill(Color.gray.opacity(0.2))
                                                                .frame(width: 100, height: 100)
                                                        }
                                                    }
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(width: 100, height: 100)
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .foregroundColor(.gray)
                                                        )
                                                }
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(viewModel.selectedImageId == image.id ? DesignColor.mainAccent : Color.clear, lineWidth: 2)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Растения и рабочие с сегментированным контролом
                    VStack(alignment: .leading, spacing: 16) {
                        // Сегментированный контрол
                        Picker("", selection: $selectedSegment) {
                            ForEach(ContentSegment.allCases, id: \.self) { segment in
                                Text(segment.rawValue).tag(segment)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        // Контент в зависимости от выбранного сегмента
                        if selectedSegment == .plants {
                            // Растения
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.addPlant()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Добавить")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(DesignColor.mainAccent)
                                    }
                                }
                                
                                if viewModel.isLoadingPlantTypes {
                                    ProgressView("Загрузка типов растений...")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if viewModel.plants.isEmpty {
                                    Text("Растения не добавлены")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    ForEach(Array(viewModel.plants.enumerated()), id: \.element.id) { index, plant in
                                        PlantSelectionRow(
                                            plant: plant,
                                            availablePlantTypes: viewModel.availablePlantTypes,
                                            onRemove: {
                                                viewModel.removePlant(at: index)
                                            },
                                            onPlantTypeChanged: { plantTypeId in
                                                viewModel.updatePlantType(at: index, plantTypeId: plantTypeId)
                                            },
                                            onQuantityChanged: { quantity in
                                                viewModel.updatePlantQuantity(at: index, quantity: quantity)
                                            }
                                        )
                                    }
                                }
                            }
                        } else {
                            // Рабочие
                            VStack(alignment: .leading, spacing: 12) {
                                if viewModel.isLoadingWorkers {
                                    ProgressView("Загрузка рабочих...")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if viewModel.availableWorkers.isEmpty {
                                    Text("Нет доступных рабочих")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    ScrollView {
                                        VStack(spacing: 12) {
                                            ForEach(viewModel.availableWorkers) { worker in
                                                WorkerSelectionRow(
                                                    worker: worker,
                                                    isSelected: viewModel.selectedWorkerIds.contains(worker.id),
                                                    onToggle: {
                                                        viewModel.toggleWorker(worker.id)
                                                    }
                                                )
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 300)
                                }
                            }
                        }
                    }
                    
                    // Сообщение об ошибке
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(DesignColor.mainRed)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Новая теплица")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task {
                            await viewModel.saveGreenhouse()
                            if viewModel.isSuccess {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.isValid)
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - Create Greenhouse ViewModel

@MainActor
class CreateGreenhouseViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var selectedImageId: String? = nil
    @Published var plants: [PlantSelection] = []
    @Published var selectedWorkerIds: [String] = []
    @Published var availableImages: [GreenhouseImageOut] = []
    @Published var availablePlantTypes: [PlantTypeOut] = []
    @Published var availableWorkers: [UserOut] = []
    @Published var isLoadingImages = false
    @Published var isLoadingPlantTypes = false
    @Published var isLoadingWorkers = false
    @Published var isSaving = false
    @Published var errorMessage: String? = nil
    @Published var isSuccess = false
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    
    func loadData() async {
        await loadImages()
        await loadPlantTypes()
        await loadWorkers()
    }
    
    func loadImages() async {
        isLoadingImages = true
        defer { isLoadingImages = false }
        
        do {
            availableImages = try await APIService.shared.getGreenhouseImages()
            print("📸 loadImages: Загружено \(availableImages.count) изображений")
            
            // Предвыбираем первую картинку
            if !availableImages.isEmpty && selectedImageId == nil {
                selectedImageId = availableImages.first?.id
                print("📸 loadImages: Предвыбрано изображение с ID: \(selectedImageId ?? "nil")")
            }
        } catch {
            print("❌ Ошибка загрузки изображений: \(error)")
            if let apiError = error as? APIError {
                errorMessage = apiError.detail
            } else {
                errorMessage = "Ошибка загрузки изображений: \(error.localizedDescription)"
            }
        }
    }
    
    func loadPlantTypes() async {
        isLoadingPlantTypes = true
        defer { isLoadingPlantTypes = false }
        
        do {
            availablePlantTypes = try await APIService.shared.getPlantTypes()
        } catch {
            print("❌ Ошибка загрузки типов растений: \(error)")
            errorMessage = "Ошибка загрузки типов растений: \(error.localizedDescription)"
        }
    }
    
    func loadWorkers() async {
        isLoadingWorkers = true
        defer { isLoadingWorkers = false }
        
        do {
            availableWorkers = try await APIService.shared.getWorkers()
            print("👷 loadWorkers: Загружено \(availableWorkers.count) рабочих")
        } catch {
            print("❌ Ошибка загрузки рабочих: \(error)")
            // Не показываем ошибку как критическую, просто логируем
        }
    }
    
    func toggleWorker(_ workerId: String) {
        if selectedWorkerIds.contains(workerId) {
            selectedWorkerIds.removeAll { $0 == workerId }
        } else {
            selectedWorkerIds.append(workerId)
        }
    }
    
    func addPlant() {
        plants.append(PlantSelection(plantTypeId: "", quantity: 1))
    }
    
    func removePlant(at index: Int) {
        guard index < plants.count else { return }
        plants.remove(at: index)
    }
    
    func updatePlantType(at index: Int, plantTypeId: String) {
        guard index < plants.count else { return }
        var updatedPlants = plants
        updatedPlants[index].plantTypeId = plantTypeId
        plants = updatedPlants
    }
    
    func updatePlantQuantity(at index: Int, quantity: Int) {
        guard index < plants.count else { return }
        var updatedPlants = plants
        updatedPlants[index].quantity = quantity
        plants = updatedPlants
    }
    
    func saveGreenhouse() async {
        isSaving = true
        errorMessage = nil
        isSuccess = false
        defer { isSaving = false }
        
        // Получаем image_url из выбранного изображения
        var imageUrl: String? = nil
        if let selectedImageId = selectedImageId,
           let selectedImage = availableImages.first(where: { $0.id == selectedImageId }) {
            imageUrl = selectedImage.image_url
        }
        
        // Формируем список растений
        let plantInstances: [PlantInstanceCreate]? = plants.isEmpty ? nil : plants.compactMap { plant in
            guard !plant.plantTypeId.isEmpty else { return nil }
            return PlantInstanceCreate(
                plant_type_id: plant.plantTypeId,
                quantity: plant.quantity,
                note: nil
            )
        }
        
        let greenhouseCreate = GreenhouseCreate(
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            image_url: imageUrl,
            plants: plantInstances?.isEmpty == false ? plantInstances : nil,
            worker_ids: selectedWorkerIds.isEmpty ? nil : selectedWorkerIds,
            sensor_ble_identifier: nil
        )
        
        do {
            _ = try await APIService.shared.createGreenhouse(greenhouseCreate)
            print("✅ Теплица успешно создана")
            isSuccess = true
            
            // Отправляем уведомление об обновлении списка теплиц
            NotificationCenter.default.post(name: NSNotification.Name("GreenhouseUpdated"), object: nil)
        } catch {
            print("❌ Ошибка создания теплицы: \(error)")
            if let apiError = error as? APIError {
                errorMessage = apiError.detail
            } else {
                errorMessage = "Ошибка создания теплицы: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Plant Selection Model

struct PlantSelection: Identifiable {
    let id = UUID()
    var plantTypeId: String
    var quantity: Int
}

// MARK: - Plant Selection Row

struct PlantSelectionRow: View {
    let plant: PlantSelection
    let availablePlantTypes: [PlantTypeOut]
    let onRemove: () -> Void
    let onPlantTypeChanged: (String) -> Void
    let onQuantityChanged: (Int) -> Void
    
    @State private var quantityText: String
    @State private var showPlantPicker = false
    
    init(plant: PlantSelection, availablePlantTypes: [PlantTypeOut], onRemove: @escaping () -> Void, onPlantTypeChanged: @escaping (String) -> Void, onQuantityChanged: @escaping (Int) -> Void) {
        self.plant = plant
        self.availablePlantTypes = availablePlantTypes
        self.onRemove = onRemove
        self.onPlantTypeChanged = onPlantTypeChanged
        self.onQuantityChanged = onQuantityChanged
        _quantityText = State(initialValue: String(plant.quantity))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Растение")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(DesignColor.mainRed)
                }
            }
            
            // Выбор типа растения
            Button(action: {
                showPlantPicker = true
            }) {
                HStack {
                    Text(selectedPlantTypeName)
                        .foregroundColor(plant.plantTypeId.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(DesignColor.Background.primary)
                .cornerRadius(40)
                .overlay(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(DesignColor.Fills.tertiar, lineWidth: 1)
                )
            }
            .sheet(isPresented: $showPlantPicker) {
                PlantPickerView(
                    availablePlantTypes: availablePlantTypes,
                    selectedPlantTypeId: plant.plantTypeId,
                    onSelect: { plantTypeId in
                        onPlantTypeChanged(plantTypeId)
                        showPlantPicker = false
                    }
                )
            }
            
            // Информация о выбранном растении (картинка и температура)
            if let selectedPlantType = selectedPlantType {
                HStack(spacing: 12) {
                    // Картинка растения
                    if let imageUrl = selectedPlantType.image_url, let url = URL(string: imageUrl) {
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
                    
                    // Температура
                    if let tempMin = selectedPlantType.temp_min, let tempMax = selectedPlantType.temp_max {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer")
                                    .foregroundColor(DesignColor.mainAccent)
                                    .font(.caption)
                                Text("Температура")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(String(format: "%.1f", tempMin))°C - \(String(format: "%.1f", tempMax))°C")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Количество
            HStack {
                Text("Количество")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        let newQuantity = max(1, plant.quantity - 1)
                        quantityText = String(newQuantity)
                        onQuantityChanged(newQuantity)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(DesignColor.mainAccent)
                    }
                    
                    TextField("", text: $quantityText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .onChange(of: quantityText) { newValue in
                            if let quantity = Int(newValue), quantity > 0 {
                                onQuantityChanged(quantity)
                            }
                        }
                    
                    Button(action: {
                        let newQuantity = plant.quantity + 1
                        quantityText = String(newQuantity)
                        onQuantityChanged(newQuantity)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignColor.mainAccent)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            quantityText = String(plant.quantity)
        }
        .onChange(of: plant.quantity) { newValue in
            if quantityText != String(newValue) {
                quantityText = String(newValue)
            }
        }
    }
    
    private var selectedPlantTypeName: String {
        if let plantType = availablePlantTypes.first(where: { $0.id == plant.plantTypeId }) {
            return plantType.name
        }
        return "Выберите растение"
    }
    
    private var selectedPlantType: PlantTypeOut? {
        availablePlantTypes.first(where: { $0.id == plant.plantTypeId })
    }
}

// MARK: - Plant Picker View

struct PlantPickerView: View {
    let availablePlantTypes: [PlantTypeOut]
    let selectedPlantTypeId: String
    let onSelect: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(availablePlantTypes) { plantType in
                        Button(action: {
                            onSelect(plantType.id)
                        }) {
                            HStack(spacing: 12) {
                                // Картинка растения
                                if let imageUrl = plantType.image_url, let url = APIService.shared.getFullImageURL(imageUrl) {
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
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 60, height: 60)
                                                .overlay(
                                                    Image(systemName: "leaf.fill")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 24))
                                                )
                                        @unknown default:
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 60, height: 60)
                                        }
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
                                    Text(plantType.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let description = plantType.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    // Температура
                                    if let tempMin = plantType.temp_min, let tempMax = plantType.temp_max {
                                        HStack(spacing: 4) {
                                            Image(systemName: "thermometer")
                                                .foregroundColor(DesignColor.mainAccent)
                                                .font(.caption)
                                            Text("\(String(format: "%.1f", tempMin))°C - \(String(format: "%.1f", tempMax))°C")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Влажность
                                    if let humMin = plantType.humidity_min, let humMax = plantType.humidity_max {
                                        HStack(spacing: 4) {
                                            Image(systemName: "drop.fill")
                                                .foregroundColor(DesignColor.mainAccent)
                                                .font(.caption)
                                            Text("\(String(format: "%.0f", humMin))% - \(String(format: "%.0f", humMax))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Индикатор выбора
                                if selectedPlantTypeId == plantType.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignColor.mainAccent)
                                        .font(.title3)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPlantTypeId == plantType.id ? DesignColor.mainAccent : Color.clear, lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Выберите растение")
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

// MARK: - Worker Selection Row

struct WorkerSelectionRow: View {
    let worker: UserOut
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Аватар рабочего
                if let avatarUrl = worker.avatar_url, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                // Информация о рабочем
                VStack(alignment: .leading, spacing: 4) {
                    Text(worker.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(worker.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Индикатор выбора
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignColor.mainAccent : .gray)
                    .font(.title3)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? DesignColor.mainAccent : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Greenhouse Detail View

struct GreenhouseDetailView: View {
    let greenhouseId: String
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
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
    @State private var plantFertilizings: [String: NextWateringOut] = [:] // plant_instance_id -> NextWateringOut
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
                                            greenhouseId: greenhouseId,
                                            plantInstance: plantInstance,
                                            plantType: plantTypes[plantInstance.plant_type_id],
                                            nextWatering: plantWaterings[plantInstance.id],
                                            nextFertilizing: plantFertilizings[plantInstance.id],
                                            onWateringComplete: {
                                                // Обновляем данные о поливе после полива
                                                Task {
                                                    // Ждем немного, чтобы сервер успел пересчитать данные
                                                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
                                                    
                                                    // Обновляем данные о растениях и поливах
                                                    await loadPlants()
                                                    
                                                    // Делаем еще одну попытку обновления через небольшую задержку
                                                    // на случай, если сервер еще не успел пересчитать
                                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
                                                    await loadPlants()
                                                    
                                                    // Обновляем данные о поливе для теплицы (для карточки в списке)
                                                    // Загружаем greenhouse для обновления данных о поливе
                                                    do {
                                                        let gh = try await APIService.shared.getGreenhouse(id: greenhouseId)
                                                        await wateringDataManager.loadNextWateringForGreenhouse(gh)
                                                    } catch {
                                                        print("❌ Ошибка загрузки теплицы для обновления данных о поливе: \(error)")
                                                    }
                                                }
                                            }
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
            
            // Загружаем данные об удобрении для каждого растения
            let fertilizings = try await APIService.shared.getNextFertilizingForPlants(greenhouseId: greenhouseId)
            var fertilizingDict: [String: NextWateringOut] = [:]
            for fertilizing in fertilizings {
                if let plantInstanceId = fertilizing.plant_instance_id {
                    fertilizingDict[plantInstanceId] = fertilizing
                }
            }
            await MainActor.run {
                plantFertilizings = fertilizingDict
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
    let greenhouseId: String
    let plantInstance: PlantInstanceOut
    let plantType: PlantTypeOut?
    let nextWatering: NextWateringOut?
    let nextFertilizing: NextWateringOut?
    let onWateringComplete: () -> Void
    
    @State private var isWatering = false
    @State private var isFertilizing = false
    @State private var errorMessage: String?
    @State private var showEditPlant = false
    
    // Проверяем, является ли пользователь администратором
    private var isAdmin: Bool {
        AuthManager.shared.currentUser?.role == "admin"
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
                // Заголовок (название растения и количество)
                HStack(spacing: 4) {
                    Text(plantType?.name ?? "Растение")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(plantInstance.quantity) шт")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Данные о поливе
                if let nextWatering = nextWatering {
                    if let daysUntil = nextWatering.days_until {
                        // Есть интервал, показываем дни до следующего полива
                        if nextWatering.is_overdue {
                            Label("Просрочено на \(abs(daysUntil)) дн.", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        } else if daysUntil == 0 {
                            Label("Сегодня", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        } else {
                            Label("Через \(daysUntil) дн.", systemImage: "drop.fill")
                                .font(.subheadline)
                                .foregroundColor(DesignColor.mainAccent)
                        }
                    } else if let lastWateringDate = nextWatering.next_watering_date {
                        // Нет интервала, но есть дата последнего полива
                        Label("Последний: \(formatDate(lastWateringDate))", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        // Нет данных о поливе
                        Label("Не запланирован", systemImage: "drop.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Label("Загрузка...", systemImage: "drop.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Данные об удобрении
                if let nextFertilizing = nextFertilizing {
                    if let daysUntil = nextFertilizing.days_until {
                        // Есть интервал, показываем дни до следующего удобрения
                        if nextFertilizing.is_overdue {
                            Label("Просрочено на \(abs(daysUntil)) дн.", systemImage: "leaf.fill")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        } else if daysUntil == 0 {
                            Label("Сегодня", systemImage: "leaf.fill")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        } else {
                            Label("Через \(daysUntil) дн.", systemImage: "leaf.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    } else if let lastFertilizingDate = nextFertilizing.next_watering_date {
                        // Нет интервала, но есть дата последнего удобрения
                        Label("Последнее: \(formatDate(lastFertilizingDate))", systemImage: "leaf.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        // Нет данных об удобрении
                        Label("Не запланировано", systemImage: "leaf.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Label("Загрузка...", systemImage: "leaf.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Сообщение об ошибке
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(DesignColor.mainRed)
                }
            }
            
            Spacer()
            
            // Кнопки действий
            VStack(spacing: 8) {
                // Кнопка "Полить"
                if shouldShowWaterButton {
                    Button(action: {
                        Task {
                            await waterPlant()
                        }
                    }) {
                        if isWatering {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Полить")
                                .font(.caption)
                                .fontWeight(.medium)
                                .tracking(-0.5)
                                .lineSpacing(15)
                                .foregroundColor(DesignColor.myBlue)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignColor.myBlue.opacity(0.1))
                    .cornerRadius(40)
                    .disabled(isWatering || isFertilizing)
                }
                
                // Кнопка "Удобрить"
                if shouldShowFertilizeButton {
                    Button(action: {
                        Task {
                            await fertilizePlant()
                        }
                    }) {
                        if isFertilizing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Удобрить")
                                .font(.caption)
                                .fontWeight(.medium)
                                .tracking(-0.5)
                                .lineSpacing(15)
                                .foregroundColor(DesignColor.myBrown)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignColor.myBrown.opacity(0.1))
                    .cornerRadius(40)
                    .disabled(isWatering || isFertilizing)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            if isAdmin {
                Button(action: {
                    showEditPlant = true
                }) {
                    Label("Редактировать", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEditPlant) {
            EditPlantView(
                greenhouseId: greenhouseId,
                plantInstance: plantInstance,
                plantType: plantType,
                nextWatering: nextWatering,
                nextFertilizing: nextFertilizing,
                onUpdateComplete: {
                    onWateringComplete()
                }
            )
        }
    }
    
    private func waterPlant() async {
        await MainActor.run {
            isWatering = true
            errorMessage = nil
        }
        
        do {
            _ = try await APIService.shared.createWateringEvent(
                greenhouseId: greenhouseId,
                plantInstanceId: plantInstance.id,
                type: "watering",
                comment: nil
            )
            
            print("✅ Полив успешно выполнен для растения \(plantInstance.id)")
            
            // Ждем немного, чтобы сервер успел пересчитать данные о поливе
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            // Обновляем данные
            await MainActor.run {
                isWatering = false
            }
            
            // Вызываем callback для обновления данных
            onWateringComplete()
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
        }
    }
    
    private func fertilizePlant() async {
        await MainActor.run {
            isFertilizing = true
            errorMessage = nil
        }
        
        do {
            _ = try await APIService.shared.createWateringEvent(
                greenhouseId: greenhouseId,
                plantInstanceId: plantInstance.id,
                type: "fertilizing",
                comment: nil
            )
            
            print("✅ Удобрение успешно выполнено для растения \(plantInstance.id)")
            
            // Ждем немного, чтобы сервер успел пересчитать данные об удобрении
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
            
            // Обновляем данные
            await MainActor.run {
                isFertilizing = false
            }
            
            // Вызываем callback для обновления данных
            onWateringComplete()
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
        }
    }
}

// MARK: - Edit Plant View

struct EditPlantView: View {
    let greenhouseId: String
    let plantInstance: PlantInstanceOut
    let plantType: PlantTypeOut?
    let nextWatering: NextWateringOut?
    let nextFertilizing: NextWateringOut?
    let onUpdateComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var quantity: String
    @State private var selectedWateringDate: Date?
    @State private var selectedFertilizingDate: Date?
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(greenhouseId: String, plantInstance: PlantInstanceOut, plantType: PlantTypeOut?, nextWatering: NextWateringOut?, nextFertilizing: NextWateringOut?, onUpdateComplete: @escaping () -> Void) {
        self.greenhouseId = greenhouseId
        self.plantInstance = plantInstance
        self.plantType = plantType
        self.nextWatering = nextWatering
        self.nextFertilizing = nextFertilizing
        self.onUpdateComplete = onUpdateComplete
        
        // Инициализируем количество из plantInstance
        _quantity = State(initialValue: String(plantInstance.quantity))
        
        // Инициализируем дату полива из nextWatering, если она есть
        if let nextWatering = nextWatering,
           let nextWateringDateString = nextWatering.next_watering_date,
           let date = parseDate(nextWateringDateString) {
            _selectedWateringDate = State(initialValue: date)
        } else {
            _selectedWateringDate = State(initialValue: nil)
        }
        
        // Инициализируем дату удобрения из nextFertilizing, если она есть
        if let nextFertilizing = nextFertilizing,
           let nextFertilizingDateString = nextFertilizing.next_watering_date,
           let date = parseDate(nextFertilizingDateString) {
            _selectedFertilizingDate = State(initialValue: date)
        } else {
            _selectedFertilizingDate = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о растении")) {
                    HStack {
                        Text("Тип растения")
                        Spacer()
                        Text(plantType?.name ?? "Неизвестно")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Количество растений")) {
                    TextField("Количество", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Дата следующего полива")) {
                    if let selectedWateringDate = selectedWateringDate {
                        DatePicker(
                            "Дата полива",
                            selection: Binding(
                                get: { selectedWateringDate },
                                set: { newDate in
                                    self.selectedWateringDate = newDate
                                }
                            ),
                            displayedComponents: .date
                        )
                        
                        Button("Очистить дату") {
                            self.selectedWateringDate = nil
                        }
                        .foregroundColor(DesignColor.mainRed)
                    } else {
                        Button("Выбрать дату") {
                            // Устанавливаем дату по умолчанию (сегодня), если дата не выбрана
                            self.selectedWateringDate = Date()
                        }
                    }
                }
                
                Section(header: Text("Дата следующего удобрения")) {
                    if let selectedFertilizingDate = selectedFertilizingDate {
                        DatePicker(
                            "Дата удобрения",
                            selection: Binding(
                                get: { selectedFertilizingDate },
                                set: { newDate in
                                    self.selectedFertilizingDate = newDate
                                }
                            ),
                            displayedComponents: .date
                        )
                        
                        Button("Очистить дату") {
                            self.selectedFertilizingDate = nil
                        }
                        .foregroundColor(DesignColor.mainRed)
                    } else {
                        Button("Выбрать дату") {
                            // Устанавливаем дату по умолчанию (сегодня), если дата не выбрана
                            self.selectedFertilizingDate = Date()
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(DesignColor.mainRed)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Редактировать растение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard let qty = Int(quantity), qty > 0 else {
            return false
        }
        return true
    }
    
    private func saveChanges() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        do {
            // Формируем дату полива в ISO8601 формате, если она выбрана
            var nextWateringDateString: String? = nil
            if let selectedWateringDate = selectedWateringDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                nextWateringDateString = formatter.string(from: selectedWateringDate)
            }
            
            // Вычисляем days_until, если есть дата полива
            var daysUntil: Int? = nil
            if let selectedWateringDate = selectedWateringDate {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let selected = calendar.startOfDay(for: selectedWateringDate)
                let components = calendar.dateComponents([.day], from: today, to: selected)
                daysUntil = components.day
            }
            
            // Формируем дату удобрения в ISO8601 формате, если она выбрана
            var nextFertilizingDateString: String? = nil
            if let selectedFertilizingDate = selectedFertilizingDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                nextFertilizingDateString = formatter.string(from: selectedFertilizingDate)
            }
            
            // Вычисляем fertilizing_days_until, если есть дата удобрения
            var fertilizingDaysUntil: Int? = nil
            if let selectedFertilizingDate = selectedFertilizingDate {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let selected = calendar.startOfDay(for: selectedFertilizingDate)
                let components = calendar.dateComponents([.day], from: today, to: selected)
                fertilizingDaysUntil = components.day
            }
            
            guard let qty = Int(quantity), qty > 0 else {
                throw APIError(detail: "Количество должно быть положительным числом")
            }
            
            let update = PlantInstanceUpdate(
                plant_type_id: nil, // Не меняем тип растения
                quantity: qty,
                note: nil, // Не меняем заметку
                next_watering_date: nextWateringDateString,
                days_until: daysUntil,
                next_fertilizing_date: nextFertilizingDateString,
                fertilizing_days_until: fertilizingDaysUntil
            )
            
            _ = try await APIService.shared.updatePlantInstance(
                greenhouseId: greenhouseId,
                plantInstanceId: plantInstance.id,
                update: update
            )
            
            print("✅ Растение успешно обновлено")
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
            
            // Обновляем данные
            onUpdateComplete()
        } catch {
            print("❌ Ошибка обновления растения: \(error)")
            await MainActor.run {
                isSaving = false
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Ошибка обновления: \(error.localizedDescription)"
                }
            }
        }
    }
}


