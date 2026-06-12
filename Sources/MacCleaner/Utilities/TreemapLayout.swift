import Foundation
import CoreGraphics

/// Squarified treemap layout (Bruls, Huizing & van Wijk). Input values must be
/// sorted in descending order; returns one rect per value, in the same order,
/// tiling `rect` with areas proportional to the values.
enum TreemapLayout {
    static func layout(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 1, rect.height > 1 else {
            return values.map { _ in .zero }
        }

        let scale = Double(rect.width * rect.height) / total
        let areas = values.map { max($0, 0) * scale }
        var result: [CGRect] = []
        result.reserveCapacity(areas.count)
        var remaining = rect
        var index = 0

        while index < areas.count {
            // Grow the row while the worst aspect ratio keeps improving.
            let side = Double(min(remaining.width, remaining.height))
            var row: [Double] = [areas[index]]
            var rowEnd = index + 1
            var bestWorst = worstAspect(row, side: side)
            while rowEnd < areas.count {
                let candidate = row + [areas[rowEnd]]
                let worst = worstAspect(candidate, side: side)
                guard worst <= bestWorst else { break }
                row = candidate
                bestWorst = worst
                rowEnd += 1
            }

            result += place(row: row, in: &remaining)
            index = rowEnd
        }
        return result
    }

    private static func worstAspect(_ row: [Double], side: Double) -> Double {
        let sum = row.reduce(0, +)
        guard sum > 0, side > 0 else { return .infinity }
        let thickness = sum / side
        var worst = 1.0
        for area in row where area > 0 {
            let length = area / thickness
            worst = max(worst, max(length / thickness, thickness / length))
        }
        return worst
    }

    /// Lays a row of areas along the shorter side of `remaining`, shrinking it.
    private static func place(row: [Double], in remaining: inout CGRect) -> [CGRect] {
        let rowArea = row.reduce(0, +)
        var rects: [CGRect] = []
        rects.reserveCapacity(row.count)

        if remaining.width >= remaining.height {
            // Vertical strip on the left edge.
            let thickness = CGFloat(rowArea) / remaining.height
            var y = remaining.minY
            for area in row {
                let height = thickness > 0 ? CGFloat(area) / thickness : 0
                rects.append(CGRect(x: remaining.minX, y: y, width: thickness, height: height))
                y += height
            }
            remaining = CGRect(
                x: remaining.minX + thickness, y: remaining.minY,
                width: remaining.width - thickness, height: remaining.height
            )
        } else {
            // Horizontal strip on the top edge.
            let thickness = CGFloat(rowArea) / remaining.width
            var x = remaining.minX
            for area in row {
                let width = thickness > 0 ? CGFloat(area) / thickness : 0
                rects.append(CGRect(x: x, y: remaining.minY, width: width, height: thickness))
                x += width
            }
            remaining = CGRect(
                x: remaining.minX, y: remaining.minY + thickness,
                width: remaining.width, height: remaining.height - thickness
            )
        }
        return rects
    }
}
