//
//  Models.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation

// MARK: - Auth Models

struct LoginRequest: Codable {
    let username: String  // email в формате OAuth2
    let password: String
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
}

struct APIError: Error, Codable {
    let detail: String
}

// MARK: - Register Models

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    let role: String  // "worker" или "admin"
}

struct UserOut: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    let is_active: Bool
    let avatar_id: String?
    let avatar_url: String?  // Полный URL аватара
    let created_at: String
}

// MARK: - Avatar Models

struct AvatarOut: Codable, Identifiable {
    let id: String
    let image_url: String
    let name: String
}

struct AvatarUpdate: Codable {
    let avatar_id: String
}

// MARK: - Greenhouse Models

struct GreenhouseOut: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
    let image_url: String?
    let sensor_id: String?
    let target_temp_min: Double?
    let target_temp_max: Double?
    let target_hum_min: Double?
    let target_hum_max: Double?
    let created_at: String
}

struct GreenhouseCreate: Codable {
    let name: String
    let description: String?
    let image_url: String?
    let plants: [PlantInstanceCreate]?
    let worker_ids: [String]?
    let sensor_ble_identifier: String?
}

struct GreenhouseUpdate: Codable {
    let name: String?
    let description: String?
    let image_url: String?
    let target_temp_min: Double?
    let target_temp_max: Double?
    let target_hum_min: Double?
    let target_hum_max: Double?
}

struct PlantInstanceCreate: Codable {
    let plant_type_id: String
    let quantity: Int
    let note: String?
}

struct GreenhouseImageOut: Codable, Identifiable {
    let id: String
    let image_url: String
    let name: String
}

// MARK: - Sensor Data Models

struct SensorDataOut: Codable {
    let id: String
    let ble_identifier: String?
    let last_temperature: Double?
    let last_humidity: Double?
    let last_update: String?
    let battery_percent: Int?  // Процент батареи, если доступен
}

struct SensorReadingOut: Codable {
    let id: String
    let sensor_id: String
    let greenhouse_id: String
    let temperature: Double
    let humidity: Double
    let created_at: String
}

struct BindSensorIn: Codable {
    let ble_identifier: String
}

struct SensorDataIn: Codable {
    let ble_identifier: String
    let temperature: Double
    let humidity: Double
}

// MARK: - Watering Models

struct WaterEventOut: Codable, Identifiable {
    let id: String
    let greenhouse_id: String
    let user_id: String
    let plant_instance_id: String?
    let type: String  // "watering" или "fertilizing"
    let created_at: String
    let comment: String?
}

struct NextWateringOut: Codable {
    let greenhouse_id: String
    let plant_instance_id: String?
    let plant_name: String?
    let next_watering_date: String?
    let days_until: Int?
    let is_overdue: Bool
}

struct WaterEventCreate: Codable {
    let greenhouse_id: String
    let user_id: String?
    let plant_instance_id: String?
    let type: String  // "watering" или "fertilizing"
    let comment: String?
}

// MARK: - Plant Models

struct PlantTypeCreate: Codable {
    let name: String
    let description: String?
    let image_url: String?
    let temp_min: Double?
    let temp_max: Double?
    let humidity_min: Double?
    let humidity_max: Double?
    let watering_interval_days: Int?
    let fertilizing_interval_days: Int?
}

struct PlantTypeOut: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let image_url: String?
    let temp_min: Double?
    let temp_max: Double?
    let humidity_min: Double?
    let humidity_max: Double?
    let watering_interval_days: Int?
    let fertilizing_interval_days: Int?
}

struct PlantInstanceOut: Codable, Identifiable {
    let id: String
    let greenhouse_id: String
    let plant_type_id: String
    let quantity: Int
    let note: String?
}

struct PlantInstanceUpdate: Codable {
    let plant_type_id: String?
    let quantity: Int?
    let note: String?
    let next_watering_date: String?
    let days_until: Int?
    let next_fertilizing_date: String?
    let fertilizing_days_until: Int?
}

struct BindWorkerIn: Codable {
    let user_id: String
}

// MARK: - Image Upload Models

struct PlantImageUploadResponse: Codable {
    let image_url: String
    let filename: String
}

