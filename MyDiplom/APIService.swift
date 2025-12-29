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
    
    /// Преобразовать относительный URL изображения в полный URL
    func getFullImageURL(_ imageUrl: String) -> URL? {
        // Если URL уже полный (начинается с http:// или https://)
        if imageUrl.hasPrefix("http://") || imageUrl.hasPrefix("https://") {
            return URL(string: imageUrl)
        }
        
        // Если URL относительный, добавляем базовый URL
        let fullURL: String
        if imageUrl.hasPrefix("/") {
            fullURL = "\(baseURL)\(imageUrl)"
        } else {
            fullURL = "\(baseURL)/\(imageUrl)"
        }
        
        return URL(string: fullURL)
    }
    
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
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Login: Неверный ответ сервера (не HTTPURLResponse)")
                throw APIError(detail: "Неверный ответ сервера")
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
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
    /// Для админа возвращаются все теплицы, для рабочего - только привязанные
    func getGreenhouses() async throws -> [GreenhouseOut] {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let userRole = AuthManager.shared.currentUser?.role ?? "unknown"
        let url = URL(string: "\(baseURL)/greenhouses")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let greenhouses = try decoder.decode([GreenhouseOut].self, from: data)
            return greenhouses
        } else if httpResponse.statusCode == 401 {
            print("❌ getGreenhouses: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getGreenhouses: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            print("❌ getGreenhouses: Ошибка сервера (код \(httpResponse.statusCode))")
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
    
    /// Обновить теплицу
    func updateGreenhouse(id: String, _ update: GreenhouseUpdate) async throws -> GreenhouseOut {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(update)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
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
            throw APIError(detail: "Доступ запрещен. Только администратор может редактировать теплицы")
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
    
    /// Удалить теплицу
    func deleteGreenhouse(id: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 204 {
            return
        } else if httpResponse.statusCode == 401 {
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            throw APIError(detail: "Доступ запрещен. Только администратор может удалять теплицы")
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
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ getCurrentSensorData: Неверный ответ сервера")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let sensorData = try decoder.decode(SensorReadingOut.self, from: data)
                return sensorData
            } else if httpResponse.statusCode == 404 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getCurrentSensorData: Данные не найдены (404), ответ: \(responseString)")
                }
                return nil
            } else if httpResponse.statusCode == 500 {
                // Ошибка 500 - проблема на сервере, но не критично для клиента
                // Возможные причины: проблема с БД, обработкой даты, или временная недоступность данных
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getCurrentSensorData: Ошибка 500 (Internal Server Error), ответ: \(responseString)")
                    print("💡 Это может означать, что на сервере нет актуальных данных датчика или произошла временная ошибка")
                } else {
                    print("⚠️ getCurrentSensorData: Ошибка 500 (Internal Server Error), не удалось декодировать ответ")
                }
                // Возвращаем nil вместо выброса ошибки, чтобы приложение продолжало работать
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ unbindSensorFromGreenhouse: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 204 {
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ bindSensorToGreenhouse: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 204 {
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
    
    /// Отправить данные с датчика на сервер
    func sendSensorData(bleIdentifier: String, temperature: Double, humidity: Double) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ sendSensorData: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        print("📤 APIService: Отправка данных датчика на сервер - BLE: \(bleIdentifier), temp: \(temperature)°C, hum: \(humidity)%")
        
        let url = URL(string: "\(baseURL)/sensors/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let sensorData = SensorDataIn(
            ble_identifier: bleIdentifier,
            temperature: temperature,
            humidity: humidity
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(sensorData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ sendSensorData: Неверный ответ сервера")
                throw APIError(detail: "Неверный ответ сервера")
            }
            
            if httpResponse.statusCode == 204 {
                print("✅ APIService: Данные датчика успешно отправлены на сервер (204)")
                return
            } else if httpResponse.statusCode == 401 {
                print("❌ sendSensorData: Ошибка 401 - Не авторизован")
                throw APIError(detail: "Не авторизован")
            } else if httpResponse.statusCode == 404 {
                print("⚠️ sendSensorData: Ошибка 404 - Датчик не найден (возможно, еще не привязан)")
                // Не бросаем ошибку, так как датчик может быть еще не привязан
                return
            } else {
                let decoder = JSONDecoder()
                if let error = try? decoder.decode(APIError.self, from: data) {
                    print("❌ sendSensorData: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                    throw APIError(detail: error.detail)
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ sendSensorData: Ошибка \(httpResponse.statusCode) - ответ: \(responseString)")
                }
                throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
            }
        } catch let urlError as URLError {
            print("❌ sendSensorData: URLError - \(urlError.localizedDescription)")
            // Не бросаем ошибку при сетевых проблемах, чтобы не прерывать работу BLE
            return
        } catch {
            print("❌ sendSensorData: Ошибка отправки данных - \(error.localizedDescription)")
            // Не бросаем ошибку, чтобы не прерывать работу BLE
            return
        }
    }
    
    // MARK: - Watering Events
    
    /// Получить информацию о следующем поливе для теплицы
    func getNextWatering(greenhouseId: String) async throws -> NextWateringOut? {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getNextWatering: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/next-watering")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ getNextWatering: Неверный ответ сервера")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let nextWatering = try decoder.decode(NextWateringOut.self, from: data)
                return nextWatering
            } else if httpResponse.statusCode == 404 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getNextWatering: Данные не найдены (404), ответ: \(responseString)")
                }
                return nil
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getNextWatering: Ошибка \(httpResponse.statusCode), ответ: \(responseString)")
                }
                return nil
            }
        } catch {
            print("❌ getNextWatering: Исключение при запросе: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Получить список событий полива
    func getWateringEvents(greenhouseId: String? = nil, userId: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async throws -> [WaterEventOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getWateringEvents: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/watering-events")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
        }
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }
        if let dateFrom = dateFrom {
            queryItems.append(URLQueryItem(name: "date_from", value: dateFrom))
        }
        if let dateTo = dateTo {
            queryItems.append(URLQueryItem(name: "date_to", value: dateTo))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError(detail: "Неверный URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getWateringEvents: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let allEvents = try decoder.decode([WaterEventOut].self, from: data)
            // Фильтруем только события полива (сервер возвращает все события)
            let wateringEvents = allEvents.filter { $0.type == "watering" }
            return wateringEvents
        } else if httpResponse.statusCode == 401 {
            print("❌ getWateringEvents: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getWateringEvents: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Создать событие полива/удобрения
    func createWateringEvent(greenhouseId: String, plantInstanceId: String?, type: String = "watering", comment: String? = nil) async throws -> WaterEventOut {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ createWateringEvent: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/watering-events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let wateringEvent = WaterEventCreate(
            greenhouse_id: greenhouseId,
            user_id: nil, // Используется текущий пользователь
            plant_instance_id: plantInstanceId,
            type: type,
            comment: comment
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(wateringEvent)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ createWateringEvent: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            let event = try decoder.decode(WaterEventOut.self, from: data)
            return event
        } else if httpResponse.statusCode == 401 {
            print("❌ createWateringEvent: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ createWateringEvent: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этой теплице")
        } else if httpResponse.statusCode == 404 {
            print("❌ createWateringEvent: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ createWateringEvent: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Plant Instances
    
    /// Получить список растений в теплице
    func getPlantInstances(greenhouseId: String) async throws -> [PlantInstanceOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getPlantInstances: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/plants")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌱 getPlantInstances: Запрос списка растений для теплицы \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getPlantInstances: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌱 getPlantInstances: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let plants = try decoder.decode([PlantInstanceOut].self, from: data)
            print("✅ getPlantInstances: Получено \(plants.count) растений")
            return plants
        } else if httpResponse.statusCode == 401 {
            print("❌ getPlantInstances: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ getPlantInstances: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этой теплице")
        } else if httpResponse.statusCode == 404 {
            print("❌ getPlantInstances: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getPlantInstances: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Получить данные о следующем поливе для каждого растения в теплице
    func getNextWateringForPlants(greenhouseId: String) async throws -> [NextWateringOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getNextWateringForPlants: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/plants/next-watering")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("💧 getNextWateringForPlants: Запрос данных о поливе для растений в теплице \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getNextWateringForPlants: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("💧 getNextWateringForPlants: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let nextWaterings = try decoder.decode([NextWateringOut].self, from: data)
            print("✅ getNextWateringForPlants: Получено \(nextWaterings.count) записей о поливе")
            return nextWaterings
        } else if httpResponse.statusCode == 401 {
            print("❌ getNextWateringForPlants: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 404 {
            print("⚠️ getNextWateringForPlants: Данные не найдены (404)")
            return []
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getNextWateringForPlants: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Получить список доступных изображений для теплиц
    func getGreenhouseImages() async throws -> [GreenhouseImageOut] {
        // Этот endpoint не требует авторизации согласно API
        let url = URL(string: "\(baseURL)/greenhouse-images")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Опционально добавляем токен, если он есть
        if let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("📸 getGreenhouseImages: Запрос изображений с URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getGreenhouseImages: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📸 getGreenhouseImages: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let images = try decoder.decode([GreenhouseImageOut].self, from: data)
            print("✅ getGreenhouseImages: Загружено \(images.count) изображений")
            for image in images {
                print("  - \(image.name): \(image.image_url)")
            }
            return images
        } else if httpResponse.statusCode == 401 {
            print("❌ getGreenhouseImages: Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getGreenhouseImages: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ getGreenhouseImages: Ошибка сервера, ответ: \(responseString)")
            }
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Получить список всех пользователей (доступно только для админа)
    func getAllUsers() async throws -> [UserOut] {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        // Проверяем, является ли пользователь админом
        guard let currentUser = AuthManager.shared.currentUser, currentUser.role == "admin" else {
            print("⚠️ getAllUsers: Доступ запрещен - требуется роль admin")
            throw APIError(detail: "Доступ запрещен. Требуется роль администратора")
        }
        
        let url = URL(string: "\(baseURL)/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("👥 getAllUsers: Запрос списка всех пользователей с URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("👥 getAllUsers: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let users = try decoder.decode([UserOut].self, from: data)
            print("✅ getAllUsers: Загружено \(users.count) пользователей")
            return users
        } else if httpResponse.statusCode == 401 {
            print("❌ getAllUsers: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ getAllUsers: Ошибка 403 - Доступ запрещен (требуется роль admin)")
            throw APIError(detail: "Доступ запрещен. Требуется роль администратора")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getAllUsers: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            print("❌ getAllUsers: Ошибка сервера (код \(httpResponse.statusCode))")
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Обновить роль пользователя (доступно только для админа)
    func updateUserRole(userId: String, role: String) async throws -> UserOut {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        // Проверяем, является ли пользователь админом
        guard let currentUser = AuthManager.shared.currentUser, currentUser.role == "admin" else {
            print("⚠️ updateUserRole: Доступ запрещен - требуется роль admin")
            throw APIError(detail: "Доступ запрещен. Требуется роль администратора")
        }
        
        let url = URL(string: "\(baseURL)/users/\(userId)/role")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = UserRoleUpdate(role: role)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)
        
        print("👥 updateUserRole: Обновление роли пользователя \(userId) на \(role)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("👥 updateUserRole: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let updatedUser = try decoder.decode(UserOut.self, from: data)
            print("✅ updateUserRole: Роль пользователя успешно обновлена")
            return updatedUser
        } else if httpResponse.statusCode == 401 {
            print("❌ updateUserRole: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ updateUserRole: Ошибка 403 - Доступ запрещен (требуется роль admin)")
            throw APIError(detail: "Доступ запрещен. Требуется роль администратора")
        } else if httpResponse.statusCode == 404 {
            print("❌ updateUserRole: Ошибка 404 - Пользователь не найден")
            throw APIError(detail: "Пользователь не найден")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ updateUserRole: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            print("❌ updateUserRole: Ошибка сервера (код \(httpResponse.statusCode))")
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Получить список всех рабочих (пользователей с ролью worker)
    /// Доступен для admin и worker
    func getWorkers() async throws -> [UserOut] {
        guard let token = AuthManager.shared.accessToken else {
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/workers")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("👷 getWorkers: Запрос списка рабочих с URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("👷 getWorkers: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let workers = try decoder.decode([UserOut].self, from: data)
            print("✅ getWorkers: Загружено \(workers.count) рабочих")
            return workers
        } else if httpResponse.statusCode == 401 {
            print("❌ getWorkers: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getWorkers: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            print("❌ getWorkers: Ошибка сервера (код \(httpResponse.statusCode))")
            throw APIError(detail: "Ошибка сервера")
        }
    }
    
    /// Получить список всех типов растений
    func getPlantTypes() async throws -> [PlantTypeOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getPlantTypes: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/plant-types")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌿 getPlantTypes: Запрос списка типов растений")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getPlantTypes: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌿 getPlantTypes: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let plantTypes = try decoder.decode([PlantTypeOut].self, from: data)
            print("✅ getPlantTypes: Получено \(plantTypes.count) типов растений")
            return plantTypes
        } else if httpResponse.statusCode == 401 {
            print("❌ getPlantTypes: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getPlantTypes: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Создать новый тип растения в справочнике
    func createPlantType(_ plant: PlantTypeCreate) async throws -> PlantTypeOut {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ createPlantType: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/plant-types")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(plant)
        
        print("🌿 createPlantType: Создание нового типа растения")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ createPlantType: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌿 createPlantType: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let plantType = try decoder.decode(PlantTypeOut.self, from: data)
            print("✅ createPlantType: Тип растения успешно создан")
            return plantType
        } else if httpResponse.statusCode == 401 {
            print("❌ createPlantType: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ createPlantType: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Требуются права администратора")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ createPlantType: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Обновить тип растения в справочнике
    func updatePlantType(plantTypeId: String, update: PlantTypeUpdate) async throws -> PlantTypeOut {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ updatePlantType: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/plant-types/\(plantTypeId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(update)
        
        print("🌿 updatePlantType: Обновление типа растения \(plantTypeId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ updatePlantType: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌿 updatePlantType: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let plantType = try decoder.decode(PlantTypeOut.self, from: data)
            print("✅ updatePlantType: Тип растения успешно обновлен")
            return plantType
        } else if httpResponse.statusCode == 401 {
            print("❌ updatePlantType: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ updatePlantType: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Требуются права администратора")
        } else if httpResponse.statusCode == 404 {
            print("❌ updatePlantType: Ошибка 404 - Тип растения не найден")
            throw APIError(detail: "Тип растения не найден")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ updatePlantType: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Удалить тип растения из справочника
    func deletePlantType(plantTypeId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ deletePlantType: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/plant-types/\(plantTypeId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌿 deletePlantType: Удаление типа растения \(plantTypeId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ deletePlantType: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌿 deletePlantType: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ deletePlantType: Тип растения успешно удален")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ deletePlantType: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ deletePlantType: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Требуются права администратора")
        } else if httpResponse.statusCode == 404 {
            print("❌ deletePlantType: Ошибка 404 - Тип растения не найден")
            throw APIError(detail: "Тип растения не найден")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ deletePlantType: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Загрузить изображение для растения
    func uploadPlantImage(imageData: Data, filename: String) async throws -> PlantImageUploadResponse {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ uploadPlantImage: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/plant-types/upload-image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Определяем MIME-тип на основе расширения файла
        let contentType: String
        let fileExtension = (filename as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "jpg", "jpeg":
            contentType = "image/jpeg"
        case "png":
            contentType = "image/png"
        case "webp":
            contentType = "image/webp"
        default:
            contentType = "image/jpeg"
        }
        
        // Создаем multipart/form-data запрос
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Добавляем файл
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 uploadPlantImage: Загрузка изображения \(filename), размер: \(imageData.count) байт, тип: \(contentType)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ uploadPlantImage: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📤 uploadPlantImage: Статус ответа = \(httpResponse.statusCode)")
        
        // Логируем ответ для отладки
        if let responseString = String(data: data, encoding: .utf8) {
            print("📤 uploadPlantImage: Ответ сервера: \(responseString.prefix(500))")
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                // Не используем convertFromSnakeCase, так как модель уже использует snake_case
                let uploadResponse = try decoder.decode(PlantImageUploadResponse.self, from: data)
                print("✅ uploadPlantImage: Изображение успешно загружено: \(uploadResponse.image_url)")
                return uploadResponse
            } catch {
                print("❌ uploadPlantImage: Ошибка декодирования ответа: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ uploadPlantImage: Полный ответ: \(responseString)")
                }
                throw APIError(detail: "Не удалось обработать ответ сервера: \(error.localizedDescription)")
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ uploadPlantImage: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ uploadPlantImage: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Требуются права администратора")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ uploadPlantImage: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ uploadPlantImage: Ошибка сервера, ответ: \(responseString)")
                throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode)): \(responseString)")
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Добавить растение в теплицу
    func addPlantInstance(greenhouseId: String, plant: PlantInstanceCreate) async throws -> PlantInstanceOut {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ addPlantInstance: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/plants")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(plant)
        
        print("🌱 addPlantInstance: Добавление растения в теплицу \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ addPlantInstance: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌱 addPlantInstance: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            let plantInstance = try decoder.decode(PlantInstanceOut.self, from: data)
            print("✅ addPlantInstance: Растение успешно добавлено")
            return plantInstance
        } else if httpResponse.statusCode == 401 {
            print("❌ addPlantInstance: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ addPlantInstance: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может добавлять растения")
        } else if httpResponse.statusCode == 404 {
            print("❌ addPlantInstance: Ошибка 404 - Теплица или тип растения не найдены")
            throw APIError(detail: "Теплица или тип растения не найдены")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ addPlantInstance: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Удалить растение из теплицы
    func deletePlantInstance(greenhouseId: String, plantInstanceId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ deletePlantInstance: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/plants/\(plantInstanceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌱 deletePlantInstance: Удаление растения \(plantInstanceId) из теплицы \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ deletePlantInstance: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌱 deletePlantInstance: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ deletePlantInstance: Растение успешно удалено")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ deletePlantInstance: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ deletePlantInstance: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может удалять растения")
        } else if httpResponse.statusCode == 404 {
            print("❌ deletePlantInstance: Ошибка 404 - Растение не найдено")
            throw APIError(detail: "Растение не найдено")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ deletePlantInstance: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Обновить растение в теплице
    func updatePlantInstance(greenhouseId: String, plantInstanceId: String, update: PlantInstanceUpdate) async throws -> PlantInstanceOut {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ updatePlantInstance: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/plants/\(plantInstanceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(update)
        
        print("🌱 updatePlantInstance: Обновление растения \(plantInstanceId) в теплице \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ updatePlantInstance: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌱 updatePlantInstance: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let updatedPlant = try decoder.decode(PlantInstanceOut.self, from: data)
            print("✅ updatePlantInstance: Растение успешно обновлено")
            return updatedPlant
        } else if httpResponse.statusCode == 401 {
            print("❌ updatePlantInstance: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ updatePlantInstance: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может редактировать растения")
        } else if httpResponse.statusCode == 404 {
            print("❌ updatePlantInstance: Ошибка 404 - Растение не найдено")
            throw APIError(detail: "Растение не найдено")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ updatePlantInstance: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Fertilizing Events
    
    /// Получить информацию о следующем удобрении для теплицы
    func getNextFertilizing(greenhouseId: String) async throws -> NextWateringOut? {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getNextFertilizing: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/next-fertilizing")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌿 getNextFertilizing: Запрос данных о следующем удобрении для теплицы \(greenhouseId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ getNextFertilizing: Неверный ответ сервера")
                return nil
            }
            
            print("🌿 getNextFertilizing: Статус ответа = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let nextFertilizing = try decoder.decode(NextWateringOut.self, from: data)
                print("✅ getNextFertilizing: Данные о следующем удобрении получены: days_until=\(nextFertilizing.days_until ?? -1)")
                return nextFertilizing
            } else if httpResponse.statusCode == 404 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getNextFertilizing: Данные не найдены (404), ответ: \(responseString)")
                }
                return nil
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ getNextFertilizing: Ошибка \(httpResponse.statusCode), ответ: \(responseString)")
                }
                return nil
            }
        } catch {
            print("❌ getNextFertilizing: Исключение при запросе: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Получить список событий удобрения
    func getFertilizingEvents(greenhouseId: String? = nil, userId: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async throws -> [WaterEventOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getFertilizingEvents: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/watering-events")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
        }
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }
        if let dateFrom = dateFrom {
            queryItems.append(URLQueryItem(name: "date_from", value: dateFrom))
        }
        if let dateTo = dateTo {
            queryItems.append(URLQueryItem(name: "date_to", value: dateTo))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError(detail: "Неверный URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌿 getFertilizingEvents: Запрос событий удобрения")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getFertilizingEvents: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌿 getFertilizingEvents: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let allEvents = try decoder.decode([WaterEventOut].self, from: data)
            // Фильтруем только события удобрения
            let fertilizingEvents = allEvents.filter { $0.type == "fertilizing" }
            print("✅ getFertilizingEvents: Получено \(fertilizingEvents.count) событий удобрения")
            return fertilizingEvents
        } else if httpResponse.statusCode == 401 {
            print("❌ getFertilizingEvents: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getFertilizingEvents: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Получить список теплиц, к которым привязан работник
    func getWorkerGreenhouses(workerId: String) async throws -> [GreenhouseOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getWorkerGreenhouses: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        // Проверяем, является ли пользователь админом
        guard let currentUser = AuthManager.shared.currentUser, currentUser.role == "admin" else {
            print("⚠️ getWorkerGreenhouses: Доступ запрещен - требуется роль admin")
            throw APIError(detail: "Доступ запрещен. Требуется роль администратора")
        }
        
        // Получаем все теплицы
        let allGreenhouses = try await getGreenhouses()
        
        // Для каждой теплицы проверяем, привязан ли к ней работник
        var workerGreenhouses: [GreenhouseOut] = []
        
        for greenhouse in allGreenhouses {
            do {
                let workers = try await getGreenhouseWorkers(greenhouseId: greenhouse.id)
                if workers.contains(where: { $0.id == workerId }) {
                    workerGreenhouses.append(greenhouse)
                }
            } catch {
                // Если не удалось получить работников для теплицы, пропускаем её
                print("⚠️ getWorkerGreenhouses: Не удалось получить работников для теплицы \(greenhouse.id): \(error)")
            }
        }
        
        print("✅ getWorkerGreenhouses: Найдено \(workerGreenhouses.count) теплиц для работника \(workerId)")
        return workerGreenhouses
    }
    
    /// Получить список отчетов о просрочках
    func getOverdueReports(greenhouseId: String? = nil, reportType: String? = nil, resolved: Bool? = nil) async throws -> [OverdueReportOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getOverdueReports: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/overdue-reports")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
        }
        if let reportType = reportType {
            queryItems.append(URLQueryItem(name: "report_type", value: reportType))
        }
        if let resolved = resolved {
            queryItems.append(URLQueryItem(name: "resolved", value: resolved ? "true" : "false"))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        let url = urlComponents.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getOverdueReports: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            // OverdueReportOut использует snake_case поля, поэтому keyDecodingStrategy не нужен
            do {
                let reports = try decoder.decode([OverdueReportOut].self, from: data)
                return reports
            } catch {
                print("❌ getOverdueReports: Ошибка декодирования: \(error)")
                throw APIError(detail: "Ошибка декодирования данных: \(error.localizedDescription)")
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ getOverdueReports: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getOverdueReports: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Получить отчеты о просрочках для конкретной теплицы
    func getGreenhouseOverdueReports(greenhouseId: String, reportType: String? = nil, resolved: Bool? = nil) async throws -> [OverdueReportOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getGreenhouseOverdueReports: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/greenhouses/\(greenhouseId)/overdue-reports")!
        var queryItems: [URLQueryItem] = []
        
        if let reportType = reportType {
            queryItems.append(URLQueryItem(name: "report_type", value: reportType))
        }
        if let resolved = resolved {
            queryItems.append(URLQueryItem(name: "resolved", value: resolved ? "true" : "false"))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        let url = urlComponents.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        print("📡 getGreenhouseOverdueReports: Запрос отчетов о просрочках для теплицы \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getGreenhouseOverdueReports: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📡 getGreenhouseOverdueReports: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            // OverdueReportOut использует snake_case поля, поэтому keyDecodingStrategy не нужен
            do {
                let reports = try decoder.decode([OverdueReportOut].self, from: data)
                print("✅ getGreenhouseOverdueReports: Получено \(reports.count) отчетов о просрочках")
                return reports
            } catch {
                print("❌ getGreenhouseOverdueReports: Ошибка декодирования: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ getGreenhouseOverdueReports: Ответ сервера: \(responseString.prefix(500))")
                }
                throw APIError(detail: "Ошибка декодирования данных: \(error.localizedDescription)")
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ getGreenhouseOverdueReports: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 404 {
            print("❌ getGreenhouseOverdueReports: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getGreenhouseOverdueReports: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Получить список работников, привязанных к теплице
    func getGreenhouseWorkers(greenhouseId: String) async throws -> [UserOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getGreenhouseWorkers: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/workers")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("👷 getGreenhouseWorkers: Запрос списка работников для теплицы \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getGreenhouseWorkers: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("👷 getGreenhouseWorkers: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let workers = try decoder.decode([UserOut].self, from: data)
            print("✅ getGreenhouseWorkers: Получено \(workers.count) работников")
            return workers
        } else if httpResponse.statusCode == 401 {
            print("❌ getGreenhouseWorkers: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ getGreenhouseWorkers: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может просматривать работников")
        } else if httpResponse.statusCode == 404 {
            print("❌ getGreenhouseWorkers: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getGreenhouseWorkers: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Привязать работника к теплице
    func bindWorkerToGreenhouse(greenhouseId: String, userId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ bindWorkerToGreenhouse: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/workers")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let bindRequest = BindWorkerIn(user_id: userId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(bindRequest)
        
        print("👷 bindWorkerToGreenhouse: Привязка работника \(userId) к теплице \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ bindWorkerToGreenhouse: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("👷 bindWorkerToGreenhouse: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ bindWorkerToGreenhouse: Работник успешно привязан")
            return
        } else if httpResponse.statusCode == 400 {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ bindWorkerToGreenhouse: Ошибка 400 - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка привязки работника")
        } else if httpResponse.statusCode == 401 {
            print("❌ bindWorkerToGreenhouse: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ bindWorkerToGreenhouse: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может привязывать работников")
        } else if httpResponse.statusCode == 404 {
            print("❌ bindWorkerToGreenhouse: Ошибка 404 - Теплица или пользователь не найдены")
            throw APIError(detail: "Теплица или пользователь не найдены")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ bindWorkerToGreenhouse: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Отвязать работника от теплицы
    func unbindWorkerFromGreenhouse(greenhouseId: String, userId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ unbindWorkerFromGreenhouse: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/workers/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("👷 unbindWorkerFromGreenhouse: Отвязка работника \(userId) от теплицы \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ unbindWorkerFromGreenhouse: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("👷 unbindWorkerFromGreenhouse: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ unbindWorkerFromGreenhouse: Работник успешно отвязан")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ unbindWorkerFromGreenhouse: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ unbindWorkerFromGreenhouse: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен. Только администратор может отвязывать работников")
        } else if httpResponse.statusCode == 404 {
            print("❌ unbindWorkerFromGreenhouse: Ошибка 404 - Привязка не найдена")
            throw APIError(detail: "Привязка не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ unbindWorkerFromGreenhouse: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Получить данные о следующем удобрении для каждого растения в теплице
    func getNextFertilizingForPlants(greenhouseId: String) async throws -> [NextWateringOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getNextFertilizingForPlants: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/greenhouses/\(greenhouseId)/plants/next-fertilizing")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌿 getNextFertilizingForPlants: Запрос данных об удобрении для растений в теплице \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getNextFertilizingForPlants: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🌿 getNextFertilizingForPlants: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let nextFertilizings = try decoder.decode([NextWateringOut].self, from: data)
            print("✅ getNextFertilizingForPlants: Получено \(nextFertilizings.count) записей об удобрении")
            return nextFertilizings
        } else if httpResponse.statusCode == 401 {
            print("❌ getNextFertilizingForPlants: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 404 {
            print("⚠️ getNextFertilizingForPlants: Данные не найдены (404)")
            return []
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getNextFertilizingForPlants: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Reports
    
    /// Получить список отчетов о поливах и удобрениях
    func getReports(greenhouseId: String? = nil, userId: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async throws -> [ReportOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getReports: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/reports")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
        }
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }
        if let dateFrom = dateFrom {
            queryItems.append(URLQueryItem(name: "date_from", value: dateFrom))
        }
        if let dateTo = dateTo {
            queryItems.append(URLQueryItem(name: "date_to", value: dateTo))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError(detail: "Неверный URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📊 getReports: Запрос отчетов")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getReports: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📊 getReports: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let reports = try decoder.decode([ReportOut].self, from: data)
            print("✅ getReports: Получено \(reports.count) отчетов")
            return reports
        } else if httpResponse.statusCode == 401 {
            print("❌ getReports: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getReports: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Watering Events Update/Delete
    
    /// Обновить событие полива/удобрения
    func updateWateringEvent(eventId: String, update: WaterEventUpdate) async throws -> WaterEventOut {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ updateWateringEvent: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/watering-events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(update)
        
        print("💧 updateWateringEvent: Обновление события \(eventId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ updateWateringEvent: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("💧 updateWateringEvent: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let event = try decoder.decode(WaterEventOut.self, from: data)
            print("✅ updateWateringEvent: Событие успешно обновлено")
            return event
        } else if httpResponse.statusCode == 401 {
            print("❌ updateWateringEvent: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ updateWateringEvent: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этой теплице")
        } else if httpResponse.statusCode == 404 {
            print("❌ updateWateringEvent: Ошибка 404 - Событие не найдено")
            throw APIError(detail: "Событие не найдено")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ updateWateringEvent: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Удалить событие полива/удобрения
    func deleteWateringEvent(eventId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ deleteWateringEvent: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/watering-events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("💧 deleteWateringEvent: Удаление события \(eventId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ deleteWateringEvent: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("💧 deleteWateringEvent: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ deleteWateringEvent: Событие успешно удалено")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ deleteWateringEvent: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ deleteWateringEvent: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этой теплице")
        } else if httpResponse.statusCode == 404 {
            print("❌ deleteWateringEvent: Ошибка 404 - Событие не найдено")
            throw APIError(detail: "Событие не найдено")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ deleteWateringEvent: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Sensor Data History
    
    /// Получить историю данных датчика для теплицы
    func getSensorDataHistory(greenhouseId: String, limit: Int = 100, offset: Int = 0) async throws -> [SensorReadingOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getSensorDataHistory: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/greenhouses/\(greenhouseId)/sensor-data")!
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        guard let url = urlComponents.url else {
            throw APIError(detail: "Неверный URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📡 getSensorDataHistory: Запрос истории данных датчика для теплицы \(greenhouseId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getSensorDataHistory: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📡 getSensorDataHistory: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let readings = try decoder.decode([SensorReadingOut].self, from: data)
            print("✅ getSensorDataHistory: Получено \(readings.count) записей")
            return readings
        } else if httpResponse.statusCode == 401 {
            print("❌ getSensorDataHistory: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ getSensorDataHistory: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этой теплице")
        } else if httpResponse.statusCode == 404 {
            print("❌ getSensorDataHistory: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getSensorDataHistory: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Alerts
    
    /// Получить список предупреждений
    func getAlerts(greenhouseId: String? = nil, isRead: Bool? = nil) async throws -> [AlertOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getAlerts: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/alerts")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
        }
        if let isRead = isRead {
            queryItems.append(URLQueryItem(name: "is_read", value: isRead ? "true" : "false"))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw APIError(detail: "Неверный URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔔 getAlerts: Запрос списка предупреждений")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getAlerts: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🔔 getAlerts: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let alerts = try decoder.decode([AlertOut].self, from: data)
            print("✅ getAlerts: Получено \(alerts.count) предупреждений")
            return alerts
        } else if httpResponse.statusCode == 401 {
            print("❌ getAlerts: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ getAlerts: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Отметить предупреждение как прочитанное
    func markAlertAsRead(alertId: String) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ markAlertAsRead: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        let url = URL(string: "\(baseURL)/alerts/\(alertId)/read")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔔 markAlertAsRead: Отметка предупреждения \(alertId) как прочитанного")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ markAlertAsRead: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🔔 markAlertAsRead: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ markAlertAsRead: Предупреждение отмечено как прочитанное")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ markAlertAsRead: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ markAlertAsRead: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этому предупреждению")
        } else if httpResponse.statusCode == 404 {
            print("❌ markAlertAsRead: Ошибка 404 - Предупреждение не найдено")
            throw APIError(detail: "Предупреждение не найдено")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ markAlertAsRead: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
    
    /// Отметить все предупреждения для теплицы как прочитанные
    func markGreenhouseAlertsAsRead(greenhouseId: String, alertType: String? = nil) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ markGreenhouseAlertsAsRead: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/greenhouses/\(greenhouseId)/alerts/read")!
        if let alertType = alertType {
            urlComponents.queryItems = [URLQueryItem(name: "alert_type", value: alertType)]
        }
        
        guard let url = urlComponents.url else {
            throw APIError(detail: "Неверный URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔔 markGreenhouseAlertsAsRead: Отметка всех предупреждений для теплицы \(greenhouseId) как прочитанных")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ markGreenhouseAlertsAsRead: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("🔔 markGreenhouseAlertsAsRead: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 204 {
            print("✅ markGreenhouseAlertsAsRead: Все предупреждения отмечены как прочитанные")
            return
        } else if httpResponse.statusCode == 401 {
            print("❌ markGreenhouseAlertsAsRead: Ошибка 401 - Не авторизован")
            throw APIError(detail: "Не авторизован")
        } else if httpResponse.statusCode == 403 {
            print("❌ markGreenhouseAlertsAsRead: Ошибка 403 - Доступ запрещен")
            throw APIError(detail: "Доступ запрещен к этой теплице")
        } else if httpResponse.statusCode == 404 {
            print("❌ markGreenhouseAlertsAsRead: Ошибка 404 - Теплица не найдена")
            throw APIError(detail: "Теплица не найдена")
        } else {
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(APIError.self, from: data) {
                print("❌ markGreenhouseAlertsAsRead: Ошибка \(httpResponse.statusCode) - \(error.detail)")
                throw APIError(detail: error.detail)
            }
            throw APIError(detail: "Ошибка сервера (код \(httpResponse.statusCode))")
        }
    }
}

