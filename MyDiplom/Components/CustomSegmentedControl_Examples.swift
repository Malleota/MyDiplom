//
//  CustomSegmentedControl_Examples.swift
//  MyDiplom
//
//  Примеры использования CustomSegmentedControl
//

import SwiftUI

// MARK: - Пример 1: WorkersView (Все, Рабочие, Админы)

/*
// В WorkersView.swift замените стандартный Picker на:

CustomSegmentedControl(
    items: [
        SegmentItem(title: "Все", icon: "person.2", color: DesignColor.myDarkBlue),
        SegmentItem(title: "Рабочие", icon: "person", color: DesignColor.myPerple),
        SegmentItem(title: "Админы", icon: "person.crop.circle", color: DesignColor.myYellow)
    ],
    selection: $selectedFilter
)
.padding(.horizontal)
.padding(.top, 8)
*/

// MARK: - Пример 2: GreenhouseViews (Растения, Работники, Отчеты)

/*
// В GreenhouseViews.swift замените стандартный Picker на:

CustomSegmentedControl(
    items: [
        SegmentItem(title: "Растения", icon: "leaf", color: DesignColor.mainAccent),
        SegmentItem(title: "Работники", icon: "person.2", color: DesignColor.myPerple),
        SegmentItem(title: "Отчеты", icon: "chart.bar", color: DesignColor.myYellow)
    ],
    selection: $selectedTab
)
.padding(.horizontal)
.padding(.top, 16)
*/

// MARK: - Пример 3: CreateGreenhouseView (Растения, Рабочие)

/*
// В CreateGreenhouseView замените стандартный Picker на:

CustomSegmentedControl(
    items: [
        SegmentItem(title: "Растения", icon: "leaf", color: DesignColor.mainAccent),
        SegmentItem(title: "Рабочие", icon: "person.2", color: DesignColor.myPerple)
    ],
    selection: $selectedSegment
)
*/

