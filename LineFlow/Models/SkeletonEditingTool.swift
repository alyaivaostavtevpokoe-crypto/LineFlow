//
//  SkeletonEditingTool.swift
//  LineFlow
//
//  Created by macbook Алиса on 21/4/26.
//
import Foundation

enum SkeletonEditingTool: String, CaseIterable, Identifiable {
    case draw
    case erase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draw:
            return "Дорисовка"
        case .erase:
            return "Стирание"
        }
    }
}
