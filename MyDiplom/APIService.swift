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
        request.timeoutInterval = 30.0 // Таймаут 30 секунд
        
        // OAuth2PasswordRequestForm использует form-data формат
        let bodyString = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("🔐 Login: Отправка запроса на \(url.absoluteString)")
        print("🔐 Login: Body = username=\(email)&password=***")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("🔐 Login: Получен ответ от сервера")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Login: Неверный ответ сервера (не HTTPURLResponse)")
                throw APIError(detail: "Неверный ответ сервера")
            }
            
            print("🔐 Login: Статус ответа = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                print("✅ Login: Авторизация успешна")
                return tokenResponse
            } else if httpResponse.statusCode == 401 {
                let decoder = JSONDecoder()
                if let error = try? decoder.decode(APIError.self, from: data) {
                    print("❌ Login: Ошибка 401 - \(error.detail)")
                    throw APIError(detail: error.detail)
                }
                print("❌ Login: Ошибка 401 - Неверный email или пароль")
                throw APIError(detail: "Неверный email или пароль")
            } else if httpResponse.statusCode == 403 {
                let decoder = JSONDecoder()
                if let error = try? decoder.decode(APIError.self, from: data) {
                    print("❌ Login: Ошибка 403 - \(error.detail)")
                    throw APIError(detail: error.detail)
                }
                print("❌ Login: Ошибка 403 - Пользователь неактивен")
                throw APIError(detail: "Пользователь неактивен")
            } else {
                let decoder = JSONDecoder()
                if let error = try? decoder.decode(APIError.self, from: data) {
                    print("❌ Login: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                    throw APIError(detail: error.detail)
                }
                print("❌ Login: Ошибка сервера (код \(httpResponse.statusCode))")
                throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
            }
        } catch let urlError as URLError {
            print("❌ Login: URLError - \(urlError.localizedDescription)")
            print("❌ Login: URLError code - \(urlError.code.rawValue)")
            if urlError.code == .timedOut {
                print("❌ Login: Превышено время ожидания")
                throw APIError(detail: "Превышено время ожидания. Проверьте подключение к интернету.")
            } else if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                print("❌ Login: Нет подключения к интернету")
                throw APIError(detail: "Нет подключения к интернету")
            } else {
                print("❌ Login: Ошибка сети - \(urlError.localizedDescription)")
                throw APIError(detail: "Ошибка подключения: \(urlError.localizedDescription)")
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            print("❌ Login: Неизвестная ошибка - \(error.localizedDescription)")
            throw APIError(detail: "Ошибка подключения: \(error.localizedDescription)")
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
    
    // MARK: - User
    
    /// Получить информацию о текущем пользователе
    func getCurrentUser() async throws -> UserOut {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(UserOut.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    // MARK: - Avatars
    
    /// Получить список доступных аватаров
    func getAvatars() async throws -> [AvatarOut] {
        let url = URL(string: "\(baseURL)/avatars")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([AvatarOut].self, from: data)
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Обновить аватар текущего пользователя
    func updateAvatar(avatarId: String) async throws -> UserOut {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/me/avatar")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let avatarUpdate = AvatarUpdate(avatar_id: avatarId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(avatarUpdate)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(UserOut.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 404 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Аватарка не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    // MARK: - Greenhouses
    
    /// Получить список всех теплиц
    func getGreenhouses() async throws -> [GreenhouseOut] {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode([GreenhouseOut].self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Получить информацию о конкретной теплице
    func getGreenhouse(id: String) async throws -> GreenhouseOut {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(GreenhouseOut.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            throw APIError(detail: "Нет доступа к этой теплице")
        } else if httpResponse.statusCode == 404 {
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Создать новую теплицу
    func createGreenhouse(_ greenhouse: GreenhouseCreate) async throws -> GreenhouseOut {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(greenhouse)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            return try decoder.decode(GreenhouseOut.self, from: data)
        } else if httpResponse.statusCode == 400 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка валидации")
        } else if httpResponse.statusCode == 401 {
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            throw APIError(detail: "Доступ запрещен. Только администратор может создавать теплицы")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Получить текущие данные датчика для теплицы
    func getCurrentSensorData(greenhouseId: String) async throws -> SensorReadingOut? {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getCurrentSensorData: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/sensor-data/current")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📡 getCurrentSensorData: Запрос данных датчика для теплицы greenhouseId=\(greenhouseId), URL=\(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ getCurrentSensorData: Неверный ответ сервера")
                return nil
            }
            
            print("📡 getCurrentSensorData: Статус ответа = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let sensorData = try decoder.decode(SensorReadingOut.self, from: data)
                print("✅ getCurrentSensorData: Данные датчика получены: temp=\(sensorData.temperature), hum=\(sensorData.humidity)")
                return sensorData
            } else if httpResponse.statusCode == 404 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getCurrentSensorData: Данные не найдены (404), ответ: \(responseString)")
                }
                return nil
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getCurrentSensorData: Ошибка \(httpResponse.statusCode), ответ: \(responseString)")
                } else {
                    print("⚠️ getCurrentSensorData: Ошибка \(httpResponse.statusCode), не удалось декодировать ответ")
                }
                return nil
            }
        } catch {
            print("❌ getCurrentSensorData: Исключение при запросе: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("❌ getCurrentSensorData: Ошибка декодирования: \(decodingError)")
            }
            return nil
        }
    }
    
    /// Получить данные датчика по ID (устаревший метод, оставлен для совместимости)
    @available(*, deprecated, message: "Используйте getCurrentSensorData(greenhouseId:) вместо этого")
    func getSensorData(sensorId: String) async throws -> SensorDataOut? {
        // Этот метод больше не используется, но оставлен для совместимости
        return nil
    }
    
    /// Отвязать датчик от теплицы
    func unbindSensorFromGreenhouse(greenhouseId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ unbindSensorFromGreenhouse: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/sensor")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📡 unbindSensorFromGreenhouse: Отправка запроса на \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ unbindSensorFromGreenhouse: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📡 unbindSensorFromGreenhouse: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ unbindSensorFromGreenhouse: Датчик успешно отвязан")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ unbindSensorFromGreenhouse: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ unbindSensorFromGreenhouse: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может отвязывать датчики")
        } else if httpResponse.statusCode == 404 {
            print("❌ unbindSensorFromGreenhouse: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ unbindSensorFromGreenhouse: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ unbindSensorFromGreenhouse: Ошибка \(httpResponse.statusCode) - ответ: \(responseString)")
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Привязать датчик к теплице
    func bindSensorToGreenhouse(greenhouseId: String, bleIdentifier: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ bindSensorToGreenhouse: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/sensor")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let bindRequest = BindSensorIn(ble_identifier: bleIdentifier)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(bindRequest)
        
        print("📡 bindSensorToGreenhouse: Отправка запроса на \(url.absoluteString)")
        print("📡 bindSensorToGreenhouse: ble_identifier=\(bleIdentifier)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ bindSensorToGreenhouse: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📡 bindSensorToGreenhouse: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            // Успешно привязано
            print("✅ bindSensorToGreenhouse: Датчик успешно привязан")
            return
        } else if httpResponse.statusCode == 400 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ bindSensorToGreenhouse: Ошибка 400 - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ bindSensorToGreenhouse: Ошибка 400 - ответ: \(responseString)")
            }
            throw APIError(detail: "Ошибка привязки датчика")
        } else if httpResponse.statusCode == 401 {
            print("❌ bindSensorToGreenhouse: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ bindSensorToGreenhouse: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может привязывать датчики")
        } else if httpResponse.statusCode == 404 {
            print("❌ bindSensorToGreenhouse: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ bindSensorToGreenhouse: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ bindSensorToGreenhouse: Ошибка \(httpResponse.statusCode) - ответ: \(responseString)")
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
}

