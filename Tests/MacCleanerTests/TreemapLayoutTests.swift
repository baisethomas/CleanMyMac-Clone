import Testing
import CoreGraphics
@testable import MacCleaner

struct TreemapLayoutTests {
    @Test func areasAreProportional() {
        let values: [Double] = [600, 300, 100]
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rects = TreemapLayout.layout(values, in: rect)

        #expect(rects.count == 3)
        let total = values.reduce(0, +)
        for (value, tile) in zip(values, rects) {
            let expected = value / total * 10000
            let actual = Double(tile.width * tile.height)
            #expect(abs(actual - expected) < 1.0, "tile area should match value share")
        }
    }

    @Test func tilesStayWithinBounds() {
        let values: [Double] = [50, 30, 20, 10, 5, 5, 2, 1]
        let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
        let rects = TreemapLayout.layout(values, in: rect)

        for tile in rects {
            #expect(tile.minX >= rect.minX - 0.01)
            #expect(tile.minY >= rect.minY - 0.01)
            #expect(tile.maxX <= rect.maxX + 0.01)
            #expect(tile.maxY <= rect.maxY + 0.01)
        }
    }

    @Test func tilesCoverTheFullRect() {
        let values: [Double] = [40, 25, 15, 10, 6, 4]
        let rect = CGRect(x: 0, y: 0, width: 200, height: 150)
        let rects = TreemapLayout.layout(values, in: rect)

        let covered = rects.reduce(0.0) { $0 + Double($1.width * $1.height) }
        #expect(abs(covered - 30000) < 1.0)
    }

    @Test func zeroTotalProducesZeroRects() {
        let rects = TreemapLayout.layout([0, 0], in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(rects.allSatisfy { $0 == .zero })
    }

    @Test func emptyInputProducesEmptyOutput() {
        #expect(TreemapLayout.layout([], in: CGRect(x: 0, y: 0, width: 100, height: 100)).isEmpty)
    }
}
