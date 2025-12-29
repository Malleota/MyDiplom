//
//  NotificationStore.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

/// Модель внутреннего уведомления приложения
struct AppNotification: Identifiable, Codable {
    let id: String
    let type: String // "sensor_alert", "watering_reminder", etc.
    let greenhouseId: String?
    let greenhouseName: String?
    let title: String
    let message: String
    let severity: String // "critical", "warning", "info"
    let isRead: Bool
    let createdAt: Date
    
    // Для Codable с Date используем timestamp
    enum CodingKeys: String, CodingKey {
        case id, type, greenhouseId, greenhouseName, title, message, severity, isRead
        case createdAtTimestamp
    }
    
    init(id: String = UUID().uuidString,
         type: String,
         greenhouseId: String?,
         greenhouseName: String?,
         title: String,
         message: String,
         severity: String = "warning",
         isRead: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.greenhouseId = greenhouseId
        self.greenhouseName = greenhouseName
        self.title = title
        self.message = message
        self.severity = severity
        self.isRead = isRead
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        greenhouseId = try container.decodeIfPresent(String.self, forKey: .greenhouseId)
        greenhouseName = try container.decodeIfPresent(String.self, forKey: .greenhouseName)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        severity = try container.decode(String.self, forKey: .severity)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        let timestamp = try container.decode(TimeInterval.self, forKey: .createdAtTimestamp)
        createdAt = Date(timeIntervalSince1970: timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(greenhouseId, forKey: .greenhouseId)
        try container.encodeIfPresent(greenhouseName, forKey: .greenhouseName)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(severity, forKey: .severity)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(createdAt.timeIntervalSince1970, forKey: .createdAtTimestamp)
    }
    
    // Реализация Equatable
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Менеджер для хранения и управления внутренними уведомлениями приложения
@MainActor
class NotificationStore: ObservableObject {
    static let shared = NotificationStore()
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    
    private let notificationsKey = "AppNotifications"
    private let maxNotifications = 100 // Максимальное количество хранимых уведомлений
    
    private init() {
        loadNotifications()
    }
    
    /// Загружает уведомления из UserDefaults
    private func loadNotifications() {
        guard let data = UserDefaults.standard.data(forKey: notificationsKey),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else {
            notifications = []
            updateUnreadCount()
            return
        }
        
        notifications = decoded.sorted { $0.createdAt > $1.createdAt }
        updateUnreadCount()
    }
    
    /// Сохраняет уведомления в UserDefaults
    private func saveNotifications() {
        // Ограничиваем количество уведомлений
        if notifications.count > maxNotifications {
            notifications = Array(notifications.prefix(maxNotifications))
        }
        
        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(encoded, forKey: notificationsKey)
        }
        updateUnreadCount()
    }
    
    /// Обновляет счетчик непрочитанных уведомлений
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    /// Проверяет, есть ли уже такое же уведомление (по типу, теплице и сообщению)
    func hasDuplicateNotification(type: String, greenhouseId: String?, message: String, withinMinutes: Int = 60) -> Bool {
        let cutoffTime = Date().addingTimeInterval(-Double(withinMinutes * 60))
        
        // Извлекаем ключевую информацию из сообщения для более точной проверки
        // Например, "Влажность выше нормы для Огурцы" - проверяем по началу сообщения
        let messageKey = extractMessageKey(message)
        
        return notifications.contains { notification in
            guard notification.type == type,
                  notification.greenhouseId == greenhouseId,
                  notification.createdAt > cutoffTime else {
                return false
            }
            
            // Проверяем либо полное совпадение сообщения, либо совпадение ключа
            let notificationKey = extractMessageKey(notification.message)
            return notification.message == message || notificationKey == messageKey
        }
    }
    
    /// Извлекает ключевую часть сообщения для проверки на дубликаты
    /// Например: "Влажность выше нормы для Огурцы: 41% (максимум: 25%)" -> "Влажность выше нормы для Огурцы"
    private func extractMessageKey(_ message: String) -> String {
        // Ищем паттерны типа "Температура выше/ниже нормы для..." или "Влажность выше/ниже нормы для..."
        if let range = message.range(of: " для ") {
            let prefix = String(message[..<range.upperBound])
            // Извлекаем название растения (до двоеточия, если есть)
            if let colonRange = message.range(of: ":", range: range.upperBound..<message.endIndex) {
                let plantName = String(message[range.upperBound..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                return prefix + plantName
            }
            return prefix
        }
        // Если паттерн не найден, возвращаем первые 50 символов
        return String(message.prefix(50))
    }
    
    /// Добавляет новое уведомление, если такого еще нет
    func addNotificationIfNotDuplicate(_ notification: AppNotification, withinMinutes: Int = 60) -> Bool {
        // Проверяем, есть ли уже такое же уведомление
        if hasDuplicateNotification(
            type: notification.type,
            greenhouseId: notification.greenhouseId,
            message: notification.message,
            withinMinutes: withinMinutes
        ) {
            print("⚠️ NotificationStore: Пропущено дублирующее уведомление: \(notification.message)")
            return false
        }
        
        notifications.insert(notification, at: 0) // Добавляем в начало
        saveNotifications()
        print("📬 NotificationStore: Добавлено уведомление: \(notification.title)")
        return true
    }
    
    /// Добавляет новое уведомление (без проверки на дубликаты)
    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0) // Добавляем в начало
        saveNotifications()
        print("📬 NotificationStore: Добавлено уведомление: \(notification.title)")
    }
    
    /// Помечает уведомление как прочитанное
    func markAsRead(_ notificationId: String) {
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            let notification = notifications[index]
            let updated = AppNotification(
                id: notification.id,
                type: notification.type,
                greenhouseId: notification.greenhouseId,
                greenhouseName: notification.greenhouseName,
                title: notification.title,
                message: notification.message,
                severity: notification.severity,
                isRead: true,
                createdAt: notification.createdAt
            )
            notifications[index] = updated
            saveNotifications()
        }
    }
    
    /// Помечает все уведомления как прочитанные
    func markAllAsRead() {
        notifications = notifications.map { notification in
            AppNotification(
                id: notification.id,
                type: notification.type,
                greenhouseId: notification.greenhouseId,
                greenhouseName: notification.greenhouseName,
                title: notification.title,
                message: notification.message,
                severity: notification.severity,
                isRead: true,
                createdAt: notification.createdAt
            )
        }
        saveNotifications()
    }
    
    /// Удаляет уведомление
    func removeNotification(_ notificationId: String) {
        notifications.removeAll { $0.id == notificationId }
        saveNotifications()
    }
    
    /// Удаляет все уведомления
    func clearAllNotifications() {
        notifications.removeAll()
        saveNotifications()
    }
    
    /// Удаляет все прочитанные уведомления
    func clearReadNotifications() {
        notifications.removeAll { $0.isRead }
        saveNotifications()
    }
}

