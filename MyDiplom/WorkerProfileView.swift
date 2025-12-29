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
    @State private var currentUser: UserOut
    @State private var greenhouses: [GreenhouseOut] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var wateringEvents: [WaterEventOut] = []
    @State private var fertilizingEvents: [WaterEventOut] = []
    @State private var isLoadingReports = false
    @State private var plantInstances: [PlantInstanceOut] = []
    @State private var plantTypes: [String: PlantTypeOut] = [:] // plant_type_id -> PlantTypeOut
    @State private var showAddGreenhouseSheet = false
    @State private var allGreenhouses: [GreenhouseOut] = []
    @State private var isLoadingAllGreenhouses = false
    @State private var isRemovingGreenhouse: Set<String> = [] // greenhouseId -> isRemoving
    @State private var isAddingGreenhouse = false
    @State private var greenhouseToRemove: GreenhouseOut?
    @State private var showRemoveAlert = false
    @State private var isChangingRole = false
    @State private var showChangeRoleAlert = false
    
    init(user: UserOut) {
        self.user = user
        _currentUser = State(initialValue: user)
    }
    
    var isAdmin: Bool {
        currentUser.role == "admin"
    }
    
    var roleText: String {
        currentUser.role == "admin" ? "Администратор" : "Рабочий"
    }
    
    var newRole: String {
        currentUser.role == "admin" ? "worker" : "admin"
    }
    
    var newRoleText: String {
        currentUser.role == "admin" ? "Рабочий" : "Администратор"
    }
    
    // Проверяем, является ли текущий пользователь админом (для управления теплицами)
    var currentUserIsAdmin: Bool {
        AuthManager.shared.currentUser?.role == "admin"
    }
    
    // Проверяем, является ли это текущий пользователь
    var isCurrentUser: Bool {
        AuthManager.shared.currentUser?.id == currentUser.id
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок: Аватарка, имя и должность
                HStack(alignment: .top, spacing: 12) {
                    // Вертикальный контейнер с именем и должностью
                    VStack(alignment: .leading, spacing: 0) {
                        Text(currentUser.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(roleText)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        // Email
                        Text(currentUser.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Аватарка справа
                    if let avatarUrl = currentUser.avatar_url, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            SkeletonView(width: 80, height: 80, cornerRadius: 10)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
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
                        // Заголовок и кнопка на одной линии
                        HStack(alignment: .center) {
                            Text("Теплицы")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            // Кнопка добавления теплицы (только для админов)
                            if currentUserIsAdmin {
                                Button(action: {
                                    Task {
                                        await loadAllGreenhousesForSelection()
                                    }
                                    showAddGreenhouseSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Добавить")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(DesignColor.mainAccent)
                                }
                                .disabled(isLoadingAllGreenhouses)
                            }
                        }
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
                                    .contextMenu {
                                        // Контекстное меню (только для админов)
                                        if currentUserIsAdmin {
                                            Button(role: .destructive) {
                                                greenhouseToRemove = greenhouse
                                                showRemoveAlert = true
                                            } label: {
                                                Label("Удалить", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Отчет (для рабочих и админов)
                VStack(alignment: .leading, spacing: 8) {
                    Text(isAdmin ? "Отчет" : "Отчет по пользователю")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    if isLoadingReports {
                        ProgressView("Загрузка отчета...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        let allEvents = (wateringEvents + fertilizingEvents).sorted { event1, event2 in
                            // Сортируем по дате создания (новые сверху)
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
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Заголовок таблицы
                                    HStack(spacing: 0) {
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
                                    
                                    // Строки таблицы
                                    ForEach(allEvents) { event in
                                        WorkerReportRowView(
                                            event: event,
                                            greenhouseName: getGreenhouseName(greenhouseId: event.greenhouse_id),
                                            plantTypeName: getPlantTypeName(plantInstanceId: event.plant_instance_id),
                                            greenhouseId: event.greenhouse_id
                                        )
                                        .environmentObject(bleManager)
                                        .environmentObject(sensorDataManager)
                                        .environmentObject(wateringDataManager)
                                        .environmentObject(fertilizingDataManager)
                                    }
                                }
                                // Минимальная ширина = сумма всех колонок (100 + 120 + 150 + 150) + отступы
                                .frame(minWidth: 520 + 32)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(currentUser.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Group {
                    if currentUserIsAdmin && !isCurrentUser {
                        Button(action: {
                            showChangeRoleAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Сменить роль")
                            }
                            .font(.subheadline)
                            .foregroundColor(DesignColor.mainAccent)
                        }
                        .disabled(isChangingRole)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .task {
            if isAdmin {
                // Для админа загружаем все теплицы
                await loadAllGreenhouses()
            } else {
                // Для рабочего загружаем только привязанные теплицы
                await loadGreenhousesAsync()
            }
            await loadPlantTypes()
            await loadReports()
        }
        .refreshable {
            if isAdmin {
                await loadAllGreenhouses()
            } else {
                await loadGreenhousesAsync()
            }
            await loadPlantTypes()
            await loadReports()
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
        .sheet(isPresented: $showAddGreenhouseSheet) {
            AddGreenhouseToUserView(
                user: currentUser,
                allGreenhouses: allGreenhouses,
                currentGreenhouses: greenhouses,
                isLoading: isLoadingAllGreenhouses,
                onAdd: { greenhouseId in
                    Task {
                        await addGreenhouse(greenhouseId: greenhouseId)
                    }
                }
            )
        }
        .alert("Отвязать работника от теплицы?", isPresented: $showRemoveAlert) {
            Button("Отвязать", role: .destructive) {
                if let greenhouse = greenhouseToRemove {
                    Task {
                        await removeGreenhouse(greenhouseId: greenhouse.id)
                    }
                }
            }
            Button("Отмена", role: .cancel) {
                greenhouseToRemove = nil
            }
        } message: {
            if let greenhouse = greenhouseToRemove {
                Text("Вы уверены, что хотите отвязать работника от теплицы \"\(greenhouse.name)\"?")
            }
        }
        .alert("Сменить роль?", isPresented: $showChangeRoleAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Сменить", role: .destructive) {
                Task {
                    await changeRole()
                }
            }
        } message: {
            Text("Вы уверены, что хотите изменить роль пользователя \"\(currentUser.name)\" с \"\(roleText)\" на \"\(newRoleText)\"?")
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
            let loadedGreenhouses: [GreenhouseOut]
            
            // Если текущий авторизованный пользователь - админ и смотрит профиль другого пользователя,
            // используем getWorkerGreenhouses для получения теплиц этого воркера
            let isViewingOtherUser = AuthManager.shared.currentUser?.id != currentUser.id
            let isCurrentUserAdmin = AuthManager.shared.currentUser?.role == "admin"
            
            if isCurrentUserAdmin && isViewingOtherUser {
                // Админ смотрит профиль воркера - используем специальный метод
                loadedGreenhouses = try await APIService.shared.getWorkerGreenhouses(workerId: currentUser.id)
            } else {
                // Воркер смотрит свой профиль или админ смотрит свой профиль
                // getGreenhouses() автоматически вернет правильные теплицы
                loadedGreenhouses = try await APIService.shared.getGreenhouses()
            }
            
            await MainActor.run {
                greenhouses = loadedGreenhouses
                isLoading = false
            }
            
            // Загружаем данные о поливах и удобрениях для всех теплиц
            for greenhouse in loadedGreenhouses {
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
    
    // Загрузка всех теплиц для админа
    private func loadAllGreenhouses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allGreenhouses = try await APIService.shared.getGreenhouses()
            await MainActor.run {
                greenhouses = allGreenhouses
                isLoading = false
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
    
    // Загрузка отчетов рабочего
    private func loadReports() async {
        await MainActor.run {
            isLoadingReports = true
        }
        
        do {
            // Загружаем события полива и удобрения для выбранного рабочего
            let currentUserId = await MainActor.run { currentUser.id }
            let watering = try await APIService.shared.getWateringEvents(userId: currentUserId)
            let fertilizing = try await APIService.shared.getFertilizingEvents(userId: currentUserId)
            
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
    
    // Загрузка типов растений
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
    
    // Получить название теплицы по ID
    private func getGreenhouseName(greenhouseId: String) -> String {
        if let greenhouse = greenhouses.first(where: { $0.id == greenhouseId }) {
            return greenhouse.name
        }
        return "—"
    }
    
    // Получить название типа растения по ID экземпляра растения
    private func getPlantTypeName(plantInstanceId: String?) -> String {
        guard let plantInstanceId = plantInstanceId else {
            return "—"
        }
        
        // Находим растение по ID
        if let plantInstance = plantInstances.first(where: { $0.id == plantInstanceId }) {
            // Находим тип растения
            if let plantType = plantTypes[plantInstance.plant_type_id] {
                return plantType.name
            }
        }
        
        return "—"
    }
    
    // Загрузка всех теплиц для выбора (только для админов)
    private func loadAllGreenhousesForSelection() async {
        await MainActor.run {
            isLoadingAllGreenhouses = true
        }
        
        do {
            let allGreenhousesList = try await APIService.shared.getGreenhouses()
            await MainActor.run {
                allGreenhouses = allGreenhousesList
                isLoadingAllGreenhouses = false
            }
        } catch {
            print("❌ Ошибка загрузки всех теплиц: \(error)")
            await MainActor.run {
                isLoadingAllGreenhouses = false
            }
        }
    }
    
    // Добавить пользователя в теплицу
    private func addGreenhouse(greenhouseId: String) async {
        await MainActor.run {
            isAddingGreenhouse = true
        }
        
        do {
            try await APIService.shared.bindWorkerToGreenhouse(greenhouseId: greenhouseId, userId: currentUser.id)
            print("✅ Пользователь \(currentUser.name) успешно добавлен в теплицу")
            
            // Обновляем список теплиц
            if isAdmin {
                await loadAllGreenhouses()
            } else {
                await loadGreenhousesAsync()
            }
            
            await MainActor.run {
                isAddingGreenhouse = false
                showAddGreenhouseSheet = false
            }
        } catch {
            print("❌ Ошибка добавления пользователя в теплицу: \(error)")
            await MainActor.run {
                isAddingGreenhouse = false
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Ошибка добавления: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Удалить пользователя из теплицы
    private func removeGreenhouse(greenhouseId: String) async {
        await MainActor.run {
            isRemovingGreenhouse.insert(greenhouseId)
        }
        
        do {
            try await APIService.shared.unbindWorkerFromGreenhouse(greenhouseId: greenhouseId, userId: currentUser.id)
            print("✅ Пользователь \(currentUser.name) успешно удален из теплицы")
            
            // Обновляем список теплиц
            if isAdmin {
                await loadAllGreenhouses()
            } else {
                await loadGreenhousesAsync()
            }
            
            await MainActor.run {
                isRemovingGreenhouse.remove(greenhouseId)
            }
        } catch {
            print("❌ Ошибка удаления пользователя из теплицы: \(error)")
            await MainActor.run {
                isRemovingGreenhouse.remove(greenhouseId)
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Ошибка удаления: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Сменить роль пользователя
    private func changeRole() async {
        await MainActor.run {
            isChangingRole = true
            errorMessage = nil
        }
        
        do {
            // Если меняем роль на админа, сначала отвязываем все теплицы
            if newRole == "admin" {
                // Загружаем текущие привязанные теплицы
                // Если текущий пользователь - админ и смотрит профиль другого пользователя,
                // используем getWorkerGreenhouses, иначе getGreenhouses
                let currentGreenhouses: [GreenhouseOut]
                let isViewingOtherUser = AuthManager.shared.currentUser?.id != currentUser.id
                let isCurrentUserAdmin = AuthManager.shared.currentUser?.role == "admin"
                
                if isCurrentUserAdmin && isViewingOtherUser {
                    currentGreenhouses = try await APIService.shared.getWorkerGreenhouses(workerId: currentUser.id)
                } else {
                    // Воркер меняет свою роль или админ меняет свою роль
                    currentGreenhouses = try await APIService.shared.getGreenhouses()
                }
                
                // Отвязываем все теплицы
                for greenhouse in currentGreenhouses {
                    do {
                        try await APIService.shared.unbindWorkerFromGreenhouse(greenhouseId: greenhouse.id, userId: currentUser.id)
                        print("✅ Теплица \(greenhouse.name) отвязана от пользователя \(currentUser.name)")
                    } catch {
                        print("⚠️ Не удалось отвязать теплицу \(greenhouse.name): \(error)")
                        // Продолжаем отвязку остальных теплиц даже при ошибке
                    }
                }
            }
            
            // Меняем роль
            let updatedUser = try await APIService.shared.updateUserRole(userId: currentUser.id, role: newRole)
            print("✅ Роль пользователя \(currentUser.name) успешно изменена на \(newRole)")
            
            await MainActor.run {
                currentUser = updatedUser
                isChangingRole = false
            }
            
            // Перезагружаем данные в зависимости от новой роли
            if updatedUser.role == "admin" {
                // Для админа загружаем все теплицы
                await loadAllGreenhouses()
            } else {
                // Для рабочего загружаем только привязанные теплицы
                await loadGreenhousesAsync()
            }
            
            // Перезагружаем отчеты
            await loadReports()
            
            // Не отправляем уведомление здесь, чтобы не прерывать навигацию
            // Список пользователей обновится при следующем открытии экрана "Работники"
        } catch {
            print("❌ Ошибка смены роли: \(error)")
            await MainActor.run {
                isChangingRole = false
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = "Ошибка смены роли: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Worker Report Row View
struct WorkerReportRowView: View {
    let event: WaterEventOut
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

// MARK: - Add Greenhouse To User View
struct AddGreenhouseToUserView: View {
    let user: UserOut
    let allGreenhouses: [GreenhouseOut]
    let currentGreenhouses: [GreenhouseOut]
    let isLoading: Bool
    let onAdd: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGreenhouseId: String?
    
    // Доступные для добавления теплицы (те, которые еще не привязаны)
    var availableGreenhouses: [GreenhouseOut] {
        let currentIds = Set(currentGreenhouses.map { $0.id })
        return allGreenhouses.filter { !currentIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Загрузка теплиц...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableGreenhouses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("Все теплицы уже привязаны")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(availableGreenhouses) { greenhouse in
                            Button(action: {
                                selectedGreenhouseId = greenhouse.id
                            }) {
                                GreenhouseSimpleCardView(
                                    greenhouse: greenhouse,
                                    isSelected: selectedGreenhouseId == greenhouse.id,
                                    imageSize: 50,
                                    showDescription: true
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Добавить теплицу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        if let greenhouseId = selectedGreenhouseId {
                            onAdd(greenhouseId)
                        }
                    }
                    .disabled(selectedGreenhouseId == nil || isLoading)
                }
            }
        }
    }
}

