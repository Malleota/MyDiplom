//
//  SkeletonView.swift
//  MyDiplom
//
//  Created by Daria Zharko on 09.11.2025.
//

import SwiftUI

// MARK: - Skeleton Components
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.white.opacity(0.4), location: 0.5),
                            .init(color: Color.clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 1.5)
                    .offset(x: -geometry.size.width * 0.75 + phase * geometry.size.width * 1.5)
                    .blur(radius: 8)
                }
                .clipped()
            )
            .onAppear {
                phase = 0
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .modifier(ShimmerEffect())
            .accessibilityHidden(true)
    }
}

// MARK: - Greenhouse Detail Skeleton
struct GreenhouseDetailSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Заголовок
                HStack(spacing: 12) {
                    SkeletonView(width: nil, height: 28, cornerRadius: 6)
                    SkeletonView(width: 80, height: 80, cornerRadius: 8)
                }
                .padding(.horizontal)
                
                // Блок данных датчика
                HStack(spacing: 12) {
                    SkeletonView(width: nil, height: 100, cornerRadius: 12)
                    SkeletonView(width: nil, height: 100, cornerRadius: 12)
                }
                .padding(.horizontal)
                
                // Сегментированный контрол
                SkeletonView(width: nil, height: 40, cornerRadius: 20)
                    .padding(.horizontal)
                
                // Элементы списка
                VStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        SkeletonView(width: nil, height: 80, cornerRadius: 12)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Plants View Skeleton
struct PlantsViewSkeleton: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    HStack(spacing: 12) {
                        // Изображение растения
                        SkeletonView(width: 50, height: 50, cornerRadius: 8)
                        
                        // Информация о растении
                        VStack(alignment: .leading, spacing: 4) {
                            // Название (headline)
                            SkeletonView(width: nil, height: 18, cornerRadius: 4)
                            
                            // Описание (caption, lineLimit: 2)
                            //SkeletonView(width: nil, height: 14, cornerRadius: 4)
                            SkeletonView(width: 200, height: 14, cornerRadius: 4)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .cardBorder()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }
}

