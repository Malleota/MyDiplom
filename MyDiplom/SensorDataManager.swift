//
//  SensorDataManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

/// Глобальный менеджер для обновления данных датчиков со всех теплиц
/// Использует WebSocket для получения обновлений в реальном времени
@MainActor
class SensorDataManager: ObservableObject {
    static let shared = SensorDataManager()
    
    @Published var sensorData: [String: SensorReadingOut] = [:] // greenhouseId -> SensorReadingOut
    
    private var activeScreensCount: Int = 0 // Счетчик активных экранов с sensor_id
    private var trackedGreenhouseIds: Set<String> = [] // Отслеживаемые теплицы
    private var websocketManager: WebSocketManager
    private var notificationManager: NotificationManager
    private var greenhouseCache: [String: GreenhouseOut] = [:] // Кэш данных теплиц для проверки норм
    private var lastNotificationTime: [String: Date] = [:] // Время последнего уведомления для каждой теплицы
    private let notificationCooldown: TimeInterval = 300 // 5 минут между уведомлениями для одной теплицы
    
    private init() {
        websocketManager = WebSocketManager.shared
        notificationManager = NotificationManager.shared
        
        // Настраиваем callback для обновлений данных через WebSocket
        websocketManager.onSensorDataUpdate = { [weak self] greenhouseId, sensorReading in
            Task { @MainActor in
                self?.handleSensorDataUpdate(greenhouseId: greenhouseId, sensorReading: sensorReading)
            }
        }
        
        // Слушаем обновления теплиц для обновления кэша
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GreenhouseUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // При обновлении теплицы нужно обновить кэш
            // Это будет сделано при следующей загрузке данных теплицы
        }
    }
    
    /// Регистрирует активный экран с запросом sensor_id
    func registerActiveScreen() {
        activeScreensCount += 1
        print("📱 SensorDataManager: Зарегистрирован активный экран (всего: \(activeScreensCount))")
        
        // Подключаемся к WebSocket, если это первый активный экран
        if activeScreensCount == 1 {
            connectWebSocket()
        }
    }
    
    /// Отменяет регистрацию активного экрана
    func unregisterActiveScreen() {
        activeScreensCount = max(0, activeScreensCount - 1)
        print("📱 SensorDataManager: Отменена регистрация экрана (осталось: \(activeScreensCount))")
        
        // Отключаемся от WebSocket, если нет активных экранов
        if activeScreensCount == 0 {
            disconnectWebSocket()
        }
    }
    
    /// Регистрирует теплицу для отслеживания через WebSocket
    func registerGreenhouse(greenhouseId: String) {
        trackedGreenhouseIds.insert(greenhouseId)
        print("📱 SensorDataManager: Зарегистрирована теплица \(greenhouseId) для отслеживания")
        
        // Если WebSocket уже подключен, переподключаемся для обновления списка
        if activeScreensCount > 0 {
            connectWebSocket()
        }
    }
    
    /// Отменяет регистрацию теплицы
    func unregisterGreenhouse(greenhouseId: String) {
        trackedGreenhouseIds.remove(greenhouseId)
        print("📱 SensorDataManager: Отменена регистрация теплицы \(greenhouseId)")
        
        // Если WebSocket подключен, переподключаемся
        if activeScreensCount > 0 {
            connectWebSocket()
        }
    }
    
    /// Подключается к WebSocket для получения обновлений
    func connectWebSocket() {
        // Проверяем, является ли пользователь админом
        let isAdmin = AuthManager.shared.currentUser?.role == "admin"
        
        if isAdmin {
            // Админы подключаются ко всем теплицам
            print("🔌 SensorDataManager: Подключение к WebSocket для всех теплиц (админ)")
            websocketManager.connectForAll()
        } else if !trackedGreenhouseIds.isEmpty {
            // Для обычных пользователей подключаемся к первой теплице
            // Если отслеживается несколько теплиц, подключаемся к первой
            // (WebSocket endpoint поддерживает только одну теплицу за раз для не-админов)
            if let firstGreenhouseId = trackedGreenhouseIds.first {
                if trackedGreenhouseIds.count == 1 {
                    print("🔌 SensorDataManager: Подключение к WebSocket для теплицы \(firstGreenhouseId)")
                } else {
                    print("🔌 SensorDataManager: Подключение к WebSocket для теплицы \(firstGreenhouseId) (первая из \(trackedGreenhouseIds.count))")
                }
                websocketManager.connect(greenhouseId: firstGreenhouseId)
            }
        } else {
            print("⚠️ SensorDataManager: Нет теплиц для отслеживания, WebSocket не подключается")
        }
    }
    
    /// Отключается от WebSocket
    private func disconnectWebSocket() {
        print("🔌 SensorDataManager: Отключение от WebSocket")
        websocketManager.disconnect()
    }
    
    /// Обрабатывает обновление данных датчика через WebSocket
    private func handleSensorDataUpdate(greenhouseId: String, sensorReading: SensorReadingOut) {
        print("📡 SensorDataManager: Обновление данных датчика для теплицы \(greenhouseId) через WebSocket: temp=\(sensorReading.temperature)°C, hum=\(sensorReading.humidity)%")
        sensorData[greenhouseId] = sensorReading
        
        // Проверяем данные на соответствие нормам и отправляем уведомления при необходимости
        Task {
            await checkSensorDataAndNotify(greenhouseId: greenhouseId, sensorReading: sensorReading)
        }
        
        // Отправляем уведомление об обновлении данных
        NotificationCenter.default.post(
            name: NSNotification.Name("SensorDataUpdated"),
            object: nil,
            userInfo: ["greenhouse_id": greenhouseId, "sensor_data": sensorReading]
        )
    }
    
    /// Загружает начальные данные датчика для конкретной теплицы (для первоначальной загрузки)
    func loadSensorDataForGreenhouse(_ greenhouse: GreenhouseOut) async {
        guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
            return
        }
        
        // Сохраняем данные теплицы в кэш для проверки норм
        greenhouseCache[greenhouse.id] = greenhouse
        
        // Регистрируем теплицу для отслеживания
        registerGreenhouse(greenhouseId: greenhouse.id)
        
        // Загружаем начальные данные с сервера (если еще нет данных)
        if sensorData[greenhouse.id] == nil {
            do {
                if let serverData = try await APIService.shared.getCurrentSensorData(greenhouseId: greenhouse.id) {
                    print("📡 SensorDataManager: Загружены начальные данные с сервера для теплицы \(greenhouse.name): temp=\(serverData.temperature)°C, hum=\(serverData.humidity)%")
                    sensorData[greenhouse.id] = serverData
                    
                    // Проверяем данные на соответствие нормам
                    await checkSensorDataAndNotify(greenhouseId: greenhouse.id, sensorReading: serverData)
                    
                    // Отправляем уведомление об обновлении данных
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SensorDataUpdated"),
                        object: nil,
                        userInfo: ["greenhouse_id": greenhouse.id, "sensor_data": serverData]
                    )
                } else {
                    print("⚠️ SensorDataManager: Нет данных датчика на сервере для теплицы \(greenhouse.name)")
                }
            } catch {
                print("❌ SensorDataManager: Ошибка загрузки начальных данных с сервера для теплицы \(greenhouse.name): \(error)")
            }
        } else {
            print("📡 SensorDataManager: Данные датчика для теплицы \(greenhouse.name) уже загружены")
        }
    }
    
    /// Обновляет данные теплицы в кэше (вызывается при обновлении теплицы)
    func updateGreenhouseCache(_ greenhouse: GreenhouseOut) {
        greenhouseCache[greenhouse.id] = greenhouse
    }
    
    /// Удаляет данные теплицы из кэша
    func removeGreenhouseFromCache(greenhouseId: String) {
        greenhouseCache.removeValue(forKey: greenhouseId)
        lastNotificationTime.removeValue(forKey: greenhouseId)
    }
    
    /// Получает данные датчика для теплицы (из кэша)
    func getSensorData(greenhouseId: String) -> SensorReadingOut? {
        return sensorData[greenhouseId]
    }
    
    /// Очищает данные для конкретной теплицы
    func clearSensorData(greenhouseId: String) {
        sensorData.removeValue(forKey: greenhouseId)
        removeGreenhouseFromCache(greenhouseId: greenhouseId)
        unregisterGreenhouse(greenhouseId: greenhouseId)
    }
    
    /// Очищает все данные
    func clearAllSensorData() {
        sensorData.removeAll()
        trackedGreenhouseIds.removeAll()
        greenhouseCache.removeAll()
        lastNotificationTime.removeAll()
        disconnectWebSocket()
    }
    
    // MARK: - Проверка данных датчиков и отправка уведомлений
    
    /// Проверяет данные датчика на соответствие нормам и отправляет уведомления при необходимости
    private func checkSensorDataAndNotify(greenhouseId: String, sensorReading: SensorReadingOut) async {
        // Получаем данные теплицы из кэша или загружаем с сервера
        var greenhouse: GreenhouseOut?
        
        if let cached = greenhouseCache[greenhouseId] {
            greenhouse = cached
        } else {
            // Загружаем данные теплицы с сервера
            do {
                greenhouse = try await APIService.shared.getGreenhouse(id: greenhouseId)
                if let gh = greenhouse {
                    greenhouseCache[greenhouseId] = gh
                }
            } catch {
                print("❌ SensorDataManager: Ошибка загрузки данных теплицы \(greenhouseId): \(error)")
                return
            }
        }
        
        guard let gh = greenhouse else {
            print("⚠️ SensorDataManager: Не удалось получить данные теплицы \(greenhouseId)")
            return
        }
        
        // Проверяем, есть ли подключенный датчик
        guard let sensorId = gh.sensor_id, !sensorId.isEmpty else {
            // У теплицы нет подключенного датчика, пропускаем проверку
            return
        }
        
        // Загружаем растения в теплице и их типы для проверки норм
        do {
            let plantInstances = try await APIService.shared.getPlantInstances(greenhouseId: greenhouseId)
            
            // Если в теплице нет растений, проверяем по нормам теплицы
            if plantInstances.isEmpty {
                print("⚠️ SensorDataManager: В теплице \(gh.name) нет растений, проверяем по нормам теплицы")
                await checkGreenhouseNorms(greenhouse: gh, sensorReading: sensorReading, greenhouseId: greenhouseId)
                return
            }
            
            // Загружаем типы растений
            let plantTypes = try await APIService.shared.getPlantTypes()
            let plantTypesDict = Dictionary(uniqueKeysWithValues: plantTypes.map { ($0.id, $0) })
            
            // Проверяем данные датчика против норм всех растений в теплице
            var hasAlert = false
            var alertMessages: [String] = []
            
            for plantInstance in plantInstances {
                guard let plantType = plantTypesDict[plantInstance.plant_type_id] else {
                    continue
                }
                
                // Проверяем температуру для этого растения
                if let tempMin = plantType.temp_min, sensorReading.temperature < tempMin {
                    let message = String(format: "Температура ниже нормы для %@: %.1f°C (минимум: %.1f°C)", 
                                       plantType.name, sensorReading.temperature, tempMin)
                    alertMessages.append(message)
                    hasAlert = true
                    let severity = sensorReading.temperature < tempMin - 5 ? "critical" : "warning"
                    await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                                 greenhouseName: gh.name,
                                                 message: message,
                                                 severity: severity)
                } else if let tempMax = plantType.temp_max, sensorReading.temperature > tempMax {
                    let message = String(format: "Температура выше нормы для %@: %.1f°C (максимум: %.1f°C)", 
                                       plantType.name, sensorReading.temperature, tempMax)
                    alertMessages.append(message)
                    hasAlert = true
                    let severity = sensorReading.temperature > tempMax + 5 ? "critical" : "warning"
                    await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                                 greenhouseName: gh.name,
                                                 message: message,
                                                 severity: severity)
                }
                
                // Проверяем влажность для этого растения
                if let humMin = plantType.humidity_min, sensorReading.humidity < humMin {
                    let message = String(format: "Влажность ниже нормы для %@: %.0f%% (минимум: %.0f%%)", 
                                       plantType.name, sensorReading.humidity, humMin)
                    alertMessages.append(message)
                    hasAlert = true
                    let severity = sensorReading.humidity < humMin - 10 ? "critical" : "warning"
                    await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                                 greenhouseName: gh.name,
                                                 message: message,
                                                 severity: severity)
                } else if let humMax = plantType.humidity_max, sensorReading.humidity > humMax {
                    let message = String(format: "Влажность выше нормы для %@: %.0f%% (максимум: %.0f%%)", 
                                       plantType.name, sensorReading.humidity, humMax)
                    alertMessages.append(message)
                    hasAlert = true
                    let severity = sensorReading.humidity > humMax + 10 ? "critical" : "warning"
                    await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                                 greenhouseName: gh.name,
                                                 message: message,
                                                 severity: severity)
                }
            }
            
            if hasAlert {
                print("⚠️ SensorDataManager: Обнаружены нарушения норм для растений в теплице \(gh.name): \(alertMessages.joined(separator: "; "))")
            } else {
                print("✅ SensorDataManager: Данные датчика в норме для всех растений в теплице \(gh.name)")
            }
            
        } catch {
            print("❌ SensorDataManager: Ошибка загрузки растений или типов растений для теплицы \(gh.name): \(error)")
            // В случае ошибки проверяем по нормам теплицы как fallback
            await checkGreenhouseNorms(greenhouse: gh, sensorReading: sensorReading, greenhouseId: greenhouseId)
        }
    }
    
    /// Проверяет данные датчика по нормам теплицы (fallback, если нет растений)
    private func checkGreenhouseNorms(greenhouse: GreenhouseOut, sensorReading: SensorReadingOut, greenhouseId: String) async {
        // Проверяем температуру
        if let tempMin = greenhouse.target_temp_min, sensorReading.temperature < tempMin {
            let message = String(format: "Температура ниже нормы: %.1f°C (минимум: %.1f°C)", 
                               sensorReading.temperature, tempMin)
            let severity = sensorReading.temperature < tempMin - 5 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId, 
                                         greenhouseName: greenhouse.name,
                                         message: message,
                                         severity: severity)
        } else if let tempMax = greenhouse.target_temp_max, sensorReading.temperature > tempMax {
            let message = String(format: "Температура выше нормы: %.1f°C (максимум: %.1f°C)", 
                               sensorReading.temperature, tempMax)
            let severity = sensorReading.temperature > tempMax + 5 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                         greenhouseName: greenhouse.name,
                                         message: message,
                                         severity: severity)
        }
        
        // Проверяем влажность
        if let humMin = greenhouse.target_hum_min, sensorReading.humidity < humMin {
            let message = String(format: "Влажность ниже нормы: %.0f%% (минимум: %.0f%%)", 
                               sensorReading.humidity, humMin)
            let severity = sensorReading.humidity < humMin - 10 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                         greenhouseName: greenhouse.name,
                                         message: message,
                                         severity: severity)
        } else if let humMax = greenhouse.target_hum_max, sensorReading.humidity > humMax {
            let message = String(format: "Влажность выше нормы: %.0f%% (максимум: %.0f%%)", 
                               sensorReading.humidity, humMax)
            let severity = sensorReading.humidity > humMax + 10 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                         greenhouseName: greenhouse.name,
                                         message: message,
                                         severity: severity)
        }
    }
    
    /// Отправляет уведомление, если прошло достаточно времени с последнего уведомления
    private func sendNotificationIfNeeded(greenhouseId: String, greenhouseName: String, message: String, severity: String) async {
        print("📢 SensorDataManager: Попытка отправить уведомление для теплицы \(greenhouseName): \(message)")
        
        // Проверяем доступ пользователя к теплице
        let hasAccess = await checkUserAccessToGreenhouse(greenhouseId: greenhouseId)
        if !hasAccess {
            print("🚫 SensorDataManager: У пользователя нет доступа к теплице \(greenhouseName) (ID: \(greenhouseId)). Уведомление не будет отправлено.")
            return
        }
        print("✅ SensorDataManager: Пользователь имеет доступ к теплице \(greenhouseName)")
        
        // Проверяем, есть ли разрешение на уведомления
        let hasPermission = await notificationManager.checkAuthorizationStatus()
        if !hasPermission {
            print("⚠️ SensorDataManager: Нет разрешения на отправку уведомлений. Запрашиваем разрешение...")
            // Запрашиваем разрешение еще раз
            notificationManager.requestAuthorization()
            // Проверяем еще раз после запроса
            let hasPermissionAfterRequest = await notificationManager.checkAuthorizationStatus()
            if !hasPermissionAfterRequest {
                print("❌ SensorDataManager: Разрешение на уведомления не получено. Уведомление не будет отправлено.")
                return
            }
            print("✅ SensorDataManager: Разрешение на уведомления получено")
        } else {
            print("✅ SensorDataManager: Разрешение на уведомления есть")
        }
        
        // Проверяем cooldown (чтобы не спамить уведомлениями)
        let now = Date()
        if let lastTime = lastNotificationTime[greenhouseId] {
            let timeSinceLastNotification = now.timeIntervalSince(lastTime)
            print("⏱️ SensorDataManager: Прошло \(Int(timeSinceLastNotification)) секунд с последнего уведомления (cooldown: \(Int(notificationCooldown)) сек)")
            
            if timeSinceLastNotification < notificationCooldown {
                let remainingTime = Int(notificationCooldown - timeSinceLastNotification)
                print("⏸️ SensorDataManager: Cooldown активен, осталось \(remainingTime) секунд. Уведомление не будет отправлено.")
                return
            }
        } else {
            print("📢 SensorDataManager: Это первое уведомление для этой теплицы")
        }
        
        // Отправляем уведомление
        print("📤 SensorDataManager: Отправка уведомления через NotificationManager...")
        notificationManager.sendSensorAlertNotification(
            greenhouseId: greenhouseId,
            greenhouseName: greenhouseName,
            message: message,
            severity: severity
        )
        
        // Обновляем время последнего уведомления
        lastNotificationTime[greenhouseId] = now
        print("✅ SensorDataManager: Уведомление отправлено, время обновлено")
    }
    
    /// Проверяет, есть ли у текущего пользователя доступ к теплице
    private func checkUserAccessToGreenhouse(greenhouseId: String) async -> Bool {
        guard let currentUser = AuthManager.shared.currentUser else {
            print("⚠️ SensorDataManager: Пользователь не авторизован")
            return false
        }
        
        // Админы имеют доступ ко всем теплицам
        if currentUser.role == "admin" {
            print("✅ SensorDataManager: Пользователь - админ, доступ ко всем теплицам")
            return true
        }
        
        // Для воркеров проверяем доступ к теплице
        if currentUser.role == "worker" {
            do {
                // Пытаемся получить теплицу - если получится, значит есть доступ
                // Если нет доступа, сервер вернет 403
                _ = try await APIService.shared.getGreenhouse(id: greenhouseId)
                print("✅ SensorDataManager: Воркер имеет доступ к теплице \(greenhouseId)")
                return true
            } catch let error as APIError {
                if error.detail.contains("Нет доступа") || error.detail.contains("доступа") || error.detail.contains("403") {
                    print("🚫 SensorDataManager: Воркер не имеет доступа к теплице \(greenhouseId)")
                    return false
                } else {
                    // Другие ошибки (например, 404) - считаем, что доступа нет
                    print("⚠️ SensorDataManager: Ошибка при проверке доступа к теплице \(greenhouseId): \(error.detail)")
                    return false
                }
            } catch {
                print("⚠️ SensorDataManager: Неожиданная ошибка при проверке доступа к теплице \(greenhouseId): \(error.localizedDescription)")
                return false
            }
        }
        
        // Для других ролей (если появятся) - по умолчанию нет доступа
        print("⚠️ SensorDataManager: Неизвестная роль пользователя: \(currentUser.role)")
        return false
    }
}

