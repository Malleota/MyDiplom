//
//  AuthContainerView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

enum AuthScreen {
    case login
    case register
}

struct AuthContainerView: View {
    @State private var currentScreen: AuthScreen = .login
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case .login:
                LoginView(onShowRegister: {
                    currentScreen = .register
                })
            case .register:
                RegisterView(onShowLogin: {
                    currentScreen = .login
                })
            }
        }
    }
}

