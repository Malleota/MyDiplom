//
//  AuthManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    
    private let tokenKey = "AccessToken"
    
    private init() {
        // Проверяем сохранённый токен при инициализации
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            accessToken = token
            isAuthenticated = true
        }
    }
    
    func login(token: String) {
        accessToken = token
        isAuthenticated = true
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func logout() {
        accessToken = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}

