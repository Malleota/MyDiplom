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
    
    private init() {
        websocketManager = WebSocketManager.shared
        
        // Настраиваем callback для обновлений данных через WebSocket
        websocketManager.onSensorDataUpdate = { [weak self] greenhouseId, sensorReading in
            Task { @MainActor in
                self?.handleSensorDataUpdate(greenhouseId: greenhouseId, sensorReading: sensorReading)
            }
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
        print("📡 SensorDataManager: Обновление данных датчика для теплицы \(greenhouseId) через WebSocket")
        sensorData[greenhouseId] = sensorReading
        
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
        
        // Регистрируем теплицу для отслеживания
        registerGreenhouse(greenhouseId: greenhouse.id)
        
        // Загружаем начальные данные с сервера (если еще нет данных)
        if sensorData[greenhouse.id] == nil {
            do {
                if let serverData = try await APIService.shared.getCurrentSensorData(greenhouseId: greenhouse.id) {
                    print("📡 SensorDataManager: Загружены начальные данные с сервера для теплицы \(greenhouse.name)")
                    sensorData[greenhouse.id] = serverData
                    
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
    
    /// Получает данные датчика для теплицы (из кэша)
    func getSensorData(greenhouseId: String) -> SensorReadingOut? {
        return sensorData[greenhouseId]
    }
    
    /// Очищает данные для конкретной теплицы
    func clearSensorData(greenhouseId: String) {
        sensorData.removeValue(forKey: greenhouseId)
        unregisterGreenhouse(greenhouseId: greenhouseId)
    }
    
    /// Очищает все данные
    func clearAllSensorData() {
        sensorData.removeAll()
        trackedGreenhouseIds.removeAll()
        disconnectWebSocket()
    }
}

