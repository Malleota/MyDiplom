//
//  WateringDataManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

/// Менеджер для управления данными о поливах теплиц
@MainActor
class WateringDataManager: ObservableObject {
    static let shared = WateringDataManager()
    
    @Published var nextWateringData: [String: NextWateringOut] = [:] // greenhouseId -> NextWateringOut
    @Published var wateringEvents: [String: [WaterEventOut]] = [:] // greenhouseId -> [WaterEventOut]
    
    private init() {}
    
    /// Загружает данные о следующем поливе для теплицы
    func loadNextWateringForGreenhouse(_ greenhouse: GreenhouseOut) async {
        do {
            if let nextWatering = try await APIService.shared.getNextWatering(greenhouseId: greenhouse.id) {
                print("💧 WateringDataManager: Загружены данные о следующем поливе для теплицы \(greenhouse.name), days_until=\(nextWatering.days_until?.description ?? "nil")")
                // Сохраняем данные, даже если все поля None (это означает, что поливов нет)
                nextWateringData[greenhouse.id] = nextWatering
                
                // Отправляем уведомление об обновлении
                NotificationCenter.default.post(
                    name: NSNotification.Name("NextWateringUpdated"),
                    object: nil,
                    userInfo: ["greenhouse_id": greenhouse.id, "next_watering": nextWatering]
                )
            } else {
                // Если API вернул nil (404 или другая ошибка), удаляем из кэша
                nextWateringData.removeValue(forKey: greenhouse.id)
            }
        } catch {
            print("❌ WateringDataManager: Ошибка загрузки данных о поливе для теплицы \(greenhouse.name): \(error)")
        }
    }
    
    /// Загружает события полива для теплицы
    func loadWateringEventsForGreenhouse(_ greenhouseId: String, dateFrom: String? = nil, dateTo: String? = nil) async {
        do {
            let events = try await APIService.shared.getWateringEvents(
                greenhouseId: greenhouseId,
                dateFrom: dateFrom,
                dateTo: dateTo
            )
            wateringEvents[greenhouseId] = events
            print("💧 WateringDataManager: Загружено \(events.count) событий полива для теплицы \(greenhouseId)")
        } catch {
            print("❌ WateringDataManager: Ошибка загрузки событий полива: \(error)")
        }
    }
    
    /// Получает данные о следующем поливе для теплицы
    func getNextWatering(greenhouseId: String) -> NextWateringOut? {
        return nextWateringData[greenhouseId]
    }
    
    /// Получает события полива для теплицы
    func getWateringEvents(greenhouseId: String) -> [WaterEventOut] {
        return wateringEvents[greenhouseId] ?? []
    }
    
    /// Очищает данные для конкретной теплицы
    func clearData(greenhouseId: String) {
        nextWateringData.removeValue(forKey: greenhouseId)
        wateringEvents.removeValue(forKey: greenhouseId)
    }
    
    /// Очищает все данные
    func clearAllData() {
        nextWateringData.removeAll()
        wateringEvents.removeAll()
    }
}

