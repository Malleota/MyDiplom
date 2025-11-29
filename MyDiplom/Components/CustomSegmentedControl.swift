//
//  CustomSegmentedControl.swift
//  MyDiplom
//
//  Created on 20.11.2025.
//

import SwiftUI

// MARK: - Segment Item
struct SegmentItem {
    let title: String
    let icon: String?
    let color: Color
    
    init(title: String, icon: String? = nil, color: Color) {
        self.title = title
        self.icon = icon
        self.color = color
    }
}

// MARK: - Custom Segmented Control
struct CustomSegmentedControl<SelectionValue: Hashable>: View {
    let items: [SegmentItem]
    let options: [SelectionValue]
    @Binding var selection: SelectionValue
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let item = items[index]
                let isSelected = selection == option
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                    }
                }) {
                    HStack(spacing: 6) {
                        if let icon = item.icon {
                            Image(systemName: icon)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(isSelected ? item.color.opacity(0.8) : item.color.opacity(0.8))
                        }
                        
                        Text(item.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? item.color.opacity(0.8) : item.color.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 40)
                            .fill(isSelected ? item.color.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(isSelected ? Color.clear : item.color.opacity(0.08), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 40))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Convenience Initializer for CaseIterable
extension CustomSegmentedControl where SelectionValue: CaseIterable {
    init(
        items: [SegmentItem],
        selection: Binding<SelectionValue>
    ) {
        let allCases = Array(SelectionValue.allCases)
        self.init(
            items: items,
            options: allCases,
            selection: selection
        )
    }
}


// MARK: - Preview
struct CustomSegmentedControl_Previews: PreviewProvider {
    enum TestOption: String, CaseIterable {
        case all = "Все"
        case workers = "Рабочие"
        case admins = "Админы"
    }
    
    static var previews: some View {
        VStack(spacing: 30) {
            StatefulPreviewWrapper(initialValue: TestOption.all) { selection in
                CustomSegmentedControl(
                    items: [
                        SegmentItem(title: "Все", icon: "person.2", color: DesignColor.myDarkBlue),
                        SegmentItem(title: "Рабочие", icon: "person", color: DesignColor.myPerple),
                        SegmentItem(title: "Админы", icon: "person.crop.circle", color: DesignColor.myYellow)
                    ],
                    selection: selection
                )
                .padding()
            }
        }
    }
}

// MARK: - Helper for Preview
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content
    
    init(initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }
    
    var body: some View {
        content($value)
    }
}

