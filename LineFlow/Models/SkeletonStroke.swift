//
//  SkeletonStroke.swift
//  LineFlow
//
//  Created by macbook Алиса on 21/4/26.
//
import Foundation
import CoreGraphics

struct SkeletonStroke: Identifiable, Equatable {
    let id = UUID()
    var points: [CGPoint]
    var tool: SkeletonEditingTool
    var brushSize: CGFloat
}
