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
    @Published var currentUser: UserOut?
    
    private let tokenKey = "AccessToken"
    
    private init() {
        // Проверяем сохранённый токен при инициализации
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            accessToken = token
            isAuthenticated = true
            // Загружаем данные пользователя
            Task {
                await loadUserData()
            }
        }
    }
    
    func login(token: String) {
        accessToken = token
        isAuthenticated = true
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task {
            await loadUserData()
        }
    }
    
    func logout() {
        accessToken = nil
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    @MainActor
    func loadUserData() async {
        do {
            currentUser = try await APIService.shared.getCurrentUser()
        } catch {
            print("Failed to load user data: \(error)")
        }
    }
    
    @MainActor
    func updateUser(_ user: UserOut) {
        currentUser = user
    }
}

