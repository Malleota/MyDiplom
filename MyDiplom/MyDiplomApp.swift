//
//  MyDiplomApp.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

@main
struct MyDiplomApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sensorDataManager = SensorDataManager.shared
    @StateObject private var wateringDataManager = WateringDataManager.shared
    @StateObject private var fertilizingDataManager = FertilizingDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(sensorDataManager)
                    .environmentObject(wateringDataManager)
                    .environmentObject(fertilizingDataManager)
                    .task {
                        // Обновляем данные подключения датчика сразу при входе в приложение
                        await loadSensorDataOnAppStart()
                    }
            } else {
                AuthContainerView()
            }
        }
    }
    
    /// Загружает данные датчиков для всех теплиц при входе в приложение
    private func loadSensorDataOnAppStart() async {
        do {
            // Загружаем список теплиц
            let greenhouses = try await APIService.shared.getGreenhouses()
            
            // Проверяем, есть ли теплицы с датчиками
            let greenhousesWithSensors = greenhouses.filter { greenhouse in
                guard let sensorId = greenhouse.sensor_id, !sensorId.isEmpty else {
                    return false
                }
                return true
            }
            
            // Если есть теплицы с датчиками, регистрируем экран и загружаем данные
            if !greenhousesWithSensors.isEmpty {
                await MainActor.run {
                    // Регистрируем активный экран для подключения к WebSocket
                    sensorDataManager.registerActiveScreen()
                }
                
                // Параллельно загружаем данные для всех теплиц с датчиками
                await withTaskGroup(of: Void.self) { group in
                    for greenhouse in greenhousesWithSensors {
                        group.addTask {
                            await MainActor.run {
                                // Регистрируем теплицу для отслеживания
                                sensorDataManager.registerGreenhouse(greenhouseId: greenhouse.id)
                            }
                            // Загружаем начальные данные датчика
                            await sensorDataManager.loadSensorDataForGreenhouse(greenhouse)
                        }
                    }
                }
            }
        } catch {
            print("❌ MyDiplomApp: Ошибка загрузки данных датчиков при входе в приложение: \(error)")
        }
    }
}
