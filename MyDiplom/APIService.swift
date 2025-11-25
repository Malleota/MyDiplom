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
    
    /// Отправить данные с датчика на сервер
    func sendSensorData(bleIdentifier: String, temperature: Double, humidity: Double) async throws {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ sendSensorData: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
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
        
        print("📤 sendSensorData: Отправка данных датчика ble_identifier=\(bleIdentifier), temp=\(temperature), hum=\(humidity)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ sendSensorData: Неверный ответ сервера")
                throw APIError(detail: "Неверный ответ сервера")
            }
            
            print("📤 sendSensorData: Статус ответа = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 204 {
                print("✅ sendSensorData: Данные успешно отправлены на сервер")
                return
            } else if httpResponse.statusCode == 401 {
                print("❌ sendSensorData: Ошибка 401 - Не авторизован")
                throw APIError(detail: "Не авторизован")
            } else if httpResponse.statusCode == 404 {
                print("⚠️ sendSensorData: Ошибка 404 - Датчик не найден")
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
        
        print("📡 getNextWatering: Запрос данных о следующем поливе для теплицы \(greenhouseId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ getNextWatering: Неверный ответ сервера")
                return nil
            }
            
            print("📡 getNextWatering: Статус ответа = \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let nextWatering = try decoder.decode(NextWateringOut.self, from: data)
                print("✅ getNextWatering: Данные о следующем поливе получены: days_until=\(nextWatering.days_until ?? -1)")
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
    func getWateringEvents(greenhouseId: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async throws -> [WaterEventOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getWateringEvents: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/watering-events")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
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
        
        print("📡 getWateringEvents: Запрос событий полива")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ getWateringEvents: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("📡 getWateringEvents: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let events = try decoder.decode([WaterEventOut].self, from: data)
            print("✅ getWateringEvents: Получено \(events.count) событий полива")
            return events
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
        
        print("💧 createWateringEvent: Создание события полива для теплицы \(greenhouseId), растение \(plantInstanceId ?? "nil")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ createWateringEvent: Неверный ответ сервера")
            throw APIError(detail: "Неверный ответ сервера")
        }
        
        print("💧 createWateringEvent: Статус ответа = \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            let event = try decoder.decode(WaterEventOut.self, from: data)
            print("✅ createWateringEvent: Событие полива успешно создано")
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
    func getFertilizingEvents(greenhouseId: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async throws -> [WaterEventOut] {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ getFertilizingEvents: Нет токена авторизации")
            throw APIError(detail: "Не авторизован")
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/watering-events")!
        var queryItems: [URLQueryItem] = []
        
        if let greenhouseId = greenhouseId {
            queryItems.append(URLQueryItem(name: "greenhouse_id", value: greenhouseId))
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
}

