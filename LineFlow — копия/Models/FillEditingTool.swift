//
//  FillEditingTool.swift
//  LineFlow
//
//  Created by macbook Алиса on 21/4/26.
//
import Foundation

enum FillEditingTool: String, CaseIterable, Identifiable {
    case deleteRegion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deleteRegion:
            return "Удаление области"
        }
    }
}
