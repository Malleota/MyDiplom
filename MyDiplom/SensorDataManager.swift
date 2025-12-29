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
        
        // Подключаемся к WebSocket, если это первый активный экран
        if activeScreensCount == 1 {
            connectWebSocket()
        }
    }
    
    /// Отменяет регистрацию активного экрана
    func unregisterActiveScreen() {
        activeScreensCount = max(0, activeScreensCount - 1)
        
        // Отключаемся от WebSocket, если нет активных экранов
        if activeScreensCount == 0 {
            disconnectWebSocket()
        }
    }
    
    /// Регистрирует теплицу для отслеживания через WebSocket
    func registerGreenhouse(greenhouseId: String) {
        trackedGreenhouseIds.insert(greenhouseId)
        
        // Если WebSocket уже подключен, переподключаемся для обновления списка
        if activeScreensCount > 0 {
            connectWebSocket()
        }
    }
    
    /// Отменяет регистрацию теплицы
    func unregisterGreenhouse(greenhouseId: String) {
        trackedGreenhouseIds.remove(greenhouseId)
        
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
            websocketManager.connectForAll()
        } else if !trackedGreenhouseIds.isEmpty {
            // Для обычных пользователей подключаемся к первой теплице
            // Если отслеживается несколько теплиц, подключаемся к первой
            // (WebSocket endpoint поддерживает только одну теплицу за раз для не-админов)
            if let firstGreenhouseId = trackedGreenhouseIds.first {
                websocketManager.connect(greenhouseId: firstGreenhouseId)
            }
        }
    }
    
    /// Отключается от WebSocket
    private func disconnectWebSocket() {
        websocketManager.disconnect()
    }
    
    /// Обрабатывает обновление данных датчика через WebSocket
    private func handleSensorDataUpdate(greenhouseId: String, sensorReading: SensorReadingOut) {
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
                    sensorData[greenhouse.id] = serverData
                    
                    // Проверяем данные на соответствие нормам
                    await checkSensorDataAndNotify(greenhouseId: greenhouse.id, sensorReading: serverData)
                    
                    // Отправляем уведомление об обновлении данных
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SensorDataUpdated"),
                        object: nil,
                        userInfo: ["greenhouse_id": greenhouse.id, "sensor_data": serverData]
                    )
                }
            } catch {
                print("❌ SensorDataManager: Ошибка загрузки начальных данных с сервера для теплицы \(greenhouse.name): \(error)")
            }
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
        
        // Проверяем температуру
        if let tempMin = gh.target_temp_min, sensorReading.temperature < tempMin {
            let message = String(format: "Температура ниже нормы: %.1f°C (минимум: %.1f°C)", 
                               sensorReading.temperature, tempMin)
            let severity = sensorReading.temperature < tempMin - 5 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId, 
                                         greenhouseName: gh.name,
                                         message: message,
                                         severity: severity)
        } else if let tempMax = gh.target_temp_max, sensorReading.temperature > tempMax {
            let message = String(format: "Температура выше нормы: %.1f°C (максимум: %.1f°C)", 
                               sensorReading.temperature, tempMax)
            let severity = sensorReading.temperature > tempMax + 5 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                         greenhouseName: gh.name,
                                         message: message,
                                         severity: severity)
        }
        
        // Проверяем влажность
        if let humMin = gh.target_hum_min, sensorReading.humidity < humMin {
            let message = String(format: "Влажность ниже нормы: %.0f%% (минимум: %.0f%%)", 
                               sensorReading.humidity, humMin)
            let severity = sensorReading.humidity < humMin - 10 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                         greenhouseName: gh.name,
                                         message: message,
                                         severity: severity)
        } else if let humMax = gh.target_hum_max, sensorReading.humidity > humMax {
            let message = String(format: "Влажность выше нормы: %.0f%% (максимум: %.0f%%)", 
                               sensorReading.humidity, humMax)
            let severity = sensorReading.humidity > humMax + 10 ? "critical" : "warning"
            await sendNotificationIfNeeded(greenhouseId: greenhouseId,
                                         greenhouseName: gh.name,
                                         message: message,
                                         severity: severity)
        }
    }
    
    /// Отправляет уведомление, если прошло достаточно времени с последнего уведомления
    private func sendNotificationIfNeeded(greenhouseId: String, greenhouseName: String, message: String, severity: String) async {
        // Проверяем, есть ли разрешение на уведомления
        let hasPermission = await notificationManager.checkAuthorizationStatus()
        guard hasPermission else {
            print("⚠️ SensorDataManager: Нет разрешения на отправку уведомлений")
            return
        }
        
        // Проверяем cooldown (чтобы не спамить уведомлениями)
        let now = Date()
        if let lastTime = lastNotificationTime[greenhouseId],
           now.timeIntervalSince(lastTime) < notificationCooldown {
            // Еще не прошло достаточно времени с последнего уведомления
            return
        }
        
        // Отправляем уведомление
        notificationManager.sendSensorAlertNotification(
            greenhouseName: greenhouseName,
            message: message,
            severity: severity
        )
        
        // Обновляем время последнего уведомления
        lastNotificationTime[greenhouseId] = now
    }
}

