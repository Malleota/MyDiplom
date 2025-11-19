import SwiftUI
import CoreBluetooth

// MARK: - UI

struct ContentView: View {
    @StateObject private var manager = BLEManager()
    @StateObject private var authManager = AuthManager.shared
    @State private var showDeviceList = false
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Шапка с аватаром и приветствием
                HStack(spacing: 8) {
                    Button(action: {
                        showProfile = true
                    }) {
                        if let avatarUrl = authManager.currentUser?.avatar_url,
                           let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 48, height: 48)
                        }
                    }
                    
                    Text("Привет, \(authManager.currentUser?.name ?? "Пользователь")!")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
                
                // Кнопка Выйти
                Button(action: {
                    authManager.logout()
                }) {
                    Text("Выйти")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .navigationTitle("MyDiplomApp")
            .sheet(isPresented: $showDeviceList) {
                DeviceListView(manager: manager) { device in
                    manager.stopScan()
                    manager.connect(to: device)
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .onDisappear {
                        // Обновляем данные пользователя при закрытии профиля
                        Task {
                            await authManager.loadUserData()
                        }
                    }
            }
            .task {
                if authManager.currentUser == nil {
                    await authManager.loadUserData()
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
