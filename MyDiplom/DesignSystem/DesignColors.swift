//
//  DesignColors.swift
//  MyDiplom
//
//  Created by ChatGPT on 20.11.2025.
//

import SwiftUI

enum DesignColor {
    enum Background {
        static let primary = Color("BackgroundPrimary")
    }
    
    enum Fills {
        static let tertiar = Color("FillsTertiar")
    }
    
    static let mainAccent = Color("MainAccent")
    static let mainRed = Color("MainRed")
    static let myBlue = Color("MyBlue")
    static let myBrown = Color("MyBrown")
    static let myDarkBlue = Color("MyDarkBlue")
    static let myPerple = Color("MyPerple")
    static let myYellow = Color("MyYellow")
}

// MARK: - Card Shadow Modifier
extension View {
    /// Применяет стандартную тень для карточек, видимую в светлой и темной теме
    func cardShadow() -> some View {
        self.modifier(CardShadowModifier())
    }
    
    /// Применяет стандартный бордер для карточек
    func cardBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1.0)
        )
    }
}

struct CardShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .dark 
                ? Color.white.opacity(0.1) 
                : Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}


