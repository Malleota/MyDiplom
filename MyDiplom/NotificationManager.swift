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
        print("🔔 NotificationManager: Запрос разрешения на уведомления...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ NotificationManager: Ошибка запроса разрешения: \(error.localizedDescription)")
            } else if granted {
                print("✅ NotificationManager: Разрешение на уведомления получено")
            } else {
                print("⚠️ NotificationManager: Разрешение на уведомления отклонено пользователем")
            }
        }
    }
    
    /// Отправляет уведомление о выходе показателей датчика за норму
    /// - Parameters:
    ///   - greenhouseId: ID теплицы для навигации
    ///   - greenhouseName: Название теплицы
    ///   - message: Текст сообщения
    ///   - severity: Уровень серьезности ("critical" или "warning")
    func sendSensorAlertNotification(
        greenhouseId: String,
        greenhouseName: String,
        message: String,
        severity: String = "warning"
    ) {
        print("📤 NotificationManager: Создание уведомления - теплица: \(greenhouseName) (ID: \(greenhouseId)), сообщение: \(message), серьезность: \(severity)")
        
        // Проверяем на дубликаты перед отправкой
        Task { @MainActor in
            let appNotification = AppNotification(
                type: "sensor_alert",
                greenhouseId: greenhouseId,
                greenhouseName: greenhouseName,
                title: "⚠️ Предупреждение: \(greenhouseName)",
                message: message,
                severity: severity
            )
            
            // Проверяем, есть ли уже такое же уведомление (в течение последнего часа)
            if NotificationStore.shared.hasDuplicateNotification(
                type: "sensor_alert",
                greenhouseId: greenhouseId,
                message: message,
                withinMinutes: 60
            ) {
                print("⚠️ NotificationManager: Пропущено дублирующее уведомление для теплицы \(greenhouseName): \(message)")
                return
            }
            
            // Добавляем уведомление в хранилище
            NotificationStore.shared.addNotification(appNotification)
            
            // Отправляем push-уведомление
            await sendPushNotification(
                greenhouseId: greenhouseId,
                greenhouseName: greenhouseName,
                message: message,
                severity: severity
            )
        }
    }
    
    /// Отправляет push-уведомление в систему
    private func sendPushNotification(
        greenhouseId: String,
        greenhouseName: String,
        message: String,
        severity: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Предупреждение: \(greenhouseName)"
        content.body = message
        content.sound = .default
        
        // Добавляем userInfo с ID теплицы для навигации
        content.userInfo = [
            "greenhouse_id": greenhouseId,
            "type": "sensor_alert"
        ]
        
        // Устанавливаем категорию для возможности действий
        content.categoryIdentifier = "SENSOR_ALERT"
        
        // Увеличиваем важность для критических уведомлений
        if severity == "critical" {
            content.interruptionLevel = .critical
            print("🔴 NotificationManager: Критический уровень уведомления")
        } else {
            content.interruptionLevel = .active
            print("🟡 NotificationManager: Предупреждающий уровень уведомления")
        }
        
        // Создаем уникальный идентификатор для уведомления
        let identifier = "sensor_alert_\(UUID().uuidString)"
        print("📤 NotificationManager: Идентификатор уведомления: \(identifier)")
        
        // Отправляем уведомление немедленно
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // nil означает немедленную отправку
        )
        
        print("📤 NotificationManager: Добавление запроса уведомления в центр уведомлений...")
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Ошибка отправки уведомления: \(error.localizedDescription)")
                print("❌ NotificationManager: Детали ошибки: \(error)")
            } else {
                print("✅ NotificationManager: Уведомление успешно добавлено в центр уведомлений")
            }
        }
    }
    
    /// Проверяет, есть ли разрешение на отправку уведомлений
    func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        print("🔔 NotificationManager: Статус разрешения на уведомления: \(status.rawValue) (\(status == .authorized ? "разрешено" : status == .denied ? "отклонено" : status == .notDetermined ? "не определено" : "provisional"))")
        return status == .authorized
    }
}

