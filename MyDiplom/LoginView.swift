//
//  LoginView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    let onShowRegister: () -> Void
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    
    private var isFormValid: Bool {
        isValidEmail(email) && password.count >= 3
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                // Лоадер
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // Форма авторизации
                VStack(spacing: 24) {
                    // Заголовок
                    Text("Вход")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Поле Email
                        SystemInputField(
                            title: "Email",
                            placeholder: "Введите email",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            submitLabel: .next
                        )
                        .onChange(of: email) { _ in
                            errorMessage = nil
                        }
                        
                        // Поле Пароль
                        SystemInputField(
                            title: "Пароль",
                            placeholder: "Введите пароль",
                            text: $password,
                            kind: .secure,
                            textContentType: .password,
                            autocapitalization: .never,
                            submitLabel: .done
                        )
                        .onChange(of: password) { _ in
                            errorMessage = nil
                        }
                        
                        // Сообщение об ошибке
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Кнопка Войти
                        Button(action: {
                            performLogin()
                        }) {
                            Text("Войти")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isFormValid ? DesignColor.mainAccent : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!isFormValid || isLoading)
                        
                        // Кнопка Регистрация
                        Button(action: {
                            onShowRegister()
                        }) {
                            Text("Регистрация")
                                .font(.headline)
                                .foregroundColor(DesignColor.mainAccent)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                errorMessage = nil
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func performLogin() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("🔐 LoginView: Начало авторизации для \(email)")
                let response = try await APIService.shared.login(email: email, password: password)
                print("✅ LoginView: Получен токен, сохранение...")
                await MainActor.run {
                    authManager.login(token: response.access_token)
                    isLoading = false
                    print("✅ LoginView: Авторизация завершена успешно")
                }
            } catch let error as APIError {
                print("❌ LoginView: API Error - \(error.detail)")
                await MainActor.run {
                    errorMessage = error.detail
                    isLoading = false
                }
            } catch let urlError as URLError {
                await MainActor.run {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorMessage = "Нет подключения к интернету"
                    case .timedOut:
                        errorMessage = "Превышено время ожидания"
                    default:
                        errorMessage = "Ошибка подключения. Проверьте интернет-соединение."
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Ошибка подключения. Проверьте интернет-соединение."
                    isLoading = false
                }
            }
        }
    }
}

