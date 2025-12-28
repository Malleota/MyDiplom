//
//  WorkersView.swift
//  MyDiplom
//
//  Created on 20.11.2025.
//

import SwiftUI

// MARK: - Workers View (Работники)
struct WorkersView: View {
    @State private var allUsers: [UserOut] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: UserFilter = .all
    
    enum UserFilter: String, CaseIterable {
        case all = "Все"
        case workers = "Рабочие"
        case admins = "Админы"
    }
    
    var filteredUsers: [UserOut] {
        switch selectedFilter {
        case .all:
            return allUsers
        case .workers:
            return allUsers.filter { $0.role == "worker" }
        case .admins:
            return allUsers.filter { $0.role == "admin" }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Переключатель фильтрации
                Picker("Фильтр", selection: $selectedFilter) {
                    ForEach(UserFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Список пользователей
                if isLoading {
                    ProgressView("Загрузка пользователей...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Ошибка загрузки")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Повторить") {
                            loadUsers()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(selectedFilter == .all ? "Нет пользователей" : "Нет \(selectedFilter.rawValue.lowercased())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredUsers) { user in
                                NavigationLink(destination: WorkerProfileView(user: user)) {
                                    UserRow(user: user)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Работники")
            .task {
                loadUsers()
            }
            .refreshable {
                await loadUsersAsync()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserRoleUpdated"))) { _ in
                loadUsers()
            }
        }
    }
    
    private func loadUsers() {
        Task {
            await loadUsersAsync()
        }
    }
    
    private func loadUsersAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let users = try await APIService.shared.getAllUsers()
            await MainActor.run {
                allUsers = users
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
}

// MARK: - User Row
struct UserRow: View {
    let user: UserOut
    
    var body: some View {
        HStack(spacing: 12) {
            // Аватар пользователя
            if let avatarUrl = user.avatar_url, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        SkeletonView(width: 50, height: 50, cornerRadius: 8)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 20))
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    )
            }
            
            // Информация о пользователе
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Бейдж роли
                    Text(user.role == "admin" ? "Админ" : "Рабочий")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(user.role == "admin" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(user.role == "admin" ? .blue : .green)
                        .cornerRadius(4)
                    
                    // Бейдж активности
                    if !user.is_active {
                        Text("Неактивен")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .cardBorder()
        .cardShadow()
    }
}

