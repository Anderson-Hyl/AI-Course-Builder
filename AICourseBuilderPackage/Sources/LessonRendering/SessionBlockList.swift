import LearningModels
import LearningUI
import SwiftUI

/// Renders an ordered list of `SessionBlock` rows. Sorts by `order` so
/// callers can pass blocks in any order. Spacing is intentionally
/// generous (24pt) so each block reads as its own card — final
/// session-workspace chrome will tighten this in a future pass.
public struct SessionBlockList: View {
    public let blocks: [SessionBlock]

    public init(blocks: [SessionBlock]) {
        self.blocks = blocks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(blocks.sorted { $0.order < $1.order }) { block in
                BlockView(block: block)
            }
        }
    }
}

// MARK: - Previews

#Preview("Haskell session") {
    ScrollView {
        SessionBlockList(blocks: Fixtures.haskellSessionBlocks)
            .padding(24)
            .frame(maxWidth: 720)
    }
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Haskell session — dark") {
    ScrollView {
        SessionBlockList(blocks: Fixtures.haskellSessionBlocks)
            .padding(24)
            .frame(maxWidth: 720)
    }
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
    .preferredColorScheme(.dark)
}

#Preview("Math session") {
    ScrollView {
        SessionBlockList(blocks: Fixtures.mathSessionBlocks)
            .padding(24)
            .frame(maxWidth: 720)
    }
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Chemistry session") {
    ScrollView {
        SessionBlockList(blocks: Fixtures.chemistrySessionBlocks)
            .padding(24)
            .frame(maxWidth: 720)
    }
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
}

#Preview("Chemistry session — dark") {
    ScrollView {
        SessionBlockList(blocks: Fixtures.chemistrySessionBlocks)
            .padding(24)
            .frame(maxWidth: 720)
    }
    .background(CourseBuilderThemePalette.mvp.surface.appCanvas)
    .preferredColorScheme(.dark)
}
