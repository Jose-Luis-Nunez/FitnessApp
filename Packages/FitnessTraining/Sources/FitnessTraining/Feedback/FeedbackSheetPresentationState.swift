import CoreGraphics

enum FeedbackSheetDragSource {
    case header
    case compactSurface
}

enum FeedbackSheetDragResult: Equatable {
    case none
    case dismiss
}

struct FeedbackSheetPresentationState: Equatable {
    var isExpanded = false

    func height(
        compactHeight: CGFloat,
        largeHeight: CGFloat,
        dragTranslation: CGFloat
    ) -> CGFloat {
        if isExpanded {
            return max(compactHeight, largeHeight - max(0, dragTranslation))
        }
        return min(largeHeight, compactHeight + max(0, -dragTranslation))
    }

    func dismissOffset(dragTranslation: CGFloat) -> CGFloat {
        guard !isExpanded else { return 0 }
        return max(0, dragTranslation)
    }

    mutating func synchronizeWithSymptoms(isEmpty: Bool) {
        isExpanded = !isEmpty
    }

    mutating func endDrag(
        translation: CGFloat,
        source: FeedbackSheetDragSource
    ) -> FeedbackSheetDragResult {
        let expansionThreshold: CGFloat = source == .header ? -60 : -40
        if translation < expansionThreshold {
            isExpanded = true
            return .none
        }

        if translation > 80 {
            if isExpanded {
                isExpanded = false
                return .none
            }
            return .dismiss
        }

        return .none
    }
}
