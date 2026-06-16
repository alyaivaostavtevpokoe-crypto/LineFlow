//
//  ColorShadowType.swift
//  LineFlow
//
//  Created by macbook Алиса on 20/5/26.
//

import Foundation

enum ColorShadowType: String, CaseIterable, Identifiable {
    case brightShadow
    case classicShadow
    case reflectedShadow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brightShadow:
            return "Яркая тень"
        case .classicShadow:
            return "Классическая тень"
        case .reflectedShadow:
            return "Отраженная тень"
        }
    }
}
