//
//  BLEManager.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import Foundation
import CoreBluetooth
import Combine

// Данные с датчика
struct SensorData: Equatable {
    let temperature: Double
    let humidity: Double
    let batteryPercent: Int
    let batteryVoltage: Double
    let rssi: Int
}

// Найденное BLE-устройство
struct DiscoveredDevice: Identifiable {
    let id: UUID          // peripheral.identifier
    let name: String
    let rssi: Int
}

// Менеджер BLE: сканирование + подключение + чтение GATT + интерпретация данных + сохранение
final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    @Published var devices: [DiscoveredDevice] = []        // список устройств
    @Published var sensors: [UUID: SensorData] = [:]       // данные по device.id
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var lastConnectedDevice: DiscoveredDevice?  // последнее подключённое устройство

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var autoConnectTimer: Timer?

    // Характеристика с температурой/влажностью/батареей
    private let tempHumidityUUID = CBUUID(string: "EBE0CCC1-7A0A-4B0C-8A1A-6FF2997DA3A6")

    // Ключ для сохранения UUID последнего устройства
    private let savedDeviceKey = "SavedPeripheralUUID"
    private var savedDeviceId: UUID?
    
    // Таймаут для автоподключения (10 секунд)
    private let autoConnectTimeout: TimeInterval = 10.0
    
    // Флаг для отключения автоподключения (для ручного сканирования)
    private var disableAutoConnect = false
    
    // Список ble_identifier датчиков, привязанных к теплицам
    private var boundSensorIdentifiers: Set<String> = []

    override init() {
        super.init()

        // Читаем сохранённый UUID устройства (если был)
        if let uuidString = UserDefaults.standard.string(forKey: savedDeviceKey),
           let uuid = UUID(uuidString: uuidString) {
            savedDeviceId = uuid
            print("Saved device id loaded:", uuid)
        }

        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: Публичные методы
    
    /// Обновляет список привязанных датчиков и проверяет, нужно ли автоподключаться
    func updateBoundSensors(_ bleIdentifiers: [String]) {
        boundSensorIdentifiers = Set(bleIdentifiers)
        print("📋 updateBoundSensors: Обновлен список привязанных датчиков: \(bleIdentifiers)")
        
        // Если есть сохраненный датчик и он привязан к теплице, разрешаем автоподключение
        if let savedId = savedDeviceId {
            let savedIdString = savedId.uuidString
            if boundSensorIdentifiers.contains(savedIdString) {
                print("✅ Сохраненный датчик \(savedIdString) привязан к теплице, автоподключение разрешено")
                // Если Bluetooth включен и еще не подключены, начинаем сканирование
                if central.state == .poweredOn, lastConnectedDevice == nil, !disableAutoConnect {
                    central.scanForPeripherals(withServices: nil, options: nil)
                    print("AUTO SCAN STARTED FOR BOUND SENSOR")
                    
                    autoConnectTimer?.invalidate()
                    autoConnectTimer = Timer.scheduledTimer(withTimeInterval: autoConnectTimeout, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        if self.lastConnectedDevice == nil {
                            self.stopScan()
                            print("Auto-connect timeout: bound sensor not found")
                        }
                    }
                }
            } else {
                print("⚠️ Сохраненный датчик \(savedIdString) не привязан к теплице, автоподключение не требуется")
            }
        }
    }

    func startScan(disableAutoConnect: Bool = false) {
        guard central.state == .poweredOn else {
            print("Cannot start scan, state =", central.state.rawValue)
            return
        }
        // Для ручного поиска очищаем список
        self.disableAutoConnect = disableAutoConnect
        devices.removeAll()
        sensors.removeAll()
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        print("SCAN STARTED (autoConnect disabled: \(disableAutoConnect))")
    }

    func stopScan() {
        central?.stopScan()
        autoConnectTimer?.invalidate()
        autoConnectTimer = nil
        print("SCAN STOPPED")
    }

    // Подключение к выбранному устройству + запоминание
    func connect(to device: DiscoveredDevice) {
        guard let peripheral = peripherals[device.id] else {
            print("No peripheral for id", device.id)
            return
        }
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        print("CONNECT TO:", device.name)

        DispatchQueue.main.async {
            self.lastConnectedDevice = device
        }

        // Сохранение UUID устройства
        UserDefaults.standard.set(device.id.uuidString, forKey: savedDeviceKey)
        savedDeviceId = device.id
    }
    
    // Отключение от устройства
    func disconnect() {
        if let peripheral = connectedPeripheral {
            central.cancelPeripheralConnection(peripheral)
            print("DISCONNECT FROM:", peripheral.identifier)
        }
        
        // Очищаем сохраненное устройство
        UserDefaults.standard.removeObject(forKey: savedDeviceKey)
        savedDeviceId = nil
        
        DispatchQueue.main.async {
            self.lastConnectedDevice = nil
            self.sensors.removeAll()
            self.connectedPeripheral = nil
        }
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        print("Bluetooth state:", central.state.rawValue)

        // Если Bluetooth включён и есть сохранённое устройство, привязанное к теплице — начинаем сканировать
        // Но только если автоподключение не отключено
        if central.state == .poweredOn, 
           let savedId = savedDeviceId,
           !disableAutoConnect,
           boundSensorIdentifiers.contains(savedId.uuidString) {
            // При автоподключении не используем AllowDuplicatesKey, чтобы избежать лишних логов
            central.scanForPeripherals(
                withServices: nil,
                options: nil
            )
            print("AUTO SCAN STARTED FOR SAVED DEVICE (bound to greenhouse)")
            
            // Устанавливаем таймаут для автоподключения
            autoConnectTimer?.invalidate()
            autoConnectTimer = Timer.scheduledTimer(withTimeInterval: autoConnectTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.lastConnectedDevice == nil {
                    self.stopScan()
                    print("Auto-connect timeout: device not found")
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        peripherals[peripheral.identifier] = peripheral

        let name = peripheral.name
        ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        ?? "Без имени"

        let dev = DiscoveredDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue
        )

        // Проверяем, идёт ли автоподключение к сохранённому устройству
        let isAutoConnecting = savedDeviceId != nil && lastConnectedDevice == nil && !disableAutoConnect
        
        // Автоподключение к сохранённому устройству (только если не отключено)
        if let targetId = savedDeviceId,
           targetId == peripheral.identifier,
           lastConnectedDevice == nil,
           !disableAutoConnect {
            autoConnectTimer?.invalidate()  // Отменяем таймаут
            stopScan()  // Останавливаем сканирование сразу после нахождения нужного устройства
            connect(to: dev)
            return  // Не добавляем устройство в общий список при автоподключении
        }

        // Добавляем устройство в список только при ручном сканировании
        if !isAutoConnecting {
            // Обновляем/добавляем устройство в список
            if let index = devices.firstIndex(where: { $0.id == dev.id }) {
                devices[index] = dev
            } else {
                devices.append(dev)
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        stopScan()
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Failed to connect:", error?.localizedDescription ?? "unknown error")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("Disconnected:", peripheral.identifier, "error:", error?.localizedDescription ?? "none")
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        if let error = error {
            print("discoverServices error:", error.localizedDescription)
            return
        }
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("discoverCharacteristics error:", error.localizedDescription)
            return
        }
        guard let chars = service.characteristics else { return }

        for ch in chars {
            if ch.uuid == tempHumidityUUID {
                peripheral.setNotifyValue(true, for: ch)
                peripheral.readValue(for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ BLE: notify state error:", error.localizedDescription)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("didUpdateValue error:", error.localizedDescription)
            return
        }
        guard characteristic.uuid == tempHumidityUUID,
              let data = characteristic.value else {
            return
        }

        // Интерпретация данных с датчика
        let sensorData = interpretSensorData(data: data, peripheralId: peripheral.identifier)
        
        if let sensor = sensorData {
            DispatchQueue.main.async {
                self.sensors[peripheral.identifier] = sensor
            }
            
            // Отправляем данные на сервер в фоновом режиме
            let bleIdentifier = peripheral.identifier.uuidString
            Task {
                do {
                    try await APIService.shared.sendSensorData(
                        bleIdentifier: bleIdentifier,
                        temperature: sensor.temperature,
                        humidity: sensor.humidity
                    )
                    // Отправляем уведомление об успешной отправке данных
                    // Это позволит запросить обновленные данные с сервера
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SensorDataSent"),
                            object: nil,
                            userInfo: ["ble_identifier": bleIdentifier]
                        )
                    }
                } catch {
                    // Ошибка уже обработана в sendSensorData, просто логируем
                    print("⚠️ Не удалось отправить данные на сервер: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: Интерпретация данных с датчика

    /// Интерпретирует сырые данные с BLE-датчика в структуру SensorData
    /// - Parameters:
    ///   - data: Данные из характеристики BLE
    ///   - peripheralId: UUID периферийного устройства
    /// - Returns: Интерпретированные данные датчика или nil при ошибке
    private func interpretSensorData(data: Data, peripheralId: UUID) -> SensorData? {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else {
            print("Not enough bytes:", bytes.count)
            return nil
        }

        // Формат: t0 t1 hum b0 b1
        // Температура: 2 байта (little-endian, знаковое Int16, делённое на 100)
        let tempRaw = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let temperature = Double(tempRaw) / 100.0

        // Влажность: 1 байт (процент)
        let humidity = Double(bytes[2])

        // Батарея: 2 байта (little-endian, милливольты, делённые на 1000)
        let batteryMv = Int(bytes[3]) | (Int(bytes[4]) << 8)
        let batteryVoltage = Double(batteryMv) / 1000.0

        // Грубая оценка процента заряда (2.1–3.1 В)
        let percentDouble = (batteryVoltage - 2.1) / (3.1 - 2.1) * 100.0
        let batteryPercent = max(0, min(100, Int(percentDouble.rounded())))

        // RSSI из списка найденных устройств
        let rssi = devices.first(where: { $0.id == peripheralId })?.rssi ?? 0

        return SensorData(
            temperature: temperature,
            humidity: humidity,
            batteryPercent: batteryPercent,
            batteryVoltage: batteryVoltage,
            rssi: rssi
        )
    }
}

