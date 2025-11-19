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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Большой аватар
                    if let selectedAvatar = avatars.first(where: { $0.id == selectedAvatarId }),
                       let url = URL(string: selectedAvatar.image_url) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
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
                            ProgressView()
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
                            .font(.system(size: 16, weight: .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Сетка аватаров
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
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
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Профиль")
                        .font(.system(size: 17, weight: .regular))
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

struct AvatarThumbnailView: View {
    let avatar: AvatarOut
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let url = URL(string: avatar.image_url) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            }
        }
    }
}

