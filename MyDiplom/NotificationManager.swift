//
//  NotificationManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import UserNotifications

/// Менеджер для управления локальными push-уведомлениями
@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    /// Запрашивает разрешение на отправку уведомлений
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ NotificationManager: Ошибка запроса разрешения: \(error.localizedDescription)")
            }
        }
    }
    
    /// Отправляет уведомление о выходе показателей датчика за норму
    /// - Parameters:
    ///   - greenhouseName: Название теплицы
    ///   - message: Текст сообщения
    ///   - severity: Уровень серьезности ("critical" или "warning")
    func sendSensorAlertNotification(
        greenhouseName: String,
        message: String,
        severity: String = "warning"
    ) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Предупреждение: \(greenhouseName)"
        content.body = message
        content.sound = .default
        
        // Устанавливаем категорию для возможности действий
        content.categoryIdentifier = "SENSOR_ALERT"
        
        // Увеличиваем важность для критических уведомлений
        if severity == "critical" {
            content.interruptionLevel = .critical
        } else {
            content.interruptionLevel = .active
        }
        
        // Создаем уникальный идентификатор для уведомления
        let identifier = "sensor_alert_\(UUID().uuidString)"
        
        // Отправляем уведомление немедленно
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // nil означает немедленную отправку
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Ошибка отправки уведомления: \(error.localizedDescription)")
            }
        }
    }
    
    /// Проверяет, есть ли разрешение на отправку уведомлений
    func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}

