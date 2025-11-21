//
//  WebSocketManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import Combine

/// Менеджер для WebSocket подключения к серверу для получения обновлений данных датчиков в реальном времени
@MainActor
class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()
    
    @Published var isConnected = false
    @Published var connectionError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var greenhouseId: String?
    private var isAdmin: Bool = false
    
    // Callback для обработки обновлений данных датчиков
    var onSensorDataUpdate: ((String, SensorReadingOut) -> Void)? // greenhouseId, sensorData
    
    private init() {}
    
    /// Подключается к WebSocket для конкретной теплицы
    func connect(greenhouseId: String) {
        guard self.greenhouseId != greenhouseId || !isConnected else {
            print("🔌 WebSocket: Уже подключен к теплице \(greenhouseId)")
            return
        }
        
        disconnect()
        self.greenhouseId = greenhouseId
        self.isAdmin = false
        performConnect()
    }
    
    /// Подключается к WebSocket для всех теплиц (только для админов)
    func connectForAll() {
        guard !isAdmin || !isConnected else {
            print("🔌 WebSocket: Уже подключен для всех теплиц")
            return
        }
        
        disconnect()
        self.greenhouseId = nil
        self.isAdmin = true
        performConnect()
    }
    
    /// Отключается от WebSocket
    func disconnect() {
        print("🔌 WebSocket: Отключение...")
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        isConnected = false
        connectionError = nil
        greenhouseId = nil
        isAdmin = false
    }
    
    private func performConnect() {
        guard let token = AuthManager.shared.accessToken else {
            print("❌ WebSocket: Нет токена авторизации")
            connectionError = "Нет токена авторизации"
            return
        }
        
        // Используем ws:// для HTTP или wss:// для HTTPS
        let baseURL = "http://95.140.158.180:8000"
        let wsBaseURL = baseURL.replacingOccurrences(of: "http://", with: "ws://").replacingOccurrences(of: "https://", with: "wss://")
        var urlString: String
        
        if isAdmin {
            urlString = "\(wsBaseURL)/ws/sensor-data?token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)"
        } else if let greenhouseId = greenhouseId {
            urlString = "\(wsBaseURL)/ws/sensor-data/\(greenhouseId)?token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token)"
        } else {
            print("❌ WebSocket: Не указан greenhouse_id и не админ")
            connectionError = "Не указан greenhouse_id"
            return
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ WebSocket: Неверный URL: \(urlString)")
            connectionError = "Неверный URL"
            return
        }
        
        print("🔌 WebSocket: Подключение к \(urlString)")
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.urlSession = session
        self.webSocketTask = task
        
        task.resume()
        
        // Начинаем слушать сообщения
        receiveMessage()
        
        // Запускаем heartbeat
        startHeartbeat()
    }
    
    private func receiveMessage() {
        guard let task = webSocketTask else { return }
        
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    
                    // Продолжаем слушать
                    self.receiveMessage()
                    
                case .failure(let error):
                    print("❌ WebSocket: Ошибка получения сообщения: \(error.localizedDescription)")
                    self.isConnected = false
                    self.connectionError = error.localizedDescription
                    
                    // Пытаемся переподключиться
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("⚠️ WebSocket: Не удалось преобразовать сообщение в данные")
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let type = json?["type"] as? String else {
                print("⚠️ WebSocket: Сообщение без типа: \(text)")
                return
            }
            
            switch type {
            case "connected":
                print("✅ WebSocket: Подключено успешно")
                isConnected = true
                connectionError = nil
                
            case "pong":
                // Ответ на ping, ничего не делаем
                break
                
            case "sensor_data":
                handleSensorDataUpdate(json)
                
            case "watering_event_created":
                // Данные о поливах обновляются автоматически на бэкенде, просто логируем
                if let greenhouseId = json?["greenhouse_id"] as? String {
                    print("💧 WebSocket: Событие полива создано для теплицы \(greenhouseId), данные обновлены автоматически на бэкенде")
                }
                
            default:
                print("⚠️ WebSocket: Неизвестный тип сообщения: \(type)")
            }
        } catch {
            print("❌ WebSocket: Ошибка парсинга JSON: \(error.localizedDescription)")
        }
    }
    
    private func handleSensorDataUpdate(_ json: [String: Any]?) {
        guard let json = json,
              let greenhouseId = json["greenhouse_id"] as? String,
              let sensorId = json["sensor_id"] as? String,
              let temperature = json["temperature"] as? Double,
              let humidity = json["humidity"] as? Double,
              let timestamp = json["timestamp"] as? String else {
            print("⚠️ WebSocket: Неполные данные sensor_data: \(json ?? [:])")
            return
        }
        
        let sensorReading = SensorReadingOut(
            id: "",
            sensor_id: sensorId,
            greenhouse_id: greenhouseId,
            temperature: temperature,
            humidity: humidity,
            created_at: timestamp
        )
        
        print("📡 WebSocket: Получены данные датчика для теплицы \(greenhouseId): temp=\(temperature), hum=\(humidity)")
        
        // Вызываем callback
        onSensorDataUpdate?(greenhouseId, sensorReading)
    }
    
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 секунд
                
                guard isConnected, let task = webSocketTask else {
                    break
                }
                
                // Отправляем ping
                let message = URLSessionWebSocketTask.Message.string("ping")
                task.send(message) { error in
                    if let error = error {
                        print("❌ WebSocket: Ошибка отправки ping: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            // Ждем 5 секунд перед переподключением
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            print("🔄 WebSocket: Попытка переподключения...")
            
            if isAdmin {
                connectForAll()
            } else if let greenhouseId = greenhouseId {
                connect(greenhouseId: greenhouseId)
            }
        }
    }
}

