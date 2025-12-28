//
//  ProfileView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var avatars: [AvatarOut] = []
    @State private var selectedAvatarId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Большой аватар
                        if let selectedAvatar = avatars.first(where: { $0.id == selectedAvatarId }),
                           let url = URL(string: selectedAvatar.image_url) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                SkeletonView(width: 176, height: 176, cornerRadius: 20)
                            }
                            .frame(width: 176, height: 176)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else if let avatarUrl = authManager.currentUser?.avatar_url,
                                  let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                SkeletonView(width: 176, height: 176, cornerRadius: 20)
                            }
                            .frame(width: 176, height: 176)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 176, height: 176)
                        }
                        
                        // Заголовок "Аватары"
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Аватары")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                               
                            
                            // Сетка аватаров
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(avatars) { avatar in
                                        AvatarThumbnailView(
                                            avatar: avatar,
                                            isSelected: (selectedAvatarId ?? authManager.currentUser?.avatar_id) == avatar.id,
                                            onTap: {
                                                selectedAvatarId = avatar.id
                                                updateAvatar(avatarId: avatar.id)
                                            }
                                        )
                                    }
                                }
                
                                .padding(.vertical, 2)
                                .padding(.horizontal, 2)
                                .padding(.trailing)
                            }
                            
                            .frame(height: 64)
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        
                        // Заголовок "Мои данные"
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Мои данные")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 24)
                            
                            // Список данных пользователя
                            VStack(spacing: 0) {
                                if let user = authManager.currentUser {
                                    VStack(spacing: 0) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Имя")
                                                    .font(.body)
                                                Text(user.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(UIColor.systemBackground))
                                        
                                        Divider()
                                            .padding(.leading, 16)
                                        
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Email")
                                                    .font(.body)
                                                Text(user.email)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(UIColor.systemBackground))
                                        
                                        Divider()
                                            .padding(.leading, 16)
                                        
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Статус")
                                                    .font(.body)
                                                Text(user.role == "worker" ? "Рабочий" : user.role == "admin" ? "Админ" : user.role)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(UIColor.systemBackground))
                                    }
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                        }
                    }
                    .padding(.top, 32)
                }
                
                // Кнопка Выйти внизу экрана
                VStack {
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        Text("Выйти")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Профиль")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Назад") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadAvatars()
                selectedAvatarId = authManager.currentUser?.avatar_id
            }
            .alert("Вы точно хотите выйти?", isPresented: $showLogoutAlert) {
                Button("Остаться", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    authManager.logout()
                }
            }
        }
    }
    
    private func loadAvatars() async {
        isLoading = true
        do {
            let loadedAvatars = try await APIService.shared.getAvatars()
            await MainActor.run {
                avatars = loadedAvatars
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Ошибка загрузки аватаров"
                isLoading = false
            }
        }
    }
    
    private func updateAvatar(avatarId: String) {
        Task {
            do {
                let updatedUser = try await APIService.shared.updateAvatar(avatarId: avatarId)
                await MainActor.run {
                    authManager.updateUser(updatedUser)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Ошибка обновления аватара"
                }
            }
        }
    }
}

struct ScrollDisabledIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDisabled(true)
        } else {
            content
        }
    }
}

struct AvatarThumbnailView: View {
    let avatar: AvatarOut
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if let url = URL(string: avatar.image_url) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .background(Color(UIColor.quaternarySystemFill))
                    } placeholder: {
                        SkeletonView(width: 64, height: 64, cornerRadius: 32)
                    }
                } else {
                    SkeletonView(width: 64, height: 64, cornerRadius: 32)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 64, height: 64)
        .fixedSize()
    }
}

