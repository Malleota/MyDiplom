//
//  FertilizingDataManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

/// Менеджер для управления данными об удобрениях теплиц
@MainActor
class FertilizingDataManager: ObservableObject {
    static let shared = FertilizingDataManager()
    
    @Published var nextFertilizingData: [String: NextWateringOut] = [:] // greenhouseId -> NextWateringOut (ближайшее удобрение среди всех растений)
    @Published var fertilizingEvents: [String: [WaterEventOut]] = [:] // greenhouseId -> [WaterEventOut]
    
    private init() {}
    
    /// Загружает данные о следующем удобрении для теплицы
    /// Находит растение, которое потребует удобрения раньше всех
    func loadNextFertilizingForGreenhouse(_ greenhouse: GreenhouseOut) async {
        do {
            // Загружаем данные об удобрении для всех растений в теплице
            let plantFertilizings = try await APIService.shared.getNextFertilizingForPlants(greenhouseId: greenhouse.id)
            
            if plantFertilizings.isEmpty {
                // Если нет растений, используем общий эндпоинт для теплицы
                if let nextFertilizing = try await APIService.shared.getNextFertilizing(greenhouseId: greenhouse.id) {
                    print("🌿 FertilizingDataManager: Загружены данные о следующем удобрении для теплицы \(greenhouse.name) (нет растений), days_until=\(nextFertilizing.days_until?.description ?? "nil")")
                    nextFertilizingData[greenhouse.id] = nextFertilizing
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NextFertilizingUpdated"),
                        object: nil,
                        userInfo: ["greenhouse_id": greenhouse.id, "next_fertilizing": nextFertilizing]
                    )
                } else {
                    nextFertilizingData.removeValue(forKey: greenhouse.id)
                }
                return
            }
            
            // Находим растение с минимальным days_until
            // Приоритет: просроченные удобрения (самое просроченное) > непросроченные (ближайшее)
            var closestFertilizing: NextWateringOut?
            var minDaysUntil: Int? = nil
            var hasOverdue = false
            
            for fertilizing in plantFertilizings {
                if let daysUntil = fertilizing.days_until {
                    // Если это просроченное удобрение
                    if fertilizing.is_overdue {
                        // Просроченные имеют приоритет
                        if !hasOverdue {
                            // Первое просроченное - берем его
                            hasOverdue = true
                            minDaysUntil = daysUntil
                            closestFertilizing = fertilizing
                        } else {
                            // Среди просроченных берем самое просроченное (минимальный days_until, т.к. он отрицательный)
                            if daysUntil < minDaysUntil! {
                                minDaysUntil = daysUntil
                                closestFertilizing = fertilizing
                            }
                        }
                    } else {
                        // Непросроченное удобрение
                        if !hasOverdue {
                            // Если еще не нашли просроченных, ищем ближайшее непросроченное
                            if minDaysUntil == nil || daysUntil < minDaysUntil! {
                                minDaysUntil = daysUntil
                                closestFertilizing = fertilizing
                            }
                        }
                        // Если уже есть просроченные, игнорируем непросроченные
                    }
                } else {
                    // Если нет days_until, но есть дата удобрения, это менее приоритетно
                    // Используем только если нет других вариантов
                    if closestFertilizing == nil {
                        closestFertilizing = fertilizing
                    }
                }
            }
            
            // Если нашли ближайшее удобрение, сохраняем его
            if let closest = closestFertilizing {
                print("🌿 FertilizingDataManager: Найдено ближайшее удобрение для теплицы \(greenhouse.name): растение '\(closest.plant_name ?? "неизвестно")', days_until=\(closest.days_until?.description ?? "nil"), is_overdue=\(closest.is_overdue)")
                nextFertilizingData[greenhouse.id] = closest
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("NextFertilizingUpdated"),
                    object: nil,
                    userInfo: ["greenhouse_id": greenhouse.id, "next_fertilizing": closest]
                )
            } else {
                // Если не нашли, удаляем из кэша
                nextFertilizingData.removeValue(forKey: greenhouse.id)
            }
        } catch {
            print("❌ FertilizingDataManager: Ошибка загрузки данных об удобрении для теплицы \(greenhouse.name): \(error)")
        }
    }
    
    /// Загружает события удобрения для теплицы
    func loadFertilizingEventsForGreenhouse(_ greenhouseId: String, dateFrom: String? = nil, dateTo: String? = nil) async {
        do {
            let events = try await APIService.shared.getFertilizingEvents(
                greenhouseId: greenhouseId,
                dateFrom: dateFrom,
                dateTo: dateTo
            )
            fertilizingEvents[greenhouseId] = events
            print("🌿 FertilizingDataManager: Загружено \(events.count) событий удобрения для теплицы \(greenhouseId)")
        } catch {
            print("❌ FertilizingDataManager: Ошибка загрузки событий удобрения: \(error)")
        }
    }
    
    /// Получает данные о следующем удобрении для теплицы
    func getNextFertilizing(greenhouseId: String) -> NextWateringOut? {
        return nextFertilizingData[greenhouseId]
    }
    
    /// Получает события удобрения для теплицы
    func getFertilizingEvents(greenhouseId: String) -> [WaterEventOut] {
        return fertilizingEvents[greenhouseId] ?? []
    }
    
    /// Очищает данные для конкретной теплицы
    func clearData(greenhouseId: String) {
        nextFertilizingData.removeValue(forKey: greenhouseId)
        fertilizingEvents.removeValue(forKey: greenhouseId)
    }
    
    /// Очищает все данные
    func clearAllData() {
        nextFertilizingData.removeAll()
        fertilizingEvents.removeAll()
    }
}

