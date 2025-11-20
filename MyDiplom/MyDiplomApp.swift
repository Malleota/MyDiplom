//
//  MyDiplomApp.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

@main
struct MyDiplomApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sensorDataManager = SensorDataManager.shared
    @StateObject private var wateringDataManager = WateringDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(sensorDataManager)
                    .environmentObject(wateringDataManager)
                    // Обновление запускается автоматически при появлении экранов с sensor_id
            } else {
                AuthContainerView()
            }
        }
    }
}
