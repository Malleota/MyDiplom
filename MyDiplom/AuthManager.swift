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
        
        // Отключаем WebSocket при логауте
        Task { @MainActor in
            WebSocketManager.shared.disconnect()
            SensorDataManager.shared.clearAllSensorData()
        }
    }
    
    @MainActor
    func loadUserData() async {
        do {
            let previousRole = currentUser?.role
            currentUser = try await APIService.shared.getCurrentUser()
            
            // Если роль изменилась, переподключаем WebSocket
            if previousRole != currentUser?.role {
                print("🔄 AuthManager: Роль пользователя изменилась, переподключаем WebSocket")
                // SensorDataManager переподключится автоматически
                SensorDataManager.shared.connectWebSocket()
            }
        } catch let error as APIError {
            // Если пользователь не авторизован, разлогиниваем его
            if error.detail.contains("Не авторизован") || error.detail.contains("не авторизован") {
                print("❌ AuthManager: Пользователь не авторизован, выполняем logout")
                logout()
            } else {
                print("Failed to load user data: \(error.detail)")
            }
        } catch let urlError as URLError {
            // Сетевые ошибки не должны разлогинивать пользователя
            print("⚠️ AuthManager: Сетевая ошибка при загрузке данных пользователя: \(urlError.localizedDescription)")
        } catch {
            print("Failed to load user data: \(error)")
            // Для других ошибок не разлогиниваем, так как это может быть временная проблема
        }
    }
    
    @MainActor
    func updateUser(_ user: UserOut) {
        currentUser = user
    }
}

