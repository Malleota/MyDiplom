//
//  MainTabView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI
import CoreBluetooth

struct MainTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 0
    
    var isAdmin: Bool {
        authManager.currentUser?.role == "admin"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Главная
            HomeView()
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }
                .tag(0)
            
            // Справочник
            PlantsView()
                .tabItem {
                    Label("Справочник", systemImage: "leaf.fill")
                }
                .tag(1)
            
            // Теплицы
            GreenhousesView()
                .tabItem {
                    Label("Теплицы", systemImage: "building.2.fill")
                }
                .tag(2)
            
            // Работники - только для админа
            if isAdmin {
                WorkersView()
                    .tabItem {
                        Label("Работники", systemImage: "person.2.fill")
                    }
                    .tag(3)
            }
        }
        .onChange(of: isAdmin) { newValue in
            // Если пользователь больше не админ и выбран таб "Работники", переключаемся на главную
            if !newValue && selectedTab == 3 {
                selectedTab = 0
            }
        }
        .task {
            if authManager.currentUser == nil {
                await authManager.loadUserData()
            }
        }
    }
}

// MARK: - Home View (Главная)
struct HomeView: View {
    @StateObject private var manager = BLEManager()
    @StateObject private var authManager = AuthManager.shared
    @State private var showDeviceList = false
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Шапка с аватаром и приветствием
                HStack(spacing: 12) {
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
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 56, height: 56)
                        }
                    }
                    
                    Text("Привет, \(authManager.currentUser?.name ?? "")!")
                        .font(.title2.bold())
                    
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
            }
            .padding()
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

// MARK: - Plants View (Справочник)
struct PlantsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("Справочник растений")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 16)
                Text("Здесь будут все растения")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            .navigationTitle("Справочник")
        }
    }
}

// MARK: - Greenhouses View (Теплицы)
struct GreenhousesView: View {
    var body: some View {
        GreenhouseListView()
    }
}

// MARK: - Workers View (Работники)
struct WorkersView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                Text("Работники")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 16)
                Text("Здесь будет список работников")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            .navigationTitle("Работники")
        }
    }
}

// MARK: - Device List View
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

