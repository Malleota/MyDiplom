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

struct UserOut: Codable {
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

struct GreenhouseOut: Codable, Identifiable {
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

