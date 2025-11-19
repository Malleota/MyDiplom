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
    let created_at: String
}

