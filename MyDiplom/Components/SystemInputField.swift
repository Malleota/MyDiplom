//
//  SystemInputField.swift
//  MyDiplom
//
//  Created by ChatGPT on 20.11.2025.
//

import SwiftUI

struct SystemInputField: View {
    enum FieldKind {
        case text
        case secure
    }
    
    enum FieldState: Equatable {
        case normal
        case error
        case success
        case custom(Color)
    }
    
    private let title: String?
    private let placeholder: String
    @Binding private var text: String
    
    private let kind: FieldKind
    private let state: FieldState
    private let keyboardType: UIKeyboardType
    private let textContentType: UITextContentType?
    private let autocapitalization: TextInputAutocapitalization
    private let submitLabel: SubmitLabel
    private let onFocusChange: ((Bool) -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var isSecureRevealed = false
    
    init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>,
        kind: FieldKind = .text,
        state: FieldState = .normal,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        submitLabel: SubmitLabel = .done,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.kind = kind
        self.state = state
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.submitLabel = submitLabel
        self.onFocusChange = onFocusChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 40)
                    .fill(DesignColor.Background.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(borderColor, lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    inputField
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if kind == .secure {
                        Button {
                            isSecureRevealed.toggle()
                        } label: {
                            Image(systemName: isSecureRevealed ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel(isSecureRevealed ? "Скрыть пароль" : "Показать пароль")
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 58)
        }
        .onChange(of: isFocused) { newValue in
            onFocusChange?(newValue)
        }
    }
    
    @ViewBuilder
    private var inputField: some View {
        if kind == .secure && !isSecureRevealed {
            SecureField(placeholder, text: $text)
                .textContentType(textContentType ?? .password)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
                .submitLabel(submitLabel)
        } else {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .disableAutocorrection(kind == .secure)
                .focused($isFocused)
                .submitLabel(submitLabel)
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .normal:
            return isFocused ? Color.accentColor.opacity(0.6) : DesignColor.Fills.tertiar
        case .error:
            return Color.red
        case .success:
            return Color.green
        case .custom(let color):
            return color
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SystemInputField(
            title: "Email",
            placeholder: "Введите email",
            text: .constant("hello@example.com"),
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            autocapitalization: .never,
            submitLabel: .next
        )
        
        SystemInputField(
            title: "Пароль",
            placeholder: "Введите пароль",
            text: .constant("password"),
            kind: .secure
        )
    }
    .padding()
}


