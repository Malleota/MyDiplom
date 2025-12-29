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
    
    @Published var nextWateringData: [String: NextWateringOut] = [:] // greenhouseId -> NextWateringOut (ближайший полив среди всех растений)
    @Published var wateringEvents: [String: [WaterEventOut]] = [:] // greenhouseId -> [WaterEventOut]
    
    private init() {}
    
    /// Загружает данные о следующем поливе для теплицы
    /// Находит растение, которое потребует полива раньше всех
    func loadNextWateringForGreenhouse(_ greenhouse: GreenhouseOut) async {
        do {
            // Загружаем данные о поливе для всех растений в теплице
            let plantWaterings = try await APIService.shared.getNextWateringForPlants(greenhouseId: greenhouse.id)
            
            if plantWaterings.isEmpty {
                // Если нет растений, используем общий эндпоинт для теплицы
                if let nextWatering = try await APIService.shared.getNextWatering(greenhouseId: greenhouse.id) {
                    nextWateringData[greenhouse.id] = nextWatering
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NextWateringUpdated"),
                        object: nil,
                        userInfo: ["greenhouse_id": greenhouse.id, "next_watering": nextWatering]
                    )
                } else {
                    nextWateringData.removeValue(forKey: greenhouse.id)
                }
                return
            }
            
            // Находим растение с минимальным days_until
            // Приоритет: просроченные поливы (самый просроченный) > непросроченные (ближайший)
            var closestWatering: NextWateringOut?
            var minDaysUntil: Int? = nil
            var hasOverdue = false
            
            for watering in plantWaterings {
                if let daysUntil = watering.days_until {
                    // Если это просроченный полив
                    if watering.is_overdue {
                        // Просроченные имеют приоритет
                        if !hasOverdue {
                            // Первый просроченный - берем его
                            hasOverdue = true
                            minDaysUntil = daysUntil
                            closestWatering = watering
                        } else {
                            // Среди просроченных берем самый просроченный (минимальный days_until, т.к. он отрицательный)
                            if daysUntil < minDaysUntil! {
                                minDaysUntil = daysUntil
                                closestWatering = watering
                            }
                        }
                    } else {
                        // Непросроченный полив
                        if !hasOverdue {
                            // Если еще не нашли просроченных, ищем ближайший непросроченный
                            if minDaysUntil == nil || daysUntil < minDaysUntil! {
                                minDaysUntil = daysUntil
                                closestWatering = watering
                            }
                        }
                        // Если уже есть просроченные, игнорируем непросроченные
                    }
                } else {
                    // Если нет days_until, но есть дата полива, это менее приоритетно
                    // Используем только если нет других вариантов
                    if closestWatering == nil {
                        closestWatering = watering
                    }
                }
            }
            
            // Если нашли ближайший полив, сохраняем его
            if let closest = closestWatering {
                nextWateringData[greenhouse.id] = closest
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("NextWateringUpdated"),
                    object: nil,
                    userInfo: ["greenhouse_id": greenhouse.id, "next_watering": closest]
                )
            } else {
                // Если не нашли, удаляем из кэша
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

