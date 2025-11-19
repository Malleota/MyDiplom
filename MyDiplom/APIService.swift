//
//  APIService.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    // TODO: Замените на реальный URL вашего API
    private let baseURL = "http://95.140.158.180:8000"
    
    private init() {}
    
    // MARK: - Auth
    
    /// Авторизация пользователя
    func login(email: String, password: String) async throws -> TokenResponse {
        let url = URL(string: "\(baseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // OAuth2PasswordRequestForm использует form-data формат
        let bodyString = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(TokenResponse.self, from: data)
        } else if httpResponse.statusCode == 401 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Неверный email или пароль")
        } else if httpResponse.statusCode == 403 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Пользователь неактивен")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Регистрация нового пользователя
    func register(name: String, email: String, password: String) async throws -> UserOut {
        let url = URL(string: "\(baseURL)/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let registerRequest = RegisterRequest(
            email: email,
            password: password,
            name: name,
            role: "worker"  // По умолчанию регистрируем как worker
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(registerRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(UserOut.self, from: data)
        } else if httpResponse.statusCode == 400 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка регистрации")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
}

