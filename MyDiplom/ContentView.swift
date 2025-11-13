import SwiftUI
import CoreBluetooth
import Combine

// Данные с датчика
struct SensorData {
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

// Менеджер BLE: сканирование + подключение + чтение GATT
final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    @Published var devices: [DiscoveredDevice] = []        // список устройств
    @Published var sensors: [UUID: SensorData] = [:]       // данные по device.id
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var lastConnectedDevice: DiscoveredDevice?  // последнее подключённое устройство

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?

    // Характеристика с температурой/влажностью/батареей
    private let tempHumidityUUID = CBUUID(string: "EBE0CCC1-7A0A-4B0C-8A1A-6FF2997DA3A6")

    // Ключ для сохранения UUID последнего устройства
    private let savedDeviceKey = "SavedPeripheralUUID"
    private var savedDeviceId: UUID?

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

    func startScan() {
        guard central.state == .poweredOn else {
            print("Cannot start scan, state =", central.state.rawValue)
            return
        }
        // Для ручного поиска очищаем список
        devices.removeAll()
        sensors.removeAll()
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        print("SCAN STARTED")
    }

    func stopScan() {
        central?.stopScan()
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

        UserDefaults.standard.set(device.id.uuidString, forKey: savedDeviceKey)
        savedDeviceId = device.id
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        print("Bluetooth state:", central.state.rawValue)

        // Если Bluetooth включён и есть сохранённое устройство — сразу начинаем сканировать
        if central.state == .poweredOn, savedDeviceId != nil {
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            print("AUTO SCAN STARTED FOR SAVED DEVICE")
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

        // Обновляем/добавляем устройство в список
        if let index = devices.firstIndex(where: { $0.id == dev.id }) {
            devices[index] = dev
        } else {
            devices.append(dev)
        }

        print("FOUND DEVICE:", name, "RSSI:", RSSI.intValue)

        // Автоподключение к сохранённому устройству
        if let targetId = savedDeviceId,
           targetId == peripheral.identifier,
           lastConnectedDevice == nil {
            print("Auto-connect to saved device:", name)
            connect(to: dev)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("Connected to", peripheral.identifier)
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
                print("Found temp/humidity characteristic")
                peripheral.setNotifyValue(true, for: ch)
                peripheral.readValue(for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("notify state error:", error.localizedDescription)
        } else {
            print("notify state changed for", characteristic.uuid, "isNotifying =", characteristic.isNotifying)
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

        let bytes = [UInt8](data)
        guard bytes.count >= 5 else {
            print("Not enough bytes:", bytes.count)
            return
        }

        // Формат: t0 t1 hum b0 b1
        let tempRaw = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let temperature = Double(tempRaw) / 100.0
        let humidity = Double(bytes[2])
        let batteryMv = Int(bytes[3]) | (Int(bytes[4]) << 8)
        let batteryVoltage = Double(batteryMv) / 1000.0

        // Грубая оценка процента заряда (2.1–3.1 В)
        let percentDouble = (batteryVoltage - 2.1) / (3.1 - 2.1) * 100.0
        let batteryPercent = max(0, min(100, Int(percentDouble.rounded())))

        let rssi = devices.first(where: { $0.id == peripheral.identifier })?.rssi ?? 0

        let sensor = SensorData(
            temperature: temperature,
            humidity: humidity,
            batteryPercent: batteryPercent,
            batteryVoltage: batteryVoltage,
            rssi: rssi
        )

        DispatchQueue.main.async {
            self.sensors[peripheral.identifier] = sensor
        }

        print("UPDATE SENSOR:",
              "T=", temperature,
              "H=", humidity,
              "Bat=", batteryPercent, "%", batteryVoltage, "V")
    }
}

// MARK: - UI

struct ContentView: View {
    @StateObject private var manager = BLEManager()
    @State private var showDeviceList = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                // Состояние Bluetooth
                switch manager.bluetoothState {
                case .unauthorized:
                    Text("Нет доступа к Bluetooth. Разреши доступ в Настройки → Конфиденциальность → Bluetooth.")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                case .poweredOff:
                    Text("Bluetooth выключен. Включи Bluetooth на устройстве.")
                        .font(.footnote)
                        .foregroundColor(.orange)
                default:
                    EmptyView()
                }

                // Выбранное/автоматически подключённое устройство
                if let device = manager.lastConnectedDevice {
                    Text("Подключено: \(device.name)")
                        .font(.headline)

                    if let sensor = manager.sensors[device.id] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: "Температура: %.2f °C", sensor.temperature))
                            Text(String(format: "Влажность: %.0f %%", sensor.humidity))
                            Text("Батарея: \(sensor.batteryPercent)%")
                            Text(String(format: "Напряжение: %.3f V", sensor.batteryVoltage))
                            Text("RSSI: \(sensor.rssi) dBm")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    } else {
                        Text("Нет данных от датчика. Подожди пару секунд после подключения.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                } else {
                    Text("Устройство не выбрано")
                        .foregroundColor(.secondary)
                }

                // Кнопка ручного выбора устройства (если нужно сменить)
                Button("Найти устройства") {
                    manager.startScan()
                    showDeviceList = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 24)

                Spacer()
            }
            .padding()
            .navigationTitle("MyDiplomApp")
            .sheet(isPresented: $showDeviceList) {
                DeviceListView(manager: manager) { device in
                    manager.stopScan()
                    manager.connect(to: device)
                }
            }
        }
    }
}

// Экран со списком устройств
struct DeviceListView: View {
    @ObservedObject var manager: BLEManager
    let onSelect: (DiscoveredDevice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(manager.devices) { device in
                Button {
                    onSelect(device)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.headline)
                            Text("RSSI: \(device.rssi) dBm")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Выбор устройства")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
