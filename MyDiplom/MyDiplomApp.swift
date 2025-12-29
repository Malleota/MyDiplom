//
//  MyDiplomApp.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI
import UserNotifications

@main
struct MyDiplomApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sensorDataManager = SensorDataManager.shared
    @StateObject private var wateringDataManager = WateringDataManager.shared
    @StateObject private var fertilizingDataManager = FertilizingDataManager.shared
    
    init() {
        // Настраиваем делегат для уведомлений, чтобы они показывались даже когда приложение активно
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
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

// MARK: - Notification Delegate для показа уведомлений в foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Показываем уведомления даже когда приложение активно
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📢 NotificationDelegate: Уведомление получено в foreground: \(notification.request.content.title)")
        // Показываем уведомление с баннером и звуком
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Обработка нажатия на уведомление
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📢 NotificationDelegate: Пользователь нажал на уведомление: \(response.notification.request.content.title)")
        print("📢 NotificationDelegate: UserInfo: \(userInfo)")
        
        // Проверяем, является ли это уведомлением о датчике
        if let type = userInfo["type"] as? String, type == "sensor_alert",
           let greenhouseId = userInfo["greenhouse_id"] as? String {
            print("📢 NotificationDelegate: Навигация к теплице с ID: \(greenhouseId)")
            
            // Отправляем уведомление через NotificationCenter для обработки в UI
            // Используем главный поток для гарантии, что UI обновится
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToGreenhouse"),
                    object: nil,
                    userInfo: ["greenhouse_id": greenhouseId]
                )
                print("✅ NotificationDelegate: Уведомление NavigateToGreenhouse отправлено для теплицы \(greenhouseId)")
            }
        } else {
            print("⚠️ NotificationDelegate: Уведомление не содержит нужных данных для навигации")
        }
        
        completionHandler()
    }
}
