//
//  SensorDataManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

/// Глобальный менеджер для обновления данных датчиков со всех теплиц
/// Запускается только когда есть активные экраны с запросом sensor_id
@MainActor
class SensorDataManager: ObservableObject {
    static let shared = SensorDataManager()
    
    @Published var sensorData: [String: SensorReadingOut] = [:] // greenhouseId -> SensorReadingOut
    
    private var refreshTask: Task<Void, Never>?
    private var notificationCancellable: AnyCancellable?
    private var activeScreensCount: Int = 0 // Счетчик активных экранов с sensor_id
    
    private init() {
        setupNotificationObserver()
    }
    
    /// Настраивает наблюдатель уведомлений об отправке данных
    private func setupNotificationObserver() {
        notificationCancellable = NotificationCenter.default.publisher(for: NSNotification.Name("SensorDataSent"))
            .sink { [weak self] notification in
                Task { @MainActor in
                    if let userInfo = notification.userInfo,
                       let bleIdentifier = userInfo["ble_identifier"] as? String {
                        await self?.refreshSensorDataForBleIdentifier(bleIdentifier)
                    }
                }
            }
    }
    
    /// Регистрирует активный экран с запросом sensor_id
    func registerActiveScreen() {
        activeScreensCount += 1
        print("📱 SensorDataManager: Зарегистрирован активный экран (всего: \(activeScreensCount))")
        
        // Запускаем обновление, если это первый активный экран
        if activeScreensCount == 1 {
            startPeriodicRefresh()
        }
    }
    
    /// Отменяет регистрацию активного экрана
    func unregisterActiveScreen() {
        activeScreensCount = max(0, activeScreensCount - 1)
        print("📱 SensorDataManager: Отменена регистрация экрана (осталось: \(activeScreensCount))")
        
        // Останавливаем обновление, если нет активных экранов
        if activeScreensCount == 0 {
            stopPeriodicRefresh()
        }
    }
    
    /// Запускает периодическое обновление данных для всех теплиц с sensor_id
    private func startPeriodicRefresh() {
        // Останавливаем предыдущую задачу, если она есть
        stopPeriodicRefresh()
        
        print("🔄 SensorDataManager: Запуск периодического обновления данных")
        
        // Запускаем задачу, которая будет периодически запрашивать данные с сервера
        refreshTask = Task { @MainActor in
            var iteration = 0
            while !Task.isCancelled {
                iteration += 1
                
                // Получаем все теплицы с sensor_id
                let greenhousesWithSensors = await self.getAllGreenhousesWithSensors()
                
                if !greenhousesWithSensors.isEmpty {
                    print("🔄 SensorDataManager: [Итерация \(iteration)] Обновление данных для \(greenhousesWithSensors.count) теплиц")
                    
                    // Обновляем данные для всех теплиц с sensor_id
                    for greenhouse in greenhousesWithSensors {
                        await self.loadSensorDataForGreenhouse(greenhouse)
                    }
                } else {
                    print("⚠️ SensorDataManager: [Итерация \(iteration)] Нет теплиц с sensor_id, пропускаем запрос")
                }
                
                // Ждем 5 секунд перед следующим запросом
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 секунд
            }
            print("⏹️ SensorDataManager: Периодическое обновление остановлено (Task cancelled)")
        }
        print("✅ SensorDataManager: Периодическое обновление запущено (каждые 5 секунд)")
    }
    
    /// Останавливает периодическое обновление данных
    private func stopPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        print("⏹️ SensorDataManager: Периодическое обновление остановлено")
    }
    
    /// Получает все теплицы с sensor_id с сервера
    private func getAllGreenhousesWithSensors() async -> [GreenhouseOut] {
        do {
            let allGreenhouses = try await APIService.shared.getGreenhouses()
            return allGreenhouses.filter { greenhouse in
                guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
                    return false
                }
                return true
            }
        } catch {
            print("❌ SensorDataManager: Ошибка загрузки теплиц: \(error)")
            return []
        }
    }
    
    /// Загружает данные датчика для конкретной теплицы
    func loadSensorDataForGreenhouse(_ greenhouse: GreenhouseOut) async {
        guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
            return
        }
        
        do {
            if let serverData = try await APIService.shared.getCurrentSensorData(greenhouseId: greenhouse.id) {
                print("📡 SensorDataManager: Загружены данные с сервера для теплицы \(greenhouse.name)")
                sensorData[greenhouse.id] = serverData
                
                // Отправляем уведомление об обновлении данных
                NotificationCenter.default.post(
                    name: NSNotification.Name("SensorDataUpdated"),
                    object: nil,
                    userInfo: ["greenhouse_id": greenhouse.id, "sensor_data": serverData]
                )
            }
        } catch {
            print("❌ SensorDataManager: Ошибка загрузки данных с сервера для теплицы \(greenhouse.name): \(error)")
        }
    }
    
    /// Обновляет данные датчика для конкретного ble_identifier
    func refreshSensorDataForBleIdentifier(_ bleIdentifier: String) async {
        // Получаем все теплицы
        let allGreenhouses = await getAllGreenhousesWithSensors()
        
        // Находим все теплицы с этим ble_identifier
        let matchingGreenhouses = allGreenhouses.filter { greenhouse in
            let savedBLE = UserDefaults.standard.string(forKey: "greenhouse_\(greenhouse.id)_ble_identifier")
            return savedBLE == bleIdentifier
        }
        
        // Обновляем данные для всех найденных теплиц
        for greenhouse in matchingGreenhouses {
            await loadSensorDataForGreenhouse(greenhouse)
        }
    }
    
    /// Получает данные датчика для теплицы (из кэша или загружает)
    func getSensorData(greenhouseId: String) -> SensorReadingOut? {
        return sensorData[greenhouseId]
    }
    
    /// Очищает данные для конкретной теплицы
    func clearSensorData(greenhouseId: String) {
        sensorData.removeValue(forKey: greenhouseId)
    }
    
    /// Очищает все данные
    func clearAllSensorData() {
        sensorData.removeAll()
    }
}

