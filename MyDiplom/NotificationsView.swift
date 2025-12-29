//
//  NotificationsView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var notificationStore: NotificationStore
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var sensorDataManager: SensorDataManager
    @EnvironmentObject var wateringDataManager: WateringDataManager
    @EnvironmentObject var fertilizingDataManager: FertilizingDataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if notificationStore.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Нет уведомлений")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Здесь будут отображаться все уведомления")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notificationStore.notifications) { notification in
                                NotificationRowView(notification: notification)
                                    .onTapGesture {
                                        handleNotificationTap(notification)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if !notification.isRead {
                                            Button {
                                                notificationStore.markAsRead(notification.id)
                                            } label: {
                                                Label("Прочитано", systemImage: "checkmark.circle")
                                            }
                                            .tint(.blue)
                                        }
                                        
                                        Button(role: .destructive) {
                                            notificationStore.removeNotification(notification.id)
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            notificationStore.markAllAsRead()
                        } label: {
                            Label("Отметить все как прочитанные", systemImage: "checkmark.circle")
                        }
                        .disabled(notificationStore.unreadCount == 0)
                        
                        Button(role: .destructive) {
                            notificationStore.clearReadNotifications()
                        } label: {
                            Label("Удалить прочитанные", systemImage: "trash")
                        }
                        .disabled(notificationStore.notifications.allSatisfy { !$0.isRead })
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            notificationStore.clearAllNotifications()
                        } label: {
                            Label("Удалить все", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // Помечаем как прочитанное
        if !notification.isRead {
            notificationStore.markAsRead(notification.id)
        }
        
        // Если уведомление связано с теплицей, открываем её
        if let greenhouseId = notification.greenhouseId {
            // Закрываем экран уведомлений
            dismiss()
            
            // Отправляем уведомление для навигации к теплице
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToGreenhouse"),
                    object: nil,
                    userInfo: ["greenhouse_id": greenhouseId]
                )
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: AppNotification
    
    var severityColor: Color {
        switch notification.severity {
        case "critical":
            return .red
        case "warning":
            return .orange
        default:
            return .blue
        }
    }
    
    var severityIcon: String {
        switch notification.severity {
        case "critical":
            return "exclamationmark.triangle.fill"
        case "warning":
            return "exclamationmark.circle.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Иконка серьезности
            Image(systemName: severityIcon)
                .font(.title3)
                .foregroundColor(severityColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // Заголовок
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.isRead ? .secondary : .primary)
                
                // Сообщение
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Информация о теплице и времени
                HStack(spacing: 8) {
                    if let greenhouseName = notification.greenhouseName {
                        Label(greenhouseName, systemImage: "building.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatDate(notification.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Индикатор непрочитанного
            if !notification.isRead {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(notification.isRead ? Color(.systemBackground) : Color(.systemBackground).opacity(0.7))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.isRead ? Color.clear : severityColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

