//
//  RegisterView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var authManager = AuthManager.shared
    let onShowLogin: () -> Void
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var generalError: String?
    
    @State private var isLoading: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var hasAttemptedSubmit: Bool = false
    
    private var hasData: Bool {
        !name.isEmpty || !email.isEmpty || !password.isEmpty
    }
    
    private var isFormValid: Bool {
        // Проверяем, что все поля заполнены
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            return false
        }
        // Проверяем валидность всех полей (всегда показываем ошибки для проверки валидности)
        return validateName(name, showErrors: true) == nil &&
               validateEmail(email, showErrors: true) == nil &&
               validatePassword(password, showErrors: true) == nil
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                // Лоадер
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // Форма регистрации
                VStack(spacing: 24) {
                    // Заголовок
                    Text("Регистрация")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Поле Имя
                            VStack(alignment: .leading, spacing: 8) {
                                SystemInputField(
                                    title: "Имя",
                                    placeholder: "Введите имя",
                                    text: $name,
                                    state: nameError == nil ? .normal : .error,
                                    textContentType: .name,
                                    autocapitalization: .words,
                                    submitLabel: .next
                                )
                                .onChange(of: name) { newValue in
                                    if hasAttemptedSubmit {
                                        nameError = validateName(newValue, showErrors: true)
                                    } else {
                                        nameError = nil
                                    }
                                    generalError = nil
                                }
                                
                                if let error = nameError {
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Поле Email
                            VStack(alignment: .leading, spacing: 8) {
                                SystemInputField(
                                    title: "Email",
                                    placeholder: "Введите email",
                                    text: $email,
                                    state: emailError == nil ? .normal : .error,
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress,
                                    autocapitalization: .never,
                                    submitLabel: .next
                                )
                                .onChange(of: email) { newValue in
                                    if hasAttemptedSubmit {
                                        emailError = validateEmail(newValue, showErrors: true)
                                    } else {
                                        emailError = nil
                                    }
                                    generalError = nil
                                }
                                
                                if let error = emailError {
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Поле Пароль
                            VStack(alignment: .leading, spacing: 8) {
                                SystemInputField(
                                    title: "Пароль",
                                    placeholder: "Введите пароль",
                                    text: $password,
                                    kind: .secure,
                                    state: passwordError == nil ? .normal : .error,
                                    textContentType: .newPassword,
                                    autocapitalization: .never,
                                    submitLabel: .done
                                )
                                .onChange(of: password) { newValue in
                                    if hasAttemptedSubmit {
                                        passwordError = validatePassword(newValue, showErrors: true)
                                    } else {
                                        passwordError = nil
                                    }
                                    generalError = nil
                                }
                                
                                if let error = passwordError {
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Общая ошибка
                            if let error = generalError {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Кнопка Зарегистрироваться
                            Button(action: {
                                performRegister()
                            }) {
                                Text("Зарегистрироваться")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(isFormValid ? DesignColor.mainAccent : Color.gray)
                                    .cornerRadius(10)
                            }
                            .disabled(!isFormValid || isLoading)
                            
                            // Кнопка Войти
                            Button(action: {
                                if hasData {
                                    showExitAlert = true
                                } else {
                                    onShowLogin()
                                }
                            }) {
                                Text("Войти")
                                    .font(.headline)
                                    .foregroundColor(DesignColor.mainAccent)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            }
        }
        .alert("Внимание", isPresented: $showExitAlert) {
            Button("Остаться", role: .cancel) {
                showExitAlert = false
            }
            Button("Покинуть", role: .destructive) {
                onShowLogin()
            }
        } message: {
            Text("Введенные данные будут утеряны при выходе с экрана")
        }
    }
    
    // MARK: - Validation
    
    private func validateName(_ name: String, showErrors: Bool) -> String? {
        if !showErrors && name.isEmpty {
            return nil
        }
        if name.isEmpty {
            return "Имя обязательно для заполнения"
        }
        if name.count < 2 {
            return "Имя должно содержать не менее 2 символов"
        }
        return nil
    }
    
    private func validateEmail(_ email: String, showErrors: Bool) -> String? {
        if !showErrors && email.isEmpty {
            return nil
        }
        if email.isEmpty {
            return "Email обязателен для заполнения"
        }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        if !emailPredicate.evaluate(with: email) {
            return "Email должен содержать @ и домен с точкой"
        }
        return nil
    }
    
    private func validatePassword(_ password: String, showErrors: Bool) -> String? {
        if !showErrors && password.isEmpty {
            return nil
        }
        if password.isEmpty {
            return "Пароль обязателен для заполнения"
        }
        if password.count < 6 {
            return "Пароль должен содержать не менее 6 символов"
        }
        let hasLowercase = password.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
        let hasUppercase = password.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        
        if !hasLowercase || !hasUppercase || !hasDigit {
            return "Пароль должен содержать минимум 1 строчную и одну заглавную букву латиницы и минимум одну цифру"
        }
        return nil
    }
    
    // MARK: - Actions
    
    private func performRegister() {
        hasAttemptedSubmit = true
        
        // Валидация всех полей
        nameError = validateName(name, showErrors: true)
        emailError = validateEmail(email, showErrors: true)
        passwordError = validatePassword(password, showErrors: true)
        
        guard isFormValid else {
            return
        }
        
        isLoading = true
        generalError = nil
        
        Task {
            do {
                // Регистрация
                _ = try await APIService.shared.register(name: name, email: email, password: password)
                
                // Автоматическая авторизация после успешной регистрации
                let response = try await APIService.shared.login(email: email, password: password)
                await MainActor.run {
                    authManager.login(token: response.access_token)
                    isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    generalError = error.detail
                    isLoading = false
                }
            } catch let urlError as URLError {
                await MainActor.run {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        generalError = "Нет подключения к интернету"
                    case .timedOut:
                        generalError = "Превышено время ожидания"
                    default:
                        generalError = "Ошибка подключения. Проверьте интернет-соединение."
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    generalError = "Ошибка подключения. Проверьте интернет-соединение."
                    isLoading = false
                }
            }
        }
    }
}

